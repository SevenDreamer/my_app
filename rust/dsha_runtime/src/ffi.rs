// 版权来源：DSHA（MIT）——派生文件，汇总见 my_app THIRD_PARTY_NOTICES.md。
//! C ABI 出入口（AGENTS.md：FFI 一律零依赖手写 `extern "system"` 声明）。
//!
//! 契约：返回 0 = 成功；返回非 0 = 失败，错误文案（机器可读代号
//! `TAR_*` / `ARCHIVE_*` / `COLD_SPLIT_*` 等）写入调用方缓冲区（UTF-8，NUL 结尾），
//! 缓冲区不足时截断并仍保证 NUL 结尾。传空指针/非法 UTF-8 返回 `FFI_INPUT`。
use std::ffi::{c_char, CStr, OsStr};
use std::fs::File;
use std::io::Read;
use std::os::raw::c_void;
use std::path::Path;
use std::panic::{catch_unwind, AssertUnwindSafe};

use crate::archive::extract_selected;
use crate::std_fs::StdFs;

/// 进度回调（done, total, ctx）；total 为归档字节数。
pub type ExtractProgress = extern "system" fn(i64, i64, *mut c_void);

fn write_error(out: *mut c_char, len: usize, message: &str) {
    if out.is_null() || len == 0 {
        return;
    }
    let bytes = message.as_bytes();
    let copy = bytes.len().min(len - 1);
    // 缓冲区由调用方给，越界写不安全；逐字节复制 + 强制 NUL 结尾。
    for (index, byte) in bytes.iter().take(copy).enumerate() {
        unsafe {
            *out.add(index) = *byte as c_char;
        }
    }
    unsafe {
        *out.add(copy) = 0;
    }
}

fn read_path(ptr: *const c_char, field: &str) -> Result<String, String> {
    if ptr.is_null() {
        return Err(format!("FFI_INPUT:{field}"));
    }
    let raw = unsafe { CStr::from_ptr(ptr) };
    match raw.to_str() {
        Ok(text) => Ok(text.to_owned()),
        Err(_) => Err(format!("FFI_INPUT:{field}")),
    }
}

/// 解包 gzip 归档到 dest（全量投影，strip=0）。
///
/// `progress` 可为 null。错误文案逐字保留（`extract_selected` 的 io::Error 链）。
///
/// # Safety
/// 路径指针指向 NUL 结尾 UTF-8；error_out 由调用方提供至少 error_len 字节。
#[unsafe(no_mangle)]
pub extern "system" fn dsha_extract_archive(
    archive_path: *const c_char,
    dest_path: *const c_char,
    progress: Option<ExtractProgress>,
    ctx: *mut c_void,
    error_out: *mut c_char,
    error_len: usize,
) -> i32 {
    let result = catch_unwind(AssertUnwindSafe(|| {
        extract_inner(archive_path, dest_path, progress, ctx)
    }));
    match result {
        Ok(Ok(())) => 0,
        Ok(Err(message)) => {
            write_error(error_out, error_len, &message);
            1
        }
        Err(_) => {
            write_error(error_out, error_len, "FFI_PANIC");
            2
        }
    }
}

fn extract_inner(
    archive_path: *const c_char,
    dest_path: *const c_char,
    progress: Option<ExtractProgress>,
    ctx: *mut c_void,
) -> Result<(), String> {
    let archive = read_path(archive_path, "archive")?;
    let dest = read_path(dest_path, "dest")?;
    let file = File::open(&archive).map_err(|error| error.to_string())?;
    let total = file.metadata().map(|m| m.len() as i64).unwrap_or(0);
    // 把逐字节读取接上进度回调（原版 extractOfflineBundle 的 (done, total) 契约）。
    let mut input: Box<dyn Read> = match progress {
        Some(callback) => Box::new(ProgressReader {
            inner: file,
            done: 0,
            total,
            callback,
            ctx,
        }),
        None => Box::new(file),
    };
    let dest = Path::new(OsStr::new(&dest));
    match extract_selected(&mut input, dest, 0, &|_| true, &StdFs) {
        Ok(_) => Ok(()),
        Err(error) => Err(error.to_string()),
    }
}

struct ProgressReader {
    inner: File,
    done: i64,
    total: i64,
    callback: ExtractProgress,
    ctx: *mut c_void,
}

impl Read for ProgressReader {
    fn read(&mut self, buffer: &mut [u8]) -> std::io::Result<usize> {
        let count = self.inner.read(buffer)?;
        self.done += count as i64;
        (self.callback)(self.done, self.total, self.ctx);
        Ok(count)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::process::Command;

    #[test]
    fn extract_fixture_round_trip() {
        let temp = std::env::temp_dir().join(format!("dsha-ffi-{}", std::process::id()));
        let source = temp.join("src");
        fs::create_dir_all(source.join("bin")).unwrap();
        fs::write(source.join("bin/bash"), b"#!/bin/sh\n").unwrap();
        fs::write(source.join("hello.txt"), b"hi\n").unwrap();
        let archive = temp.join("offline.tar.gz");
        // 用系统 tar 造夹具（测试宿主有 tar；引擎本身只负责解）。
        let status = Command::new("tar")
            .args(["-czf"])
            .arg(&archive)
            .arg("-C")
            .arg(&source)
            .arg(".")
            .status()
            .unwrap();
        assert!(status.success());
        let dest = temp.join("out");
        fs::create_dir_all(&dest).unwrap();
        let c_archive = std::ffi::CString::new(archive.to_string_lossy().as_bytes()).unwrap();
        let c_dest = std::ffi::CString::new(dest.to_string_lossy().as_bytes()).unwrap();
        let mut error = [0u8; 512];
        let code = dsha_extract_archive(
            c_archive.as_ptr(),
            c_dest.as_ptr(),
            None,
            std::ptr::null_mut(),
            error.as_mut_ptr() as *mut c_char,
            error.len(),
        );
        assert_eq!(code, 0, "error: {}", String::from_utf8_lossy(&error));
        assert_eq!(fs::read(dest.join("hello.txt")).unwrap(), b"hi\n");
        assert_eq!(fs::read(dest.join("bin/bash")).unwrap(), b"#!/bin/sh\n");
        // 坏归档 → 非 0 + 机器码进缓冲区。
        fs::write(&archive, b"not a gzip").unwrap();
        let code = dsha_extract_archive(
            c_archive.as_ptr(),
            c_dest.as_ptr(),
            None,
            std::ptr::null_mut(),
            error.as_mut_ptr() as *mut c_char,
            error.len(),
        );
        assert_eq!(code, 1);
        assert!(!error.is_empty());
        fs::remove_dir_all(&temp).unwrap();
    }
}
