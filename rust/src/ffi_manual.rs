//! 手动 FFI 桥接（临时方案，等 flutter_rust_bridge codegen 在 Windows 上修复后替换）
//!
//! 使用标准的 #[no_mangle] extern "C" 接口，供 Dart FFI 调用。

use std::ffi::{CStr, CString};
use std::os::raw::c_char;

/// 初始化 Hermes Agent（C ABI）
///
/// 返回版本字符串的指针，需要用 `free_string` 释放
#[no_mangle]
pub extern "C" fn init_hermes(log_level: *const c_char) -> *mut c_char {
    let log_level = if log_level.is_null() {
        "info".to_string()
    } else {
        unsafe { CStr::from_ptr(log_level).to_string_lossy().to_string() }
    };

    std::env::set_var("RUST_LOG", &log_level);

    let result = format!(
        "Hermes Agent Core v{} initialized (log={})",
        env!("CARGO_PKG_VERSION"),
        log_level
    );

    CString::new(result).unwrap().into_raw()
}

/// 获取 Core 版本号（C ABI）
#[no_mangle]
pub extern "C" fn get_core_version() -> *mut c_char {
    let version = env!("CARGO_PKG_VERSION").to_string();
    CString::new(version).unwrap().into_raw()
}

/// Ping 测试（C ABI）
#[no_mangle]
pub extern "C" fn ping() -> *mut c_char {
    let result = "pong".to_string();
    CString::new(result).unwrap().into_raw()
}

/// 释放 CString 指针（防止内存泄漏）
///
/// Dart 侧调用完 Rust 返回的字符串后，必须调用此函数释放内存
#[no_mangle]
pub extern "C" fn free_string(s: *mut c_char) {
    if s.is_null() {
        return;
    }
    unsafe {
        let _ = CString::from_raw(s);
    }
}

/// 加法测试（最简单的 FFI 测试）
#[no_mangle]
pub extern "C" fn add(a: i32, b: i32) -> i32 {
    a + b
}

/// 获取 LLM 模型列表（JSON 字符串）
///
/// 返回 JSON 字符串指针，需要用 `free_string` 释放
#[no_mangle]
pub extern "C" fn llm_list_models(provider: *const c_char) -> *mut c_char {
    let provider = if provider.is_null() {
        "deepseek".to_string()
    } else {
        unsafe { CStr::from_ptr(provider).to_string_lossy().to_string() }
    };

    let models = match provider.as_str() {
        "deepseek" => vec!["deepseek-chat".to_string(), "deepseek-reasoner".to_string()],
        "openai" => vec!["gpt-4o".to_string(), "gpt-4o-mini".to_string()],
        "local" => vec!["qwen3-4b".to_string(), "phi4-mini".to_string()],
        _ => vec![],
    };

    let json = serde_json::json!({
        "provider": provider,
        "models": models,
    });

    let result = serde_json::to_string(&json).unwrap();
    CString::new(result).unwrap().into_raw()
}
