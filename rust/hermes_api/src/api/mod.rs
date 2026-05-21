//! Hermes API - Flutter Rust Bridge API functions

use hermes_agent::*;
use once_cell::sync::Lazy;
use std::sync::Arc;
use tokio::sync::{Mutex, RwLock};
use futures::StreamExt;

/// Global session manager
static SESSION_MANAGER: Lazy<Arc<Mutex<SessionManager>>> =
    Lazy::new(|| Arc::new(Mutex::new(SessionManager::new())));

/// Global skill manager
static SKILL_MANAGER: Lazy<Arc<RwLock<SkillManager>>> =
    Lazy::new(|| Arc::new(RwLock::new(SkillManager::new())));

/// Global cron scheduler
static CRON_SCHEDULER: Lazy<Arc<RwLock<CronScheduler>>> =
    Lazy::new(|| Arc::new(RwLock::new(CronScheduler::new())));

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

/// Skill info for FRB
pub struct SkillInfoFrb {
    pub id: String,
    pub name: String,
    pub description: String,
    pub trigger_type: String,
    pub usage_count: u32,
}

/// Task info for FRB
pub struct TaskInfoFrb {
    pub id: String,
    pub name: String,
    pub cron_expression: String,
    pub enabled: bool,
    pub last_run: Option<String>,
    pub next_run: Option<String>,
}

/// Model info for FRB
pub struct ModelInfoFrb {
    pub id: String,
    pub name: String,
    pub provider: String,
    pub context_length: u32,
}

/// Stream sink for FRB
pub struct StreamSink {
    pub sink: flutter_rust_bridge::StreamSink<String>,
}

// ============================================================================
// Session Management
// ============================================================================

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

// ============================================================================
// Skill Management
// ============================================================================

/// Create a new skill
#[flutter_rust_bridge::frb(sync)]
pub fn hermes_create_skill(
    name: String,
    description: String,
    trigger_type: String,
    trigger_value: String,
) -> Result<String, String> {
    let trigger = match trigger_type.as_str() {
        "keyword" => SkillTrigger::Keyword(trigger_value),
        "pattern" => SkillTrigger::Pattern(trigger_value),
        "auto" => SkillTrigger::Auto,
        "manual" => SkillTrigger::Manual,
        _ => SkillTrigger::Manual,
    };

    let runtime = tokio::runtime::Runtime::new()
        .map_err(|e| format!("创建 runtime 失败: {}", e))?;

    runtime.block_on(async {
        let manager = SKILL_MANAGER.read().await;
        manager
            .create(name, description, trigger)
            .await
            .map_err(|e| e.to_string())
    })
}

/// Get all skills
#[flutter_rust_bridge::frb(sync)]
pub fn hermes_get_skills() -> Result<Vec<SkillInfoFrb>, String> {
    let runtime = tokio::runtime::Runtime::new()
        .map_err(|e| format!("创建 runtime 失败: {}", e))?;

    runtime.block_on(async {
        let manager = SKILL_MANAGER.read().await;
        let skills = manager.list().await.map_err(|e| e.to_string())?;
        Ok(skills
            .into_iter()
            .map(|s| SkillInfoFrb {
                id: s.id,
                name: s.name,
                description: s.description,
                trigger_type: s.trigger_type,
                usage_count: s.usage_count,
            })
            .collect())
    })
}

/// Delete a skill
#[flutter_rust_bridge::frb(sync)]
pub fn hermes_delete_skill(id: String) -> Result<(), String> {
    let runtime = tokio::runtime::Runtime::new()
        .map_err(|e| format!("创建 runtime 失败: {}", e))?;

    runtime.block_on(async {
        let manager = SKILL_MANAGER.read().await;
        manager.delete(&id).await.map_err(|e| e.to_string())
    })
}

// ============================================================================
// Cron Scheduler
// ============================================================================

/// Create a scheduled task
#[flutter_rust_bridge::frb(sync)]
pub fn hermes_create_task(
    name: String,
    cron_expression: String,
    command: String,
) -> Result<String, String> {
    let runtime = tokio::runtime::Runtime::new()
        .map_err(|e| format!("创建 runtime 失败: {}", e))?;

    runtime.block_on(async {
        let scheduler = CRON_SCHEDULER.read().await;
        scheduler
            .add_task(name, cron_expression, command)
            .await
            .map_err(|e| e.to_string())
    })
}

/// Get all tasks
#[flutter_rust_bridge::frb(sync)]
pub fn hermes_get_tasks() -> Result<Vec<TaskInfoFrb>, String> {
    let runtime = tokio::runtime::Runtime::new()
        .map_err(|e| format!("创建 runtime 失败: {}", e))?;

    runtime.block_on(async {
        let scheduler = CRON_SCHEDULER.read().await;
        let tasks = scheduler.list_tasks().await.map_err(|e| e.to_string())?;
        Ok(tasks
            .into_iter()
            .map(|t| TaskInfoFrb {
                id: t.id,
                name: t.name,
                cron_expression: t.cron_expression,
                enabled: t.enabled,
                last_run: t.last_run,
                next_run: t.next_run,
            })
            .collect())
    })
}

/// Delete a task
#[flutter_rust_bridge::frb(sync)]
pub fn hermes_delete_task(id: String) -> Result<(), String> {
    let runtime = tokio::runtime::Runtime::new()
        .map_err(|e| format!("创建 runtime 失败: {}", e))?;

    runtime.block_on(async {
        let scheduler = CRON_SCHEDULER.read().await;
        scheduler.delete_task(&id).await.map_err(|e| e.to_string())
    })
}

/// Enable a task
#[flutter_rust_bridge::frb(sync)]
pub fn hermes_enable_task(id: String) -> Result<(), String> {
    let runtime = tokio::runtime::Runtime::new()
        .map_err(|e| format!("创建 runtime 失败: {}", e))?;

    runtime.block_on(async {
        let scheduler = CRON_SCHEDULER.read().await;
        scheduler.enable_task(&id).await.map_err(|e| e.to_string())
    })
}

/// Disable a task
#[flutter_rust_bridge::frb(sync)]
pub fn hermes_disable_task(id: String) -> Result<(), String> {
    let runtime = tokio::runtime::Runtime::new()
        .map_err(|e| format!("创建 runtime 失败: {}", e))?;

    runtime.block_on(async {
        let scheduler = CRON_SCHEDULER.read().await;
        scheduler.disable_task(&id).await.map_err(|e| e.to_string())
    })
}

/// Execute a task manually
#[flutter_rust_bridge::frb(sync)]
pub fn hermes_execute_task(id: String) -> Result<String, String> {
    let runtime = tokio::runtime::Runtime::new()
        .map_err(|e| format!("创建 runtime 失败: {}", e))?;

    runtime.block_on(async {
        let scheduler = CRON_SCHEDULER.read().await;
        scheduler.execute_task(&id).await.map_err(|e| e.to_string())
    })
}

// ============================================================================
// Model Info
// ============================================================================

/// Get available models
#[flutter_rust_bridge::frb(sync)]
pub fn hermes_get_models() -> Result<Vec<ModelInfoFrb>, String> {
    use hermes_agent::llm::list_models;
    let models = list_models();
    Ok(models
        .into_iter()
        .map(|m| ModelInfoFrb {
            id: m.id,
            name: m.name,
            provider: m.provider,
            context_length: m.context_length,
        })
        .collect())
}