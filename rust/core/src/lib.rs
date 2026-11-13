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

/// 版本决策：[remote] 是否比 [current] 新（semver 标准，含预发布段
/// 排序——1.3.0-dev.1 < 1.3.0）。解析失败返回 -1（调用方保守处理）。
/// 迁移自 update_service._isNewer（pub_semver 同标准）。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn core_semver_is_newer(
    remote: *const c_char,
    current: *const c_char,
) -> i32 {
    use semver::Version;
    let (Some(r), Some(c)) = (
        unsafe { CStr::from_ptr(remote) }.to_str().ok(),
        unsafe { CStr::from_ptr(current) }.to_str().ok(),
    ) else {
        return -1;
    };
    // 兼容带 build 号（1.3.0+92）与纯版本（1.3.0）——取版本段
    let clean = |s: &str| -> String {
        s.split('+').next().unwrap_or(s).trim().to_string()
    };
    let (Ok(rv), Ok(cv)) = (
        Version::parse(&clean(r)),
        Version::parse(&clean(c)),
    ) else {
        return -1;
    };
    if rv > cv {
        1
    } else {
        0
    }
}

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

/// 文件流式 SHA-256（镜像/大文件校验正解）：路径进 → 十六进制串出。
/// Rust 内流式读（8KB 块）——大文件零双拷贝；路径须 UTF-8；失败/文件
/// 不存在返回 null（错误细节经 [core_last_error] 取）。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn core_sha256_file(path: *const c_char) -> *mut c_char {
    use std::io::Read;
    if path.is_null() {
        return std::ptr::null_mut();
    }
    let Ok(p) = unsafe { CStr::from_ptr(path) }.to_str() else {
        return std::ptr::null_mut();
    };
    let Ok(mut f) = std::fs::File::open(p) else {
        return std::ptr::null_mut();
    };
    let mut hasher = Sha256::new();
    let mut buf = [0u8; 8192];
    loop {
        match f.read(&mut buf) {
            Ok(0) => break,
            Ok(n) => hasher.update(&buf[..n]),
            Err(_) => return std::ptr::null_mut(),
        }
    }
    let hex: String = hasher.finalize().iter().map(|b| format!("{b:02x}")).collect();
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
    fn semver_decisions() {
        let c = |s: &str| CString::new(s).unwrap();
        let (r1, c1) = (c("1.3.0"), c("1.2.9"));
        assert_eq!(unsafe { core_semver_is_newer(r1.as_ptr(), c1.as_ptr()) }, 1);
        // 预发布排序：dev.9 < dev.10（数字比较非字典序——手写踩过的坑）
        let (r2, c2) = (c("1.3.0-dev.10"), c("1.3.0-dev.9"));
        assert_eq!(unsafe { core_semver_is_newer(r2.as_ptr(), c2.as_ptr()) }, 1);
        // 预发布 < 正式
        let (r3, c3) = (c("1.3.0"), c("1.3.0-dev.49"));
        assert_eq!(unsafe { core_semver_is_newer(r3.as_ptr(), c3.as_ptr()) }, 1);
        // 带 build 号兼容
        let (r4, c4) = (c("1.4.0"), c("1.3.0+92"));
        assert_eq!(unsafe { core_semver_is_newer(r4.as_ptr(), c4.as_ptr()) }, 1);
        // 不更新
        let (r5, c5) = (c("1.3.0-dev.48"), c("1.3.0-dev.49"));
        assert_eq!(unsafe { core_semver_is_newer(r5.as_ptr(), c5.as_ptr()) }, 0);
        // 非法串
        let (r6, c6) = (c("not-a-version"), c("1.0.0"));
        assert_eq!(unsafe { core_semver_is_newer(r6.as_ptr(), c6.as_ptr()) }, -1);
    }

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
    fn sha256_file_stream() {
        // 流式与内存版结果一致性（写临时文件验证）
        let tmp = std::env::temp_dir().join("core_sha256_test.txt");
        std::fs::write(&tmp, b"abc").unwrap();
        let path = CString::new(tmp.to_str().unwrap()).unwrap();
        let p = unsafe { core_sha256_file(path.as_ptr()) };
        let s = unsafe { CStr::from_ptr(p) }.to_str().unwrap().to_string();
        assert_eq!(
            s,
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        );
        unsafe { core_string_free(p) };
        std::fs::remove_file(&tmp).ok();
        // 不存在的文件 → null
        let bad = CString::new("/nonexistent/core_test").unwrap();
        assert!(unsafe { core_sha256_file(bad.as_ptr()) }.is_null());
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
