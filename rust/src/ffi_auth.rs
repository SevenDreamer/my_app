//! 认证相关 FFI 桥接
//!
//! 用户管理、应用管理、权限管理的 C ABI 接口

use std::ffi::{CStr, CString};
use std::os::raw::c_char;

/// 辅助：C 字符串 → Rust String
fn from_c_str(ptr: *const c_char) -> String {
    if ptr.is_null() {
        String::new()
    } else {
        unsafe { CStr::from_ptr(ptr).to_string_lossy().to_string() }
    }
}

/// 辅助：Rust String → C 字符串指针
fn to_c_str(s: &str) -> *mut c_char {
    CString::new(s).unwrap().into_raw()
}

// ============================ 数据库初始化 ============================

/// 初始化认证数据库
/// 输入：数据库路径（可为空，默认 "auth.db"）
/// 输出：JSON 字符串
#[no_mangle]
pub extern "C" fn auth_init(db_path: *const c_char) -> *mut c_char {
    let path = from_c_str(db_path);
    let path_opt = if path.is_empty() { None } else { Some(path.as_str()) };
    
    let rt = tokio::runtime::Runtime::new().unwrap();
    let result = rt.block_on(crate::auth::init_auth_db(path_opt));
    match result {
        Ok(s) => to_c_str(&s),
        Err(e) => to_c_str(&format!("{{\"ok\": false, \"error\": \"{}\"}}", e)),
    }
}

// ============================ 认证 API ============================

/// 用户登录
/// 输入：JSON 字符串 `{"username": "...", "password": "..."}`
/// 输出：JSON 字符串 `{"ok": true, "user_id": ..., "username": "...", "role": "...", "token": "..."}`
#[no_mangle]
pub extern "C" fn auth_login(request_json: *const c_char) -> *mut c_char {
    let req_str = from_c_str(request_json);
    
    // 解析请求
    let req: serde_json::Value = match serde_json::from_str(&req_str) {
        Ok(v) => v,
        Err(e) => return to_c_str(&format!(
            "{{\"ok\": false, \"error\": \"Invalid request: {}\"}}",
            e
        )),
    };
    
    let username = req["username"].as_str().unwrap_or("");
    let password = req["password"].as_str().unwrap_or("");
    
    let rt = tokio::runtime::Runtime::new().unwrap();
    let result = rt.block_on(crate::auth::login(username, password));
    to_c_str(&result)
}

/// 用户登出
/// 输入：token 字符串
/// 输出：JSON 字符串
#[no_mangle]
pub extern "C" fn auth_logout(token: *const c_char) -> *mut c_char {
    let token_str = from_c_str(token);
    
    let rt = tokio::runtime::Runtime::new().unwrap();
    let result = rt.block_on(crate::auth::logout(&token_str));
    to_c_str(&result)
}

/// 获取当前登录用户
/// 输入：token 字符串
/// 输出：JSON 字符串
#[no_mangle]
pub extern "C" fn auth_get_current_user(token: *const c_char) -> *mut c_char {
    let token_str = from_c_str(token);
    
    let rt = tokio::runtime::Runtime::new().unwrap();
    let result = rt.block_on(crate::auth::get_current_user(&token_str));
    to_c_str(&result)
}

// ============================ 用户管理 API ============================

/// 创建用户（仅管理员）
/// 输入：JSON 字符串 `{"username": "...", "password": "...", "role": "..."}`，token
/// 输出：JSON 字符串
#[no_mangle]
pub extern "C" fn auth_create_user(
    request_json: *const c_char,
    token: *const c_char,
) -> *mut c_char {
    let req_str = from_c_str(request_json);
    let token_str = from_c_str(token);
    
    let rt = tokio::runtime::Runtime::new().unwrap();
    let result = rt.block_on(crate::auth::create_user(&req_str, &token_str));
    to_c_str(&result)
}

/// 获取用户列表（仅管理员）
/// 输入：token 字符串
/// 输出：JSON 字符串
#[no_mangle]
pub extern "C" fn auth_get_users(token: *const c_char) -> *mut c_char {
    let token_str = from_c_str(token);
    
    let rt = tokio::runtime::Runtime::new().unwrap();
    let result = rt.block_on(crate::auth::get_users(&token_str));
    to_c_str(&result)
}

/// 更新用户（仅管理员）
/// 输入：user_id, JSON 字符串 `{"password": "...", "role": "..."}`，token
/// 输出：JSON 字符串
#[no_mangle]
pub extern "C" fn auth_update_user(
    user_id: i64,
    request_json: *const c_char,
    token: *const c_char,
) -> *mut c_char {
    let req_str = from_c_str(request_json);
    let token_str = from_c_str(token);
    
    let rt = tokio::runtime::Runtime::new().unwrap();
    let result = rt.block_on(crate::auth::update_user(user_id, &req_str, &token_str));
    to_c_str(&result)
}

/// 删除用户（仅管理员）
/// 输入：user_id, token
/// 输出：JSON 字符串
#[no_mangle]
pub extern "C" fn auth_delete_user(
    user_id: i64,
    token: *const c_char,
) -> *mut c_char {
    let token_str = from_c_str(token);
    
    let rt = tokio::runtime::Runtime::new().unwrap();
    let result = rt.block_on(crate::auth::delete_user(user_id, &token_str));
    to_c_str(&result)
}

// ============================ 应用管理 API ============================

/// 注册应用（仅管理员）
/// 输入：JSON 字符串，token
/// 输出：JSON 字符串
#[no_mangle]
pub extern "C" fn auth_register_app(
    request_json: *const c_char,
    token: *const c_char,
) -> *mut c_char {
    let req_str = from_c_str(request_json);
    let token_str = from_c_str(token);
    
    let rt = tokio::runtime::Runtime::new().unwrap();
    let result = rt.block_on(crate::auth::register_app(&req_str, &token_str));
    to_c_str(&result)
}

/// 获取应用列表
/// 输入：token
/// 输出：JSON 字符串
#[no_mangle]
pub extern "C" fn auth_get_apps(token: *const c_char) -> *mut c_char {
    let token_str = from_c_str(token);
    
    let rt = tokio::runtime::Runtime::new().unwrap();
    let result = rt.block_on(crate::auth::get_apps(&token_str));
    to_c_str(&result)
}

/// 更新应用（仅管理员）
/// 输入：app_id, JSON 字符串，token
/// 输出：JSON 字符串
#[no_mangle]
pub extern "C" fn auth_update_app(
    app_id: i64,
    request_json: *const c_char,
    token: *const c_char,
) -> *mut c_char {
    let req_str = from_c_str(request_json);
    let token_str = from_c_str(token);
    
    let rt = tokio::runtime::Runtime::new().unwrap();
    let result = rt.block_on(crate::auth::update_app(app_id, &req_str, &token_str));
    to_c_str(&result)
}

/// 删除应用（仅管理员）
/// 输入：app_id, token
/// 输出：JSON 字符串
#[no_mangle]
pub extern "C" fn auth_delete_app(
    app_id: i64,
    token: *const c_char,
) -> *mut c_char {
    let token_str = from_c_str(token);
    
    let rt = tokio::runtime::Runtime::new().unwrap();
    let result = rt.block_on(crate::auth::delete_app(app_id, &token_str));
    to_c_str(&result)
}

// ============================ 权限管理 API ============================

/// 为用户分配应用（仅管理员）
/// 输入：user_id, app_id, token
/// 输出：JSON 字符串
#[no_mangle]
pub extern "C" fn auth_assign_app_to_user(
    user_id: i64,
    app_id: i64,
    token: *const c_char,
) -> *mut c_char {
    let token_str = from_c_str(token);
    
    let rt = tokio::runtime::Runtime::new().unwrap();
    let result = rt.block_on(crate::auth::assign_app_to_user(user_id, app_id, &token_str));
    to_c_str(&result)
}

/// 移除用户的应用权限（仅管理员）
/// 输入：user_id, app_id, token
/// 输出：JSON 字符串
#[no_mangle]
pub extern "C" fn auth_remove_app_from_user(
    user_id: i64,
    app_id: i64,
    token: *const c_char,
) -> *mut c_char {
    let token_str = from_c_str(token);
    
    let rt = tokio::runtime::Runtime::new().unwrap();
    let result = rt.block_on(crate::auth::remove_app_from_user(user_id, app_id, &token_str));
    to_c_str(&result)
}

/// 获取用户的应用权限
/// 输入：user_id, token
/// 输出：JSON 字符串
#[no_mangle]
pub extern "C" fn auth_get_user_apps(
    user_id: i64,
    token: *const c_char,
) -> *mut c_char {
    let token_str = from_c_str(token);
    
    let rt = tokio::runtime::Runtime::new().unwrap();
    let result = rt.block_on(crate::auth::get_user_apps(user_id, &token_str));
    to_c_str(&result)
}
