//! 用户认证和授权模块
//!
//! 管理用户、应用权限和系统访问控制

use std::path::PathBuf;
use std::sync::Arc;
use tokio::sync::Mutex;

use serde::{Deserialize, Serialize};
use serde_json;
use sqlx::{SqlitePool, FromRow};
use bcrypt::{hash, verify, DEFAULT_COST};
use uuid::Uuid;

use once_cell::sync::Lazy;

// ============================ 类型定义 ============================

/// 用户角色
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum UserRole {
    Admin,  // 超级管理员 - 可以看到所有子应用
    User,   // 普通用户 - 只能看到被分配的子应用
}

impl ToString for UserRole {
    fn to_string(&self) -> String {
        match self {
            UserRole::Admin => "admin".to_string(),
            UserRole::User => "user".to_string(),
        }
    }
}

impl From<&str> for UserRole {
    fn from(s: &str) -> Self {
        match s {
            "admin" => UserRole::Admin,
            _ => UserRole::User,
        }
    }
}

/// 用户信息
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct User {
    pub id: i64,
    pub username: String,
    #[serde(skip_serializing)]
    pub password_hash: String,
    pub role: String,
    pub created_at: String,
    pub updated_at: String,
}

/// 应用信息
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct AppInfo {
    pub id: i64,
    pub app_name: String,
    pub display_name: String,
    pub description: Option<String>,
    pub icon: Option<String>,
    pub route: String,
    pub is_active: bool,
    pub created_at: String,
}

/// 用户-应用权限
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct UserAppPermission {
    pub id: i64,
    pub user_id: i64,
    pub app_id: i64,
    pub created_at: String,
}

/// 登录请求
#[derive(Debug, Deserialize)]
pub struct LoginRequest {
    pub username: String,
    pub password: String,
}

/// 登录响应
#[derive(Debug, Serialize)]
pub struct LoginResponse {
    pub ok: bool,
    pub user_id: Option<i64>,
    pub username: Option<String>,
    pub role: Option<String>,
    pub token: Option<String>,
    pub error: Option<String>,
}

/// 创建用户请求
#[derive(Debug, Deserialize)]
pub struct CreateUserRequest {
    pub username: String,
    pub password: String,
    pub role: String,
}

/// 更新用户请求
#[derive(Debug, Deserialize)]
pub struct UpdateUserRequest {
    pub password: Option<String>,
    pub role: Option<String>,
}

// ============================ 全局状态 ============================

static DB_POOL: Lazy<Arc<Mutex<Option<SqlitePool>>>> = 
    Lazy::new(|| Arc::new(Mutex::new(None)));

static CURRENT_USER: Lazy<Arc<Mutex<Option<LoggedInUser>>>> = 
    Lazy::new(|| Arc::new(Mutex::new(None)));

#[derive(Debug, Clone)]
struct LoggedInUser {
    user_id: i64,
    username: String,
    role: String,
    token: String,
}

// ============================ 初始化 ============================

/// 初始化认证数据库
pub async fn init_auth_db(db_path: Option<&str>) -> anyhow::Result<String> {
    let path = db_path.unwrap_or("auth.db");
    let db_path = PathBuf::from(path);
    
    // 确保数据库目录存在
    if let Some(parent) = db_path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    
    let url = format!("sqlite:{}", db_path.display());
    let pool = SqlitePool::connect(&url).await?;
    
    // 创建表
    create_tables(&pool).await?;
    
    // 创建默认超级管理员账号（如果不存在）
    create_default_admin(&pool).await?;
    
    // 保存连接池
    let mut db = DB_POOL.lock().await;
    *db = Some(pool);
    
    Ok(serde_json::json!({
        "ok": true,
        "message": "Auth database initialized",
        "db_path": path
    }).to_string())
}

/// 创建必要的表
async fn create_tables(pool: &SqlitePool) -> anyhow::Result<()> {
    // 创建 users 表
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            role TEXT NOT NULL DEFAULT 'user',
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
        "#
    )
    .execute(pool)
    .await?;
    
    // 创建 apps 表
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS apps (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            app_name TEXT UNIQUE NOT NULL,
            display_name TEXT NOT NULL,
            description TEXT,
            icon TEXT,
            route TEXT NOT NULL,
            is_active BOOLEAN DEFAULT 1,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
        "#
    )
    .execute(pool)
    .await?;
    
    // 创建 user_app_permissions 表
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS user_app_permissions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            app_id INTEGER NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (app_id) REFERENCES apps(id) ON DELETE CASCADE,
            UNIQUE(user_id, app_id)
        )
        "#
    )
    .execute(pool)
    .await?;
    
    Ok(())
}

/// 创建默认超级管理员账号
async fn create_default_admin(pool: &SqlitePool) -> anyhow::Result<()> {
    let count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM users WHERE role = 'admin'")
        .fetch_one(pool)
        .await?;
    
    if count.0 == 0 {
        // 创建默认管理员账号：用户名 admin，密码 admin123
        let password_hash = hash("admin123", DEFAULT_COST)?;
        sqlx::query(
            "INSERT INTO users (username, password_hash, role) VALUES (?, ?, ?)"
        )
        .bind("admin")
        .bind(password_hash)
        .bind("admin")
        .execute(pool)
        .await?;
        
        eprintln!("Created default admin account: username=admin, password=admin123");
    }
    
    Ok(())
}

// ============================ 辅助函数 ============================

/// 获取数据库连接池
async fn get_db_pool() -> anyhow::Result<SqlitePool> {
    let db = DB_POOL.lock().await;
    match *db {
        Some(ref pool) => Ok(pool.clone()),
        None => Err(anyhow::anyhow!("Auth database not initialized")),
    }
}

/// 生成 token
fn generate_token() -> String {
    Uuid::new_v4().to_string()
}

// ============================ 认证 API ============================

/// 用户登录
pub async fn login(username: &str, password: &str) -> String {
    let result = match do_login(username, password).await {
        Ok(resp) => serde_json::to_value(resp).unwrap(),
        Err(e) => serde_json::json!({
            "ok": false,
            "error": e.to_string()
        }),
    };
    result.to_string()
}

async fn do_login(username: &str, password: &str) -> anyhow::Result<LoginResponse> {
    let pool = get_db_pool().await?;
    
    let user: Option<User> = sqlx::query_as("SELECT id, username, password_hash, role, created_at, updated_at FROM users WHERE username = ?")
        .bind(username)
        .fetch_optional(&pool)
        .await?;
    
    match user {
        Some(user) => {
            // 验证密码
            if verify(password, &user.password_hash)? {
                let token = generate_token();
                
                // 保存当前登录用户
                let mut current = CURRENT_USER.lock().await;
                *current = Some(LoggedInUser {
                    user_id: user.id,
                    username: user.username.clone(),
                    role: user.role.clone(),
                    token: token.clone(),
                });
                
                Ok(LoginResponse {
                    ok: true,
                    user_id: Some(user.id),
                    username: Some(user.username),
                    role: Some(user.role),
                    token: Some(token),
                    error: None,
                })
            } else {
                Ok(LoginResponse {
                    ok: false,
                    user_id: None,
                    username: None,
                    role: None,
                    token: None,
                    error: Some("Invalid password".to_string()),
                })
            }
        }
        None => Ok(LoginResponse {
            ok: false,
            user_id: None,
            username: None,
            role: None,
            token: None,
            error: Some("User not found".to_string()),
        }),
    }
}

/// 用户登出
pub async fn logout(token: &str) -> String {
    let mut current = CURRENT_USER.lock().await;
    if let Some(ref user) = *current {
        if user.token == token {
            *current = None;
            return json_ok(true);
        }
    }
    json_err("Invalid token")
}

/// 获取当前登录用户
pub async fn get_current_user(token: &str) -> String {
    let current = CURRENT_USER.lock().await;
    if let Some(ref user) = *current {
        if user.token == token {
            return serde_json::json!({
                "ok": true,
                "user_id": user.user_id,
                "username": user.username,
                "role": user.role
            }).to_string();
        }
    }
    json_err("Not logged in")
}

// ============================ 用户管理 API ============================

/// 创建用户（仅管理员）
pub async fn create_user(request_json: &str, token: &str) -> String {
    // 验证权限
    if !check_admin_permission(token).await {
        return json_err("Permission denied: admin only");
    }
    
    let req: CreateUserRequest = match serde_json::from_str(request_json) {
        Ok(r) => r,
        Err(e) => return json_err(&format!("Invalid request: {}", e)),
    };
    
    let pool = match get_db_pool().await {
        Ok(p) => p,
        Err(e) => return json_err(&e.to_string()),
    };
    
    // 检查用户名是否已存在
    let exists: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM users WHERE username = ?")
        .bind(&req.username)
        .fetch_one(&pool)
        .await
        .unwrap_or((0,));
    
    if exists.0 > 0 {
        return json_err("Username already exists");
    }
    
    // 创建用户
    let password_hash = match hash(&req.password, DEFAULT_COST) {
        Ok(h) => h,
        Err(e) => return json_err(&format!("Password hash failed: {}", e)),
    };
    
    let result = sqlx::query(
        "INSERT INTO users (username, password_hash, role) VALUES (?, ?, ?)"
    )
    .bind(&req.username)
    .bind(&password_hash)
    .bind(&req.role)
    .execute(&pool)
    .await;
    
    match result {
        Ok(_) => json_ok(true),
        Err(e) => json_err(&format!("Create user failed: {}", e)),
    }
}

/// 获取用户列表
pub async fn get_users(token: &str) -> String {
    // 验证权限
    if !check_admin_permission(token).await {
        return json_err("Permission denied: admin only");
    }
    
    let pool = match get_db_pool().await {
        Ok(p) => p,
        Err(e) => return json_err(&e.to_string()),
    };
    
    let users: Vec<User> = sqlx::query_as("SELECT id, username, password_hash, role, created_at, updated_at FROM users ORDER BY id")
        .fetch_all(&pool)
        .await
        .unwrap_or_default();
    
    let users_json: Vec<serde_json::Value> = users.iter().map(|user| {
        serde_json::json!({
            "id": user.id,
            "username": user.username,
            "role": user.role,
            "created_at": user.created_at,
            "updated_at": user.updated_at
        })
    }).collect();
    
    json_ok(users_json)
}

/// 更新用户（仅管理员）
pub async fn update_user(user_id: i64, request_json: &str, token: &str) -> String {
    // 验证权限
    if !check_admin_permission(token).await {
        return json_err("Permission denied: admin only");
    }
    
    let req: UpdateUserRequest = match serde_json::from_str(request_json) {
        Ok(r) => r,
        Err(e) => return json_err(&format!("Invalid request: {}", e)),
    };
    
    let pool = match get_db_pool().await {
        Ok(p) => p,
        Err(e) => return json_err(&e.to_string()),
    };
    
    // 构建更新 SQL
    let mut sets = Vec::new();
    let mut params = Vec::new();
    
    if let Some(ref password) = req.password {
        let password_hash = match hash(password, DEFAULT_COST) {
            Ok(h) => h,
            Err(e) => return json_err(&format!("Password hash failed: {}", e)),
        };
        sets.push("password_hash = ?");
        params.push(password_hash);
    }
    
    if let Some(ref role) = req.role {
        sets.push("role = ?");
        params.push(role.clone());
    }
    
    if sets.is_empty() {
        return json_err("No fields to update");
    }
    
    sets.push("updated_at = CURRENT_TIMESTAMP");
    
    let sql = format!("UPDATE users SET {} WHERE id = ?", sets.join(", "));
    params.push(user_id.to_string());
    
    let mut query = sqlx::query(&sql);
    for param in params {
        query = query.bind(param);
    }
    
    let result = query.execute(&pool).await;
    
    match result {
        Ok(_) => json_ok(true),
        Err(e) => json_err(&format!("Update user failed: {}", e)),
    }
}

/// 删除用户（仅管理员）
pub async fn delete_user(user_id: i64, token: &str) -> String {
    // 验证权限
    if !check_admin_permission(token).await {
        return json_err("Permission denied: admin only");
    }
    
    let pool = match get_db_pool().await {
        Ok(p) => p,
        Err(e) => return json_err(&e.to_string()),
    };
    
    let result = sqlx::query("DELETE FROM users WHERE id = ?")
        .bind(user_id)
        .execute(&pool)
        .await;
    
    match result {
        Ok(_) => json_ok(true),
        Err(e) => json_err(&format!("Delete user failed: {}", e)),
    }
}

// ============================ 应用管理 API ============================

/// 注册应用（仅管理员）
pub async fn register_app(request_json: &str, token: &str) -> String {
    // 验证权限
    if !check_admin_permission(token).await {
        return json_err("Permission denied: admin only");
    }
    
    let app: AppInfo = match serde_json::from_str(request_json) {
        Ok(a) => a,
        Err(e) => return json_err(&format!("Invalid request: {}", e)),
    };
    
    let pool = match get_db_pool().await {
        Ok(p) => p,
        Err(e) => return json_err(&e.to_string()),
    };
    
    let result = sqlx::query(
        "INSERT INTO apps (app_name, display_name, description, icon, route, is_active) VALUES (?, ?, ?, ?, ?, ?)"
    )
    .bind(&app.app_name)
    .bind(&app.display_name)
    .bind(&app.description)
    .bind(&app.icon)
    .bind(&app.route)
    .bind(app.is_active)
    .execute(&pool)
    .await;
    
    match result {
        Ok(_) => json_ok(true),
        Err(e) => json_err(&format!("Register app failed: {}", e)),
    }
}

/// 获取应用列表
pub async fn get_apps(token: &str) -> String {
    let pool = match get_db_pool().await {
        Ok(p) => p,
        Err(e) => return json_err(&e.to_string()),
    };
    
    // 检查用户权限
    let current = CURRENT_USER.lock().await;
    let user_role = match *current {
        Some(ref user) if user.token == token => user.role.clone(),
        _ => return json_err("Not logged in"),
    };
    drop(current);
    
    let apps: Vec<AppInfo> = if user_role == "admin" {
        // 管理员可以看到所有应用
        sqlx::query_as("SELECT id, app_name, display_name, description, icon, route, is_active, created_at FROM apps WHERE is_active = 1")
            .fetch_all(&pool)
            .await
            .unwrap_or_default()
    } else {
        // 普通用户只能看到被分配的应用
        let user_id = match *CURRENT_USER.lock().await {
            Some(ref user) if user.token == token => user.user_id,
            _ => return json_err("Not logged in"),
        };
        
        sqlx::query_as(
            r#"
            SELECT a.id, a.app_name, a.display_name, a.description, a.icon, a.route, a.is_active, a.created_at
            FROM apps a
            INNER JOIN user_app_permissions p ON a.id = p.app_id
            WHERE p.user_id = ? AND a.is_active = 1
            "#
        )
        .bind(user_id)
        .fetch_all(&pool)
        .await
        .unwrap_or_default()
    };
    
    let apps_json: Vec<serde_json::Value> = apps.iter().map(|app| {
        serde_json::json!({
            "id": app.id,
            "app_name": app.app_name,
            "display_name": app.display_name,
            "description": app.description,
            "icon": app.icon,
            "route": app.route,
            "is_active": app.is_active,
            "created_at": app.created_at
        })
    }).collect();
    
    json_ok(apps_json)
}

/// 更新应用（仅管理员）
pub async fn update_app(app_id: i64, request_json: &str, token: &str) -> String {
    // 验证权限
    if !check_admin_permission(token).await {
        return json_err("Permission denied: admin only");
    }
    
    let app: AppInfo = match serde_json::from_str(request_json) {
        Ok(a) => a,
        Err(e) => return json_err(&format!("Invalid request: {}", e)),
    };
    
    let pool = match get_db_pool().await {
        Ok(p) => p,
        Err(e) => return json_err(&e.to_string()),
    };
    
    let result = sqlx::query(
        "UPDATE apps SET display_name = ?, description = ?, icon = ?, route = ?, is_active = ? WHERE id = ?"
    )
    .bind(&app.display_name)
    .bind(&app.description)
    .bind(&app.icon)
    .bind(&app.route)
    .bind(app.is_active)
    .bind(app_id)
    .execute(&pool)
    .await;
    
    match result {
        Ok(_) => json_ok(true),
        Err(e) => json_err(&format!("Update app failed: {}", e)),
    }
}

/// 删除应用（仅管理员）
pub async fn delete_app(app_id: i64, token: &str) -> String {
    // 验证权限
    if !check_admin_permission(token).await {
        return json_err("Permission denied: admin only");
    }
    
    let pool = match get_db_pool().await {
        Ok(p) => p,
        Err(e) => return json_err(&e.to_string()),
    };
    
    let result = sqlx::query("DELETE FROM apps WHERE id = ?")
        .bind(app_id)
        .execute(&pool)
        .await;
    
    match result {
        Ok(_) => json_ok(true),
        Err(e) => json_err(&format!("Delete app failed: {}", e)),
    }
}

// ============================ 权限管理 API ============================

/// 为用户分配应用（仅管理员）
pub async fn assign_app_to_user(user_id: i64, app_id: i64, token: &str) -> String {
    // 验证权限
    if !check_admin_permission(token).await {
        return json_err("Permission denied: admin only");
    }
    
    let pool = match get_db_pool().await {
        Ok(p) => p,
        Err(e) => return json_err(&e.to_string()),
    };
    
    let result = sqlx::query(
        "INSERT OR IGNORE INTO user_app_permissions (user_id, app_id) VALUES (?, ?)"
    )
    .bind(user_id)
    .bind(app_id)
    .execute(&pool)
    .await;
    
    match result {
        Ok(_) => json_ok(true),
        Err(e) => json_err(&format!("Assign app failed: {}", e)),
    }
}

/// 移除用户的应用权限（仅管理员）
pub async fn remove_app_from_user(user_id: i64, app_id: i64, token: &str) -> String {
    // 验证权限
    if !check_admin_permission(token).await {
        return json_err("Permission denied: admin only");
    }
    
    let pool = match get_db_pool().await {
        Ok(p) => p,
        Err(e) => return json_err(&e.to_string()),
    };
    
    let result = sqlx::query(
        "DELETE FROM user_app_permissions WHERE user_id = ? AND app_id = ?"
    )
    .bind(user_id)
    .bind(app_id)
    .execute(&pool)
    .await;
    
    match result {
        Ok(_) => json_ok(true),
        Err(e) => json_err(&format!("Remove app failed: {}", e)),
    }
}

/// 获取用户的应用权限
pub async fn get_user_apps(user_id: i64, token: &str) -> String {
    // 验证权限（管理员可以查看所有用户，普通用户只能查看自己）
    let current = CURRENT_USER.lock().await;
    let (is_admin, current_user_id) = match *current {
        Some(ref user) if user.token == token => {
            (user.role == "admin", user.user_id)
        }
        _ => return json_err("Not logged in"),
    };
    drop(current);
    
    if !is_admin && current_user_id != user_id {
        return json_err("Permission denied");
    }
    
    let pool = match get_db_pool().await {
        Ok(p) => p,
        Err(e) => return json_err(&e.to_string()),
    };
    
    let apps: Vec<AppInfo> = sqlx::query_as(
        r#"
        SELECT a.id, a.app_name, a.display_name, a.description, a.icon, a.route, a.is_active, a.created_at
        FROM apps a
        INNER JOIN user_app_permissions p ON a.id = p.app_id
        WHERE p.user_id = ?
        "#
    )
    .bind(user_id)
    .fetch_all(&pool)
    .await
    .unwrap_or_default();
    
    let apps_json: Vec<serde_json::Value> = apps.iter().map(|app| {
        serde_json::json!({
            "id": app.id,
            "app_name": app.app_name,
            "display_name": app.display_name,
            "description": app.description,
            "icon": app.icon,
            "route": app.route,
            "is_active": app.is_active,
            "created_at": app.created_at
        })
    }).collect();
    
    json_ok(apps_json)
}

// ============================ 权限检查 ============================

/// 检查是否为管理员
async fn check_admin_permission(token: &str) -> bool {
    let current = CURRENT_USER.lock().await;
    match *current {
        Some(ref user) if user.token == token => user.role == "admin",
        _ => false,
    }
}

// ============================ 工具函数 ============================

fn json_ok<T: Serialize>(value: T) -> String {
    serde_json::json!({"ok": true, "data": value}).to_string()
}

fn json_err(msg: &str) -> String {
    serde_json::json!({"ok": false, "error": msg}).to_string()
}
