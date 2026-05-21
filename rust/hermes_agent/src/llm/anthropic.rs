//! Anthropic Claude client

use async_trait::async_trait;
use reqwest::Client as HttpClient;
use serde::{Deserialize, Serialize};
use anyhow::Result;

use super::{CompletionRequest, CompletionResponse, LlmClientBase};
use crate::types::{Message, MessageRole};

/// Anthropic API request
#[derive(Debug, Serialize)]
struct AnthropicRequest {
    model: String,
    messages: Vec<AnthropicMessage>,
    #[serde(skip_serializing_if = "Option::is_none")]
    max_tokens: Option<u32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    system: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    temperature: Option<f32>,
}

/// Anthropic message format
#[derive(Debug, Serialize)]
struct AnthropicMessage {
    role: String,
    content: String,
}

/// Anthropic API response
#[derive(Debug, Deserialize)]
struct AnthropicResponse {
    content: Vec<AnthropicContent>,
    stop_reason: Option<String>,
}

#[derive(Debug, Deserialize)]
struct AnthropicContent {
    text: String,
}

/// Anthropic Claude client
pub struct AnthropicClient {
    client: HttpClient,
    api_key: String,
    model: String,
}

impl AnthropicClient {
    pub fn new(api_key: String, model: String) -> Self {
        Self {
            client: HttpClient::new(),
            api_key,
            model,
        }
    }

    fn convert_messages(messages: &[Message]) -> (Vec<AnthropicMessage>, Option<String>) {
        let mut system_prompt = None;
        let mut anthropic_messages = Vec::new();

        for m in messages {
            match m.role {
                MessageRole::System => {
                    system_prompt = Some(m.content.clone());
                }
                _ => {
                    anthropic_messages.push(AnthropicMessage {
                        role: m.role.to_string(),
                        content: m.content.clone(),
                    });
                }
            }
        }

        (anthropic_messages, system_prompt)
    }
}

#[async_trait]
impl LlmClientBase for AnthropicClient {
    async fn complete(&self, request: CompletionRequest) -> Result<CompletionResponse> {
        let (messages, system) = Self::convert_messages(&request.messages);

        let req = AnthropicRequest {
            model: self.model.clone(),
            messages,
            max_tokens: request.max_tokens,
            system,
            temperature: request.temperature,
        };

        let response = self
            .client
            .post("https://api.anthropic.com/v1/messages")
            .header("x-api-key", &self.api_key)
            .header("anthropic-version", "2023-06-01")
            .header("content-type", "application/json")
            .json(&req)
            .send()
            .await?;

        let status = response.status();
        if !status.is_success() {
            let error_text = response.text().await?;
            anyhow::bail!("Anthropic API error: {} - {}", status, error_text);
        }

        let api_response: AnthropicResponse = response.json().await?;

        let content = api_response
            .content
            .first()
            .map(|c| c.text.clone())
            .unwrap_or_default();

        Ok(CompletionResponse {
            content,
            tool_calls: Vec::new(),
            finish_reason: api_response.stop_reason.unwrap_or_else(|| "stop".to_string()),
        })
    }

    fn model_name(&self) -> &str {
        &self.model
    }
}