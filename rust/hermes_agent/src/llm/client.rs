//! LLM client trait

use async_trait::async_trait;
use futures::Stream;
use anyhow::Result;

use crate::types::{Message, ToolDefinition};

/// Completion request
#[derive(Debug, Clone)]
pub struct CompletionRequest {
    pub messages: Vec<Message>,
    pub model: String,
    pub temperature: Option<f32>,
    pub max_tokens: Option<u32>,
    pub tools: Vec<ToolDefinition>,
}

impl Default for CompletionRequest {
    fn default() -> Self {
        Self {
            messages: Vec::new(),
            model: "gpt-4".to_string(),
            temperature: Some(0.7),
            max_tokens: Some(2048),
            tools: Vec::new(),
        }
    }
}

/// Completion response
#[derive(Debug, Clone)]
pub struct CompletionResponse {
    pub content: String,
    pub tool_calls: Vec<crate::types::ToolCall>,
    pub finish_reason: String,
}

/// Stream chunk
#[derive(Debug, Clone)]
pub struct StreamChunk {
    pub content: String,
    pub is_final: bool,
}

/// LLM client trait - base interface
#[async_trait]
pub trait LlmClientBase: Send + Sync {
    /// Complete a request and return the response
    async fn complete(&self, request: CompletionRequest) -> Result<CompletionResponse>;

    /// Get the model name
    fn model_name(&self) -> &str;
}

/// Model info
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct ModelInfo {
    pub id: String,
    pub name: String,
    pub provider: String,
    pub context_length: u32,
}