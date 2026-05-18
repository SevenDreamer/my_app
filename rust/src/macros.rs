//! FFI 宏定义
//!
//! 用于减少 FFI 函数中的重复代码

/// 调用 async 函数（自动处理 tokio runtime）
///
/// 用法：
/// ```rust
/// #[no_mangle]
/// pub extern "C" fn auth_logout(token: *const c_char) -> *mut c_char {
///     let token_str = from_c_str(token);
///     call_async!(crate::auth::logout(&token_str))
/// }
/// ```
#[macro_export]
macro_rules! call_async {
    // 无参数
    ($func:expr) => {{
        let rt = tokio::runtime::Runtime::new().unwrap();
        let result = rt.block_on($func);
        to_c_str(&result)
    }};
    
    // 1 个参数
    ($func:expr, $($arg:expr),+) => {{
        let rt = tokio::runtime::Runtime::new().unwrap();
        let result = rt.block_on($func($(arg),+));
        to_c_str(&result)
    }};
}

/// 从 C 字符串指针获取 Rust String
#[macro_export]
macro_rules! from_c {
    ($ptr:expr) => {{
        $crate::ffi_auth::from_c_str($ptr)
    }};
}

/// 将 Rust String 转换为 C 字符串指针
#[macro_export]
macro_rules! to_c {
    ($s:expr) => {{
        $crate::ffi_auth::to_c_str($s)
    }};
}
