//! Hermes API - Flutter Rust Bridge API functions

use hermes_agent::*;
use once_cell::sync::Lazy;
use std::sync::Arc;
use tokio::sync::Mutex;

/// Global session manager
static SESSION_MANAGER: Lazy<Arc<Mutex<SessionManager>>> =
    Lazy::new(|| Arc::new(Mutex::new(SessionManager::new())));

/// Session info for FRB
pub struct SessionInfo {
    pub id: String,
    pub title: String,
    pub model: String,
    pub message_count: u32,
    pub created_at: String,
    pub updated_at: String,
}

/// Message info for FRB
pub struct MessageInfo {
    pub id: String,
    pub role: String,
    pub content: String,
    pub timestamp: String,
}

/// Initialize hermes agent
#[flutter_rust_bridge::frb(sync)]
pub fn init_hermes() -> Result<String, String> {
    Ok("Hermes Agent 初始化成功".to_string())
}

/// Create a new session
#[flutter_rust_bridge::frb(sync)]
pub fn hermes_create_session(title: String, model: String) -> Result<String, String> {
    let runtime = tokio::runtime::Runtime::new()
        .map_err(|e| format!("创建 runtime 失败: {}", e))?;

    runtime.block_on(async {
        let manager = SESSION_MANAGER.lock().await;
        manager.create(title, model).await.map_err(|e| e.to_string())
    })
}

/// Get all sessions
#[flutter_rust_bridge::frb(sync)]
pub fn hermes_get_sessions() -> Result<Vec<SessionInfo>, String> {
    let runtime = tokio::runtime::Runtime::new()
        .map_err(|e| format!("创建 runtime 失败: {}", e))?;

    runtime.block_on(async {
        let manager = SESSION_MANAGER.lock().await;
        let sessions = manager.list().await.map_err(|e| e.to_string())?;
        Ok(sessions
            .into_iter()
            .map(|s| SessionInfo {
                id: s.id,
                title: s.title,
                model: s.model,
                message_count: s.message_count as u32,
                created_at: s.created_at,
                updated_at: s.updated_at,
            })
            .collect())
    })
}

/// Delete a session
#[flutter_rust_bridge::frb(sync)]
pub fn hermes_delete_session(id: String) -> Result<(), String> {
    let runtime = tokio::runtime::Runtime::new()
        .map_err(|e| format!("创建 runtime 失败: {}", e))?;

    runtime.block_on(async {
        let manager = SESSION_MANAGER.lock().await;
        manager.delete(&id).await.map_err(|e| e.to_string())
    })
}

/// Send a message and get a response
#[flutter_rust_bridge::frb(sync)]
pub fn hermes_send_message(session_id: String, message: String) -> Result<String, String> {
    let runtime = tokio::runtime::Runtime::new()
        .map_err(|e| format!("创建 runtime 失败: {}", e))?;

    runtime.block_on(async {
        let manager = SESSION_MANAGER.lock().await;

        let session = manager.get(&session_id).await.map_err(|e| e.to_string())?;
        let session = session.ok_or("会话不存在")?;

        let mut loop_ = ConversationLoop::new(session);
        let response = loop_
            .process_user_message(&message)
            .await
            .map_err(|e| e.to_string())?;

        Ok(response)
    })
}

/// Get messages for a session
#[flutter_rust_bridge::frb(sync)]
pub fn hermes_get_messages(session_id: String) -> Result<Vec<MessageInfo>, String> {
    let runtime = tokio::runtime::Runtime::new()
        .map_err(|e| format!("创建 runtime 失败: {}", e))?;

    runtime.block_on(async {
        let manager = SESSION_MANAGER.lock().await;
        let messages = manager.get_messages(&session_id).await.map_err(|e| e.to_string())?;
        Ok(messages
            .into_iter()
            .map(|m| MessageInfo {
                id: m.id,
                role: m.role,
                content: m.content,
                timestamp: m.timestamp,
            })
            .collect())
    })
}

/// Set model for a session
#[flutter_rust_bridge::frb(sync)]
pub fn hermes_set_model(session_id: String, model: String) -> Result<(), String> {
    let runtime = tokio::runtime::Runtime::new()
        .map_err(|e| format!("创建 runtime 失败: {}", e))?;

    runtime.block_on(async {
        let manager = SESSION_MANAGER.lock().await;
        manager
            .set_model(&session_id, &model)
            .await
            .map_err(|e| e.to_string())
    })
}
