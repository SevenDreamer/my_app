//! 数据库模块 — 统一处理 SQLite / MySQL / PostgreSQL
//!
//! 通过 FFI 暴露给 Dart 侧，所有复杂数据用 JSON 字符串传递。

use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::Mutex;

use serde::{Deserialize, Serialize};
use serde_json;
use sqlx::{AnyPool, Executor, Row};
use uuid::Uuid;

// ============================ 类型定义 ============================

/// 数据库连接配置（对应 Dart 侧 `DbConnectionConfig`）
#[derive(Debug, Clone, Deserialize)]
pub struct DbConfig {
    pub db_type: String, // "sqlite" | "mysql" | "postgresql" | "mongodb"
    pub host: Option<String>,
    pub port: Option<u16>,
    pub username: Option<String>,
    pub password: Option<String>,
    pub database_name: Option<String>,
    pub file_path: Option<String>, // SQLite 专用
}

/// 数据库信息
#[derive(Debug, Clone, Serialize)]
pub struct DbInfo {
    pub name: String,
    pub tables_json: String, // JSON 字符串，避免 FFI 复杂类型
}

/// 表信息
#[derive(Debug, Clone, Serialize)]
pub struct TableInfoOut {
    pub name: String,
    pub row_count: i64,
    pub fields_json: String,
}

// ============================ 连接管理 ============================

struct ConnectionEntry {
    config: DbConfig,
    pool: Option<AnyPool>,
}

static CONNECTIONS: once_cell::sync::Lazy<Arc<Mutex<HashMap<String, ConnectionEntry>>>> =
    once_cell::sync::Lazy::new(|| Arc::new(Mutex::new(HashMap::new())));

/// 生成连接 ID
fn new_conn_id() -> String {
    Uuid::new_v4().to_string()
}

// ============================ 内部实现 ============================

async fn connect_sqlite(config: &DbConfig) -> anyhow::Result<AnyPool> {
    let path = config.file_path.as_deref().unwrap_or(":memory:");
    let url = format!("sqlite:{}", path);
    let pool = AnyPool::connect(&url).await?;
    Ok(pool)
}

async fn connect_mysql(config: &DbConfig) -> anyhow::Result<AnyPool> {
    let host = config.host.as_deref().unwrap_or("localhost");
    let port = config.port.unwrap_or(3306);
    let db = config.database_name.as_deref().unwrap_or("mysql");
    let username = config.username.as_deref().unwrap_or("root");
    let password = config.password.as_deref().unwrap_or("");

    let url = format!(
        "mysql://{}:{}@{}:{}/{}",
        username,
        urlencoding::encode(password),
        host,
        port,
        db
    );
    let pool = AnyPool::connect(&url).await?;
    Ok(pool)
}

async fn connect_postgresql(config: &DbConfig) -> anyhow::Result<AnyPool> {
    let host = config.host.as_deref().unwrap_or("localhost");
    let port = config.port.unwrap_or(5432);
    let db = config.database_name.as_deref().unwrap_or("postgres");
    let username = config.username.as_deref().unwrap_or("postgres");
    let password = config.password.as_deref().unwrap_or("");

    let url = format!(
        "postgresql://{}:{}@{}:{}/{}",
        username,
        urlencoding::encode(password),
        host,
        port,
        db
    );
    let pool = AnyPool::connect(&url).await?;
    Ok(pool)
}

// ============================ 对外 FFI 接口 ============================

/// 连接数据库
/// 输入：JSON 格式的 DbConfig
/// 输出：JSON 字符串 `{"ok": true, "conn_id": "..."}` 或 `{"ok": false, "error": "..."}`
pub async fn db_connect(config_json: &str) -> String {
    let config: DbConfig = match serde_json::from_str(config_json) {
        Ok(c) => c,
        Err(e) => return json_err(&format!("Invalid config: {}", e)),
    };

    let conn_id = new_conn_id();
    let pool = match config.db_type.as_str() {
        "sqlite" => match connect_sqlite(&config).await {
            Ok(p) => Some(p),
            Err(e) => return json_err(&format!("SQLite connect failed: {}", e)),
        },
        "mysql" => match connect_mysql(&config).await {
            Ok(p) => Some(p),
            Err(e) => return json_err(&format!("MySQL connect failed: {}", e)),
        },
        "postgresql" => match connect_postgresql(&config).await {
            Ok(p) => Some(p),
            Err(e) => return json_err(&format!("PostgreSQL connect failed: {}", e)),
        },
        "mongodb" => {
            return json_err("MongoDB not yet implemented in Rust side");
        }
        _ => return json_err(&format!("Unsupported db_type: {}", config.db_type)),
    };

    let mut conns = CONNECTIONS.lock().await;
    conns.insert(
        conn_id.clone(),
        ConnectionEntry {
            config: config.clone(),
            pool,
        },
    );

    serde_json::json!({
        "ok": true,
        "conn_id": conn_id,
    })
    .to_string()
}

/// 断开连接
pub async fn db_disconnect(conn_id: &str) -> String {
    let mut conns = CONNECTIONS.lock().await;
    if conns.remove(conn_id).is_some() {
        json_ok(true)
    } else {
        json_err(&format!("Connection not found: {}", conn_id))
    }
}

/// 获取所有数据库列表
pub async fn db_get_databases(conn_id: &str) -> String {
    let conns = CONNECTIONS.lock().await;
    let entry = match conns.get(conn_id) {
        Some(e) => e,
        None => return json_err(&format!("Connection not found: {}", conn_id)),
    };

    let pool = match &entry.pool {
        Some(p) => p,
        None => return json_err("No active connection pool"),
    };

    let db_type = &entry.config.db_type;
    let result = match db_type.as_str() {
        "sqlite" => {
            match pool.fetch_all("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'").await {
                Ok(rows) => {
                    let tables: Vec<serde_json::Value> = rows.iter().map(|row| {
                        let name: String = row.get(0);
                        serde_json::json!({"name": name, "row_count": 0})
                    }).collect();
                    Ok(serde_json::json!(tables))
                }
                Err(e) => Err(format!("Failed to get tables: {}", e)),
            }
        }
        "mysql" => {
            match pool.fetch_all("SHOW DATABASES").await {
                Ok(rows) => {
                    let dbs: Vec<String> = rows.iter()
                        .filter_map(|row| {
                            let name: String = row.get(0);
                            if ["information_schema", "mysql", "performance_schema", "sys"].contains(&name.as_str()) {
                                None
                            } else {
                                Some(name)
                            }
                        })
                        .collect();
                    let result: Vec<serde_json::Value> = dbs.iter()
                        .map(|n| serde_json::json!({"name": n, "tables": []}))
                        .collect();
                    Ok(serde_json::json!(result))
                }
                Err(e) => Err(format!("SHOW DATABASES failed: {}", e)),
            }
        }
        "postgresql" => {
            match pool.fetch_all("SELECT datname FROM pg_database WHERE datistemplate = false").await {
                Ok(rows) => {
                    let dbs: Vec<String> = rows.iter()
                        .filter_map(|row| {
                            let name: String = row.get(0);
                            Some(name)
                        })
                        .collect();
                    let result: Vec<serde_json::Value> = dbs.iter()
                        .map(|n| serde_json::json!({"name": n, "tables": []}))
                        .collect();
                    Ok(serde_json::json!(result))
                }
                Err(e) => Err(format!("pg_database query failed: {}", e)),
            }
        }
        _ => Err(format!("Unsupported db_type: {}", db_type)),
    };

    drop(conns);

    match result {
        Ok(data) => json_ok(data),
        Err(e) => json_err(&e),
    }
}

/// 获取指定数据库的表列表（暂未完整实现）
pub async fn db_get_tables(_conn_id: &str, _database_name: &str) -> String {
    json_err("db_get_tables: not yet fully implemented")
}

/// 获取表的字段信息（暂未完整实现）
pub async fn db_get_fields(_conn_id: &str, _database_name: &str, _table_name: &str) -> String {
    json_err("db_get_fields: not yet fully implemented")
}

/// 获取表数据（分页，暂未完整实现）
pub async fn db_get_table_data(
    _conn_id: &str,
    _database_name: &str,
    _table_name: &str,
    _limit: i64,
    _offset: i64,
) -> String {
    json_err("db_get_table_data: not yet fully implemented")
}

/// 测试连接
pub async fn db_test_connection(config_json: &str) -> String {
    let config: DbConfig = match serde_json::from_str(config_json) {
        Ok(c) => c,
        Err(e) => return json_err(&format!("Invalid config: {}", e)),
    };

    let result = match config.db_type.as_str() {
        "sqlite" => connect_sqlite(&config).await,
        "mysql" => connect_mysql(&config).await,
        "postgresql" => connect_postgresql(&config).await,
        _ => return json_err(&format!("Unsupported db_type: {}", config.db_type)),
    };

    match result {
        Ok(_) => json_ok(true),
        Err(e) => json_err(&format!("Connection test failed: {}", e)),
    }
}

// ============================ 工具函数 ============================

fn json_ok<T: Serialize>(value: T) -> String {
    serde_json::json!({"ok": true, "data": value}).to_string()
}

fn json_err(msg: &str) -> String {
    serde_json::json!({"ok": false, "error": msg}).to_string()
}
