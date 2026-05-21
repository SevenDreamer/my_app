//! LLM client factory

use std::env;
use anyhow::Result;

use super::{LlmClientBase, OpenAIClient, AnthropicClient, ModelInfo, CompletionRequest, CompletionResponse};

/// Supported LLM providers
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LlmProvider {
    OpenAI,
    Anthropic,
    Gemini,
    OpenRouter,
}

impl LlmProvider {
    pub fn from_model(model: &str) -> Self {
        let model_lower = model.to_lowercase();
        if model_lower.starts_with("gpt") || model_lower.starts_with("o1") || model_lower.starts_with("o3") || model_lower.starts_with("o4") {
            LlmProvider::OpenAI
        } else if model_lower.starts_with("claude") {
            LlmProvider::Anthropic
        } else if model_lower.starts_with("gemini") {
            LlmProvider::Gemini
        } else {
            LlmProvider::OpenRouter
        }
    }
}

/// Enum-based LLM client for dyn compatibility
pub enum LlmClientEnum {
    OpenAI(OpenAIClient),
    Anthropic(AnthropicClient),
}

impl LlmClientEnum {
    pub async fn complete(&self, request: CompletionRequest) -> Result<CompletionResponse> {
        match self {
            LlmClientEnum::OpenAI(client) => client.complete(request).await,
            LlmClientEnum::Anthropic(client) => client.complete(request).await,
        }
    }

    pub fn model_name(&self) -> &str {
        match self {
            LlmClientEnum::OpenAI(client) => client.model_name(),
            LlmClientEnum::Anthropic(client) => client.model_name(),
        }
    }
}

/// Create an LLM client based on model name
pub fn create_client(model: String) -> Result<LlmClientEnum> {
    let provider = LlmProvider::from_model(&model);

    match provider {
        LlmProvider::OpenAI => {
            let api_key = env::var("OPENAI_API_KEY")
                .map_err(|_| anyhow::anyhow!("OPENAI_API_KEY not set"))?;
            Ok(LlmClientEnum::OpenAI(OpenAIClient::new(api_key, model)))
        }
        LlmProvider::Anthropic => {
            let api_key = env::var("ANTHROPIC_API_KEY")
                .map_err(|_| anyhow::anyhow!("ANTHROPIC_API_KEY not set"))?;
            Ok(LlmClientEnum::Anthropic(AnthropicClient::new(api_key, model)))
        }
        LlmProvider::Gemini => {
            anyhow::bail!("Gemini provider not implemented yet")
        }
        LlmProvider::OpenRouter => {
            let api_key = env::var("OPENROUTER_API_KEY")
                .map_err(|_| anyhow::anyhow!("OPENROUTER_API_KEY not set"))?;
            Ok(LlmClientEnum::OpenAI(OpenAIClient::with_base_url(
                api_key,
                "https://openrouter.ai/api/v1".to_string(),
                model,
            )))
        }
    }
}

/// List available models
pub fn list_models() -> Vec<ModelInfo> {
    vec![
        // OpenAI
        ModelInfo {
            id: "gpt-4o".to_string(),
            name: "GPT-4o".to_string(),
            provider: "openai".to_string(),
            context_length: 128000,
        },
        ModelInfo {
            id: "gpt-4-turbo".to_string(),
            name: "GPT-4 Turbo".to_string(),
            provider: "openai".to_string(),
            context_length: 128000,
        },
        ModelInfo {
            id: "gpt-3.5-turbo".to_string(),
            name: "GPT-3.5 Turbo".to_string(),
            provider: "openai".to_string(),
            context_length: 16385,
        },
        // Anthropic
        ModelInfo {
            id: "claude-sonnet-4-20250514".to_string(),
            name: "Claude Sonnet 4".to_string(),
            provider: "anthropic".to_string(),
            context_length: 200000,
        },
        ModelInfo {
            id: "claude-3-5-sonnet-20241022".to_string(),
            name: "Claude 3.5 Sonnet".to_string(),
            provider: "anthropic".to_string(),
            context_length: 200000,
        },
        ModelInfo {
            id: "claude-3-opus-20240229".to_string(),
            name: "Claude 3 Opus".to_string(),
            provider: "anthropic".to_string(),
            context_length: 200000,
        },
        // OpenRouter
        ModelInfo {
            id: "google/gemini-pro".to_string(),
            name: "Gemini Pro (OpenRouter)".to_string(),
            provider: "openrouter".to_string(),
            context_length: 32000,
        },
        ModelInfo {
            id: "meta-llama/llama-3-70b-instruct".to_string(),
            name: "Llama 3 70B (OpenRouter)".to_string(),
            provider: "openrouter".to_string(),
            context_length: 8192,
        },
    ]
}