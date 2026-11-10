//! my_app 核心引擎（Rust）——底子骨架（2026-11-10）。
//!
//! 定位：计算密集的核心层（未来的镜像校验/快照差分/解压），经 C ABI 供
//! Flutter（dart:ffi）调用；同一 crate 将来编 wasm 供 web 端复用。
//! FFI 规矩（项目先例）：零依赖手写 `extern "C"`，不引 FFI 框架。
//!
//! 分层：本 crate 只做纯计算（无 IO/无平台 API）——平台相关（文件/线程）
//! 留在调用侧，保证 wasm 可编译。

use std::ffi::{c_char, CString};

/// 核心引擎版本号（心跳函数——FFI 通路的活体验证）。
/// 返回值为静态字符串指针，调用方**不得释放**。
#[unsafe(no_mangle)]
pub extern "C" fn core_version() -> *const c_char {
    // 静态生命周期：进程内有效，免释放（FFI 心跳惯例）
    static VERSION: &str = concat!("core-rs-", env!("CARGO_PKG_VERSION"));
    // CString::new 只能给运行时串用；静态串直接转指针
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
    fn build_info_roundtrip() {
        let p = core_build_info();
        assert!(!p.is_null());
        let s = unsafe { std::ffi::CStr::from_ptr(p) };
        assert!(s.to_str().unwrap().contains("target="));
        unsafe { core_string_free(p) };
    }
}
