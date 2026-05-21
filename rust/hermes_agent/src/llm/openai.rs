//! OpenAI client

use async_openai::{
    config::OpenAIConfig,
    types::{
        ChatCompletionRequestMessage, ChatCompletionRequestUserMessage,
        ChatCompletionRequestUserMessageContent, ChatCompletionRequestSystemMessage,
        ChatCompletionRequestSystemMessageContent, ChatCompletionRequestAssistantMessage,
        ChatCompletionRequestAssistantMessageContent, ChatCompletionRequestToolMessage,
        ChatCompletionRequestToolMessageContent, CreateChatCompletionRequest,
    },
    Client as OpenAIClientSdk,
};
use async_trait::async_trait;
use anyhow::Result;

use super::{CompletionRequest, CompletionResponse, LlmClientBase};
use crate::types::{Message, MessageRole, ToolCall};

/// OpenAI client implementation
pub struct OpenAIClient {
    client: OpenAIClientSdk<OpenAIConfig>,
    model: String,
}

impl OpenAIClient {
    pub fn new(api_key: String, model: String) -> Self {
        let config = OpenAIConfig::new().with_api_key(api_key);
        Self {
            client: OpenAIClientSdk::with_config(config),
            model,
        }
    }

    pub fn with_base_url(api_key: String, base_url: String, model: String) -> Self {
        let config = OpenAIConfig::new()
            .with_api_key(api_key)
            .with_api_base(base_url);
        Self {
            client: OpenAIClientSdk::with_config(config),
            model,
        }
    }

    fn convert_messages(messages: &[Message]) -> Vec<ChatCompletionRequestMessage> {
        messages
            .iter()
            .map(|m| match m.role {
                MessageRole::System => {
                    ChatCompletionRequestMessage::System(ChatCompletionRequestSystemMessage {
                        content: ChatCompletionRequestSystemMessageContent::Text(m.content.clone()),
                        name: None,
                    })
                }
                MessageRole::User => {
                    ChatCompletionRequestMessage::User(ChatCompletionRequestUserMessage {
                        content: ChatCompletionRequestUserMessageContent::Text(m.content.clone()),
                        name: None,
                    })
                }
                MessageRole::Assistant => {
                    ChatCompletionRequestMessage::Assistant(ChatCompletionRequestAssistantMessage {
                        content: Some(ChatCompletionRequestAssistantMessageContent::Text(
                            m.content.clone(),
                        )),
                        name: None,
                        tool_calls: None,
                        refusal: None,
                        audio: None,
                        #[allow(deprecated)]
                        function_call: None,
                    })
                }
                MessageRole::Tool => {
                    ChatCompletionRequestMessage::Tool(ChatCompletionRequestToolMessage {
                        content: ChatCompletionRequestToolMessageContent::Text(m.content.clone()),
                        tool_call_id: m.tool_call_id.clone().unwrap_or_default(),
                    })
                }
            })
            .collect()
    }
}

#[async_trait]
impl LlmClientBase for OpenAIClient {
    async fn complete(&self, request: CompletionRequest) -> Result<CompletionResponse> {
        let messages = Self::convert_messages(&request.messages);

        let req = CreateChatCompletionRequest {
            model: self.model.clone(),
            messages,
            temperature: request.temperature,
            max_completion_tokens: request.max_tokens,
            stream: Some(false),
            ..Default::default()
        };

        let response = self.client.chat().create(req).await?;

        let choice = response.choices.first().ok_or_else(|| {
            anyhow::anyhow!("No choices in response")
        })?;

        let content = choice.message.content.clone().unwrap_or_default();

        let tool_calls = choice
            .message
            .tool_calls
            .clone()
            .map(|calls| {
                calls
                    .into_iter()
                    .map(|tc| {
                        let args: serde_json::Value =
                            serde_json::from_str(&tc.function.arguments).unwrap_or_default();
                        ToolCall::new(tc.function.name, args)
                    })
                    .collect()
            })
            .unwrap_or_default();

        let finish_reason = choice
            .finish_reason
            .clone()
            .map(|r| format!("{:?}", r))
            .unwrap_or_else(|| "stop".to_string());

        Ok(CompletionResponse {
            content,
            tool_calls,
            finish_reason,
        })
    }

    fn model_name(&self) -> &str {
        &self.model
    }
}