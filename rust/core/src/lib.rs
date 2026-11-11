//! my_app 核心引擎（Rust）——底子骨架（2026-11-10）。
//!
//! 定位：计算密集的核心层（未来的镜像校验/快照差分/解压），经 C ABI 供
//! Flutter（dart:ffi）调用；同一 crate 将来编 wasm 供 web 端复用。
//! FFI 规矩（项目先例）：零依赖手写 `extern "C"`，不引 FFI 框架。
//!
//! 分层：本 crate 只做纯计算（无 IO/无平台 API）——平台相关（文件/线程）
//! 留在调用侧，保证 wasm 可编译。

use std::ffi::{c_char, CStr, CString};
use std::slice;

use sha2::{Digest, Sha256};

/// 核心引擎版本号（心跳函数——FFI 通路的活体验证）。
/// 返回值为静态字符串指针，调用方**不得释放**。
#[unsafe(no_mangle)]
pub extern "C" fn core_version() -> *const c_char {
    // C ABI 字符串必须 NUL 终止——静态串手动补 \0（2026-11-10 FFI 测试
    // 抓获：缺 NUL 尾会让调用方 toDartString 读越界出 FormatException）
    static VERSION: &str = concat!("core-rs-", env!("CARGO_PKG_VERSION"), "\0");
    VERSION.as_ptr() as *const c_char
}

/// 自检算术（FFI 通路的双向验证：int 进出）。
#[unsafe(no_mangle)]
pub extern "C" fn core_add(a: i64, b: i64) -> i64 {
    a.saturating_add(b)
}

/// 带字符串返回的示例：sha256 就绪位（功能未落地，先验字符串通道）。
/// 返回堆分配字符串，调用方须用 [core_string_free] 释放。
#[unsafe(no_mangle)]
pub extern "C" fn core_build_info() -> *mut c_char {
    let s = format!(
        "target={} profile={}",
        std::env::consts::ARCH,
        if cfg!(debug_assertions) { "debug" } else { "release" }
    );
    CString::new(s).map(|c| c.into_raw()).unwrap_or(std::ptr::null_mut())
}

/// SHA-256 哈希（镜像/快照校验原语）：字节缓冲进 → 十六进制串出。
/// [data] 为缓冲指针、[len] 为字节数；返回堆分配字符串，须用
/// [core_string_free] 释放。data 为空指针返回 null。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn core_sha256_hex(data: *const u8, len: usize) -> *mut c_char {
    if data.is_null() {
        return std::ptr::null_mut();
    }
    let bytes = unsafe { slice::from_raw_parts(data, len) };
    let mut hasher = Sha256::new();
    hasher.update(bytes);
    let digest = hasher.finalize();
    let hex: String = digest.iter().map(|b| format!("{b:02x}")).collect();
    CString::new(hex).map(|c| c.into_raw()).unwrap_or(std::ptr::null_mut())
}

/// 释放 [core_build_info] 返回的字符串（配对释放，FFI 纪律）。
///
/// # Safety
/// [ptr] 必须来自 [core_build_info] 的返回值且只释放一次。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn core_string_free(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe { drop(CString::from_raw(ptr)) };
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn add_saturates() {
        assert_eq!(core_add(2, 3), 5);
        assert_eq!(core_add(i64::MAX, 1), i64::MAX);
    }

    #[test]
    fn version_is_static_cstring() {
        let p = core_version();
        assert!(!p.is_null());
        let s = unsafe { std::ffi::CStr::from_ptr(p) };
        assert!(s.to_str().unwrap().starts_with("core-rs-"));
    }

    #[test]
    fn sha256_known_vector() {
        // NIST 测试向量：空串 → e3b0c442...（校验哈希正确性）
        let p = unsafe { core_sha256_hex(std::ptr::null(), 0) };
        assert!(p.is_null(), "空指针须返回 null");
        let empty: [u8; 0] = [];
        let p = unsafe { core_sha256_hex(empty.as_ptr(), 0) };
        let s = unsafe { CStr::from_ptr(p) }.to_str().unwrap().to_string();
        assert_eq!(
            s,
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        );
        unsafe { core_string_free(p) };
    }

    #[test]
    fn sha256_abc_vector() {
        let data = b"abc";
        let p = unsafe { core_sha256_hex(data.as_ptr(), data.len()) };
        let s = unsafe { CStr::from_ptr(p) }.to_str().unwrap().to_string();
        assert_eq!(
            s,
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        );
        unsafe { core_string_free(p) };
    }

    #[test]
    fn build_info_roundtrip() {
        let p = core_build_info();
        assert!(!p.is_null());
        let s = unsafe { std::ffi::CStr::from_ptr(p) };
        assert!(s.to_str().unwrap().contains("target="));
        unsafe { core_string_free(p) };
    }
}
