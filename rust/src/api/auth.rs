//! 认证相关 API
//!
//! 此文件由 flutter_rust_bridge_codegen 处理，自动生成 Dart 侧绑定。

use serde::{Deserialize, Serialize};
use reqwest;

// ============================
// 请求/响应类型定义
// ============================

/// 登录请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LoginRequest {
    pub username: String,
    pub password: String,
}

/// 登录响应（后端返回格式）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LoginResponse {
    pub ok: bool,
    pub data: Option<LoginData>,
    pub error: Option<String>,
}

/// 登录成功后的数据
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LoginData {
    pub token: String,
    pub user_id: i64,
    pub username: String,
    pub role: String,
}

/// 用户信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserInfo {
    pub user_id: i64,
    pub username: String,
    pub role: String,
}

// ============================
// 认证 API 函数
// ============================

/// 登录
///
/// - `base_url`: 后端基础 URL（如 `https://api.example.com`）
/// - `username`: 用户名
/// - `password`: 密码
/// - 返回：token 字符串，或错误信息
#[flutter_rust_bridge::frb(sync)]  // 使用 sync 因为在 Rust 内部用 reqwest blocking
pub fn login(base_url: String, username: String, password: String) -> Result<String, String> {
    // 构造完整的登录 URL
    let url = format!("{}/api/auth/login", base_url.trim_end_matches('/'));

    // 创建登录请求体
    let request = LoginRequest { username, password };

    // 发送 HTTP POST 请求（使用 reqwest 异步，但这里用 block_on 转换为同步）
    let runtime = tokio::runtime::Runtime::new()
        .map_err(|e| format!("创建 tokio runtime 失败: {}", e))?;

    runtime.block_on(async {
        let client = reqwest::Client::new();
        
        match client.post(&url).json(&request).send().await {
            Ok(resp) => {
                let status = resp.status();
                if !status.is_success() {
                    return Err(format!("HTTP 错误: {}", status));
                }

                match resp.json::<LoginResponse>().await {
                    Ok(data) => {
                        if data.ok {
                            match data.data {
                                Some(login_data) => Ok(login_data.token),
                                None => Err("登录成功但未返回 token".to_string()),
                            }
                        } else {
                            Err(data.error.unwrap_or_else(|| "登录失败".to_string()))
                        }
                    }
                    Err(e) => Err(format!("解析响应失败: {}", e)),
                }
            }
            Err(e) => Err(format!("请求失败: {}", e)),
        }
    })
}

/// 验证 token 是否有效
///
/// - `base_url`: 后端基础 URL
/// - `token`: 要验证的 token
/// - 返回：用户信息，或错误信息
#[flutter_rust_bridge::frb(sync)]
pub fn verify_token(base_url: String, token: String) -> Result<UserInfo, String> {
    let url = format!("{}/api/auth/verify", base_url.trim_end_matches('/'));

    let runtime = tokio::runtime::Runtime::new()
        .map_err(|e| format!("创建 tokio runtime 失败: {}", e))?;

    runtime.block_on(async {
        let client = reqwest::Client::new();
        
        match client
            .get(&url)
            .header("Authorization", format!("Bearer {}", token))
            .send()
            .await
        {
            Ok(resp) => {
                let status = resp.status();
                if !status.is_success() {
                    return Err(format!("HTTP 错误: {}", status));
                }

                match resp.json::<LoginResponse>().await {
                    Ok(data) => {
                        if data.ok {
                            match data.data {
                                Some(login_data) => Ok(UserInfo {
                                    user_id: login_data.user_id,
                                    username: login_data.username,
                                    role: login_data.role,
                                }),
                                None => Err("验证成功但未返回用户信息".to_string()),
                            }
                        } else {
                            Err(data.error.unwrap_or_else(|| "token 无效".to_string()))
                        }
                    }
                    Err(e) => Err(format!("解析响应失败: {}", e)),
                }
            }
            Err(e) => Err(format!("请求失败: {}", e)),
        }
    })
}

/// 登出（可选：让后端失效 token）
///
/// - `base_url`: 后端基础 URL
/// - `token`: 要登出的 token
#[flutter_rust_bridge::frb(sync)]
pub fn logout(base_url: String, token: String) -> Result<String, String> {
    let url = format!("{}/api/auth/logout", base_url.trim_end_matches('/'));

    let runtime = tokio::runtime::Runtime::new()
        .map_err(|e| format!("创建 tokio runtime 失败: {}", e))?;

    runtime.block_on(async {
        let client = reqwest::Client::new();
        
        match client
            .post(&url)
            .header("Authorization", format!("Bearer {}", token))
            .send()
            .await
        {
            Ok(resp) => {
                let status = resp.status();
                if !status.is_success() {
                    return Err(format!("HTTP 错误: {}", status));
                }
                Ok("登出成功".to_string())
            }
            Err(e) => Err(format!("请求失败: {}", e)),
        }
    })
}
