//! OpenAI client

use async_trait::async_trait;
use futures::Stream;
use anyhow::Result;

use super::{CompletionRequest, CompletionResponse, StreamChunk, LlmClient};

/// OpenAI client implementation
pub struct OpenAIClient {
    api_key: String,
    model: String,
}

impl OpenAIClient {
    pub fn new(api_key: String, model: String) -> Self {
        Self { api_key, model }
    }
}

#[async_trait]
impl LlmClient for OpenAIClient {
    async fn complete(&self, request: CompletionRequest) -> Result<CompletionResponse> {
        // Placeholder implementation
        // Will be implemented with async-openai crate
        Ok(CompletionResponse {
            content: "[OpenAI response placeholder]".to_string(),
            tool_calls: Vec::new(),
            finish_reason: "stop".to_string(),
        })
    }

    async fn stream(
        &self,
        request: CompletionRequest,
    ) -> Result<impl Stream<Item = Result<StreamChunk>> + Send> {
        // Placeholder
        futures::stream::once(Ok(StreamChunk {
            content: "[Streaming placeholder]".to_string(),
            is_final: true,
        }))
    }

    fn model_name(&self) -> &str {
        &self.model
    }
}