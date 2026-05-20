//! 认证相关 API
//!
//! 直接连接 PostgreSQL 数据库进行用户认证

use serde::{Deserialize, Serialize};
use sqlx::postgres::PgPoolOptions;
use sqlx::PgPool;
use std::sync::Arc;
use tokio::sync::Mutex;
use once_cell::sync::Lazy;
use bcrypt::{verify, DEFAULT_COST};
use uuid::Uuid;

// ============================
// 类型定义
// ============================

/// 登录成功后的用户信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserInfo {
    pub user_id: i32,
    pub username: String,
    pub role: String,
}

/// 数据库用户记录
#[derive(Debug, sqlx::FromRow)]
struct DbUser {
    id: i32,
    username: String,
    password_hash: String,
    role: String,
}

// ============================
// 全局状态
// ============================

/// PostgreSQL 连接池
static DB_POOL: Lazy<Arc<Mutex<Option<PgPool>>>> =
    Lazy::new(|| Arc::new(Mutex::new(None)));

/// 当前登录用户（内存中保存 token）
static CURRENT_USER: Lazy<Arc<Mutex<Option<LoggedInUser>>>> =
    Lazy::new(|| Arc::new(Mutex::new(None)));

#[derive(Debug, Clone)]
struct LoggedInUser {
    user_id: i32,
    username: String,
    role: String,
    token: String,
}

// ============================
// 初始化
// ============================

/// 初始化 PostgreSQL 连接池
#[flutter_rust_bridge::frb(sync)]
pub fn init_auth_db() -> Result<String, String> {
    let runtime = tokio::runtime::Runtime::new()
        .map_err(|e| format!("创建 tokio runtime 失败: {}", e))?;

    runtime.block_on(async {
        let db_url = "postgres://seven:dQt6yMsCgu@159.75.98.152:5433/my_app";

        let pool = PgPoolOptions::new()
            .max_connections(5)
            .connect(db_url)
            .await
            .map_err(|e| format!("连接 PostgreSQL 失败: {}", e))?;

        // 测试连接
        sqlx::query("SELECT 1")
            .fetch_one(&pool)
            .await
            .map_err(|e| format!("数据库连接测试失败: {}", e))?;

        // 保存连接池
        let mut db = DB_POOL.lock().await;
        *db = Some(pool);

        Ok("PostgreSQL 连接成功".to_string())
    })
}

/// 获取数据库连接池
async fn get_db_pool() -> Result<PgPool, String> {
    let db = DB_POOL.lock().await;
    match *db {
        Some(ref pool) => Ok(pool.clone()),
        None => Err("数据库未初始化，请先调用 init_auth_db".to_string()),
    }
}

// ============================
// 认证 API
// ============================

/// 用户登录
#[flutter_rust_bridge::frb(sync)]
pub fn login(username: String, password: String) -> Result<UserInfo, String> {
    let runtime = tokio::runtime::Runtime::new()
        .map_err(|e| format!("创建 tokio runtime 失败: {}", e))?;

    runtime.block_on(async {
        let pool = get_db_pool().await?;

        // 查询用户
        let user: Option<DbUser> = sqlx::query_as(
            "SELECT id, username, password_hash, role FROM users WHERE username = $1"
        )
        .bind(&username)
        .fetch_optional(&pool)
        .await
        .map_err(|e| format!("查询用户失败: {}", e))?;

        match user {
            Some(user) => {
                // 验证密码
                let valid = verify(&password, &user.password_hash)
                    .map_err(|e| format!("密码验证失败: {}", e))?;

                if !valid {
                    return Err("用户名或密码错误".to_string());
                }

                // 生成 token
                let token = Uuid::new_v4().to_string();

                // 保存当前登录用户
                let mut current = CURRENT_USER.lock().await;
                *current = Some(LoggedInUser {
                    user_id: user.id,
                    username: user.username.clone(),
                    role: user.role.clone(),
                    token: token.clone(),
                });

                Ok(UserInfo {
                    user_id: user.id,
                    username: user.username,
                    role: user.role,
                })
            }
            None => Err("用户名或密码错误".to_string()),
        }
    })
}

/// 验证 token 是否有效
#[flutter_rust_bridge::frb(sync)]
pub fn verify_token(token: String) -> Result<UserInfo, String> {
    let runtime = tokio::runtime::Runtime::new()
        .map_err(|e| format!("创建 tokio runtime 失败: {}", e))?;

    runtime.block_on(async {
        let current = CURRENT_USER.lock().await;
        match *current {
            Some(ref user) if user.token == token => {
                Ok(UserInfo {
                    user_id: user.user_id,
                    username: user.username.clone(),
                    role: user.role.clone(),
                })
            }
            _ => Err("token 无效或已过期".to_string()),
        }
    })
}

/// 用户登出
#[flutter_rust_bridge::frb(sync)]
pub fn logout(token: String) -> Result<String, String> {
    let runtime = tokio::runtime::Runtime::new()
        .map_err(|e| format!("创建 tokio runtime 失败: {}", e))?;

    runtime.block_on(async {
        let mut current = CURRENT_USER.lock().await;
        match *current {
            Some(ref user) if user.token == token => {
                *current = None;
                Ok("登出成功".to_string())
            }
            _ => Err("无效的 token".to_string()),
        }
    })
}

/// 获取当前登录用户
#[flutter_rust_bridge::frb(sync)]
pub fn get_current_user(token: String) -> Result<UserInfo, String> {
    verify_token(token)
}