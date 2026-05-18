//! 手动编写的最小化 ffi_bridge.rs
//! 临时方案：绕过 flutter_rust_bridge_codegen 在 Windows 上的路径 bug
//! 
//! 此文件提供 FFI 绑定，让 Dart 可以调用 Rust 函数
//! 后续应在 Linux/WSL 中重新运行 codegen 生成完整版本

use std::ffi::{CStr, CString};
use std::os::raw::c_char;

// ============================
// 辅助宏：将 Rust String 转为 C 指针
// ============================

fn rust_str_to_c(s: String) -> *mut c_char {
    CString::new(s).unwrap().into_raw()
}

unsafe fn c_char_to_rust_str<'a>(s: *const c_char) -> &'a str {
    if s.is_null() {
        ""
    } else {
        CStr::from_ptr(s).to_str().unwrap_or("")
    }
}

// ============================
// 对外的 C 函数（导出的 FFI 接口）
// ============================

/// greet 函数 - FFI 导出
#[no_mangle]
pub extern "C" fn my_app_greet(name: *const c_char) -> *mut c_char {
    let name_str = unsafe { c_char_to_rust_str(name).to_string() };
    let result = format!("Hello, {name_str}!");
    rust_str_to_c(result)
}

/// ping 函数 - FFI 导出
#[no_mangle]
pub extern "C" fn my_app_ping() -> *mut c_char {
    rust_str_to_c("pong".to_string())
}

/// get_core_version 函数 - FFI 导出
#[no_mangle]
pub extern "C" fn my_app_get_core_version() -> *mut c_char {
    let version = env!("CARGO_PKG_VERSION").to_string();
    rust_str_to_c(version)
}

/// 释放 C 字符串内存（由 Dart 侧调用）
#[no_mangle]
pub extern "C" fn my_app_free_string(s: *mut c_char) {
    if !s.is_null() {
        unsafe {
            let _ = CString::from_raw(s);
        }
    }
}

/// init_my_app 函数 - FFI 导出
#[no_mangle]
pub extern "C" fn my_app_init(log_level: *const c_char) -> *mut c_char {
    let level = unsafe { c_char_to_rust_str(log_level).to_string() };
    // 设置日志级别（简化版）
    let result = format!(
        "My App Core v{} initialized (log={level})",
        env!("CARGO_PKG_VERSION")
    );
    rust_str_to_c(result)
}
