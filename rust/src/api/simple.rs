//!
//! My App - 对外 FFI API
//!
//! 此文件由 flutter_rust_bridge_codegen 处理，自动生成 Dart 侧绑定。

use serde::{Deserialize, Serialize};

// ============================
// 示例函数（与 frb_generated.rs 兼容，不要删除）
// ============================

#[flutter_rust_bridge::frb(sync)]
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

// ============================
// 类型定义（与 Dart 侧共享）
// ============================

/// 消息角色
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum MessageRole {
    User,
    Assistant,
    System,
}

/// 聊天消息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatMessage {
    pub role: MessageRole,
    pub content: String,
    pub timestamp_ms: i64,
}

/// LLM 请求参数
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LlmRequest {
    pub messages: Vec<ChatMessage>,
    pub model: String,
    pub max_tokens: Option<u32>,
    pub temperature: Option<f32>,
}

/// LLM 响应
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LlmResponse {
    pub content: String,
    pub tokens_used: u32,
}

/// 设备状态
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeviceStatus {
    pub online: bool,
    pub battery_percent: i32,
    pub storage_free_bytes: u64,
    pub agent_mode: String,
}

/// Agent 配置
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentConfig {
    pub agent_name: String,
    pub mode: String,
    pub llm_provider: String,
    pub llm_api_key: String,
    pub llm_base_url: Option<String>,
}

// ============================
// Core 初始化
// ============================

/// 初始化 My App Core
#[flutter_rust_bridge::frb(sync)]
pub fn init_my_app(log_level: String) -> String {
    std::env::set_var("RUST_LOG", &log_level);
    format!(
        "My App Core v{} initialized (log={})",
        env!("CARGO_PKG_VERSION"),
        log_level
    )
}

/// 获取 Core 版本号
#[flutter_rust_bridge::frb(sync)]
pub fn get_core_version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

// ============================
// LLM 接口
// ============================

/// 调用云端 LLM（非流式，Phase 1）
pub async fn llm_chat(request: LlmRequest) -> Result<LlmResponse, String> {
    Ok(LlmResponse {
        content: format!(
            "Echo: {}",
            request
                .messages
                .last()
                .map(|m| m.content.as_str())
                .unwrap_or("")
        ),
        tokens_used: 0,
    })
}

/// 获取可用模型列表
#[flutter_rust_bridge::frb(sync)]
pub fn llm_list_models(provider: String) -> Vec<String> {
    match provider.as_str() {
        "deepseek" => vec!["deepseek-chat".to_string(), "deepseek-reasoner".to_string()],
        "openai" => vec!["gpt-4o".to_string(), "gpt-4o-mini".to_string()],
        "local" => vec!["qwen3-4b".to_string(), "phi4-mini".to_string()],
        _ => vec![],
    }
}

// ============================
// 设备状态接口
// ============================

pub async fn get_device_status() -> Result<DeviceStatus, String> {
    Ok(DeviceStatus {
        online: true,
        battery_percent: 85,
        storage_free_bytes: 10_737_418_240,
        agent_mode: "alpha".to_string(),
    })
}

// ============================
// Agent 配置接口
// ============================

pub async fn save_agent_config(config: AgentConfig) -> Result<String, String> {
    Ok(format!("Config saved for agent: {}", config.agent_name))
}

pub async fn load_agent_config() -> Result<AgentConfig, String> {
    Ok(AgentConfig {
        agent_name: "Alpha".to_string(),
        mode: "alpha".to_string(),
        llm_provider: "deepseek".to_string(),
        llm_api_key: "".to_string(),
        llm_base_url: None,
    })
}

// ============================
// 测试接口
// ============================

/// 简单 ping
#[flutter_rust_bridge::frb(sync)]
pub fn ping() -> String {
    "pong".to_string()
}

/// 计算斐波那契（测试异步）
pub async fn fib(n: u32) -> u64 {
    match n {
        0 => 0,
        1 => 1,
        _ => {
            let mut a = 0u64;
            let mut b = 1u64;
            for _ in 2..=n {
                let c = a + b;
                a = b;
                b = c;
            }
            b
        }
    }
}
