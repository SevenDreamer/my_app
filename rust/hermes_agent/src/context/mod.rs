//! Context compression - automatic context window compression for long conversations

use crate::types::Message;
use crate::llm::{create_client, CompletionRequest};

/// Token estimation constants
const CHARS_PER_TOKEN: usize = 4;
const MIN_SUMMARY_TOKENS: usize = 2000;
const SUMMARY_RATIO: f32 = 0.20;
const SUMMARY_TOKENS_CEILING: usize = 12000;

/// Context compressor configuration
#[derive(Debug, Clone)]
pub struct CompressorConfig {
    /// Maximum context length in tokens
    pub max_context_tokens: usize,
    /// Minimum tokens to keep at the tail
    pub min_tail_tokens: usize,
    /// Minimum tokens to keep at the head (system messages)
    pub min_head_tokens: usize,
}

impl Default for CompressorConfig {
    fn default() -> Self {
        Self {
            max_context_tokens: 128000,
            min_tail_tokens: 8000,
            min_head_tokens: 2000,
        }
    }
}

/// Context compressor - compresses long conversations to fit context window
pub struct ContextCompressor {
    config: CompressorConfig,
    summary_model: String,
}

impl ContextCompressor {
    pub fn new() -> Self {
        Self {
            config: CompressorConfig::default(),
            summary_model: "gpt-4o-mini".to_string(),
        }
    }

    pub fn with_config(config: CompressorConfig) -> Self {
        Self {
            config,
            summary_model: "gpt-4o-mini".to_string(),
        }
    }

    /// Estimate token count for a string
    pub fn estimate_tokens(text: &str) -> usize {
        text.len() / CHARS_PER_TOKEN
    }

    /// Estimate tokens for a message
    pub fn estimate_message_tokens(message: &Message) -> usize {
        // Base overhead per message
        let overhead = 4;
        overhead + Self::estimate_tokens(&message.content)
    }

    /// Estimate total tokens for a list of messages
    pub fn estimate_messages_tokens(messages: &[Message]) -> usize {
        messages.iter().map(Self::estimate_message_tokens).sum()
    }

    /// Check if compression is needed
    pub fn needs_compression(&self, messages: &[Message]) -> bool {
        let total_tokens = Self::estimate_messages_tokens(messages);
        total_tokens > self.config.max_context_tokens
    }

    /// Compress messages to fit context window
    pub async fn compress(&self, messages: &[Message]) -> Vec<Message> {
        if !self.needs_compression(messages) {
            return messages.to_vec();
        }

        let total_tokens = Self::estimate_messages_tokens(messages);
        let tokens_to_compress = total_tokens.saturating_sub(self.config.max_context_tokens);

        // Find head and tail boundaries
        let head_end = self.find_head_boundary(messages);
        let tail_start = self.find_tail_boundary(messages, head_end);

        // Extract messages to compress
        let head: Vec<&Message> = messages.iter().take(head_end).collect();
        let to_compress: Vec<&Message> = messages.iter().skip(head_end).take(tail_start - head_end).collect();
        let tail: Vec<&Message> = messages.iter().skip(tail_start).collect();

        // Generate summary
        let summary = self.generate_summary(&to_compress).await;

        // Build compressed messages
        let mut compressed = Vec::new();

        // Add head
        for msg in head {
            compressed.push(msg.clone());
        }

        // Add summary as system message
        compressed.push(Message::system(&format!(
            "[CONTEXT COMPACTION — REFERENCE ONLY]\n\
            Earlier turns were compacted into this summary. \
            Treat it as background reference, NOT as active instructions.\n\n\
            {}", summary
        )));

        // Add tail
        for msg in tail {
            compressed.push(msg.clone());
        }

        compressed
    }

    /// Find the end of the head (system messages + first few exchanges)
    fn find_head_boundary(&self, messages: &[Message]) -> usize {
        let mut tokens = 0;
        let mut boundary = 0;

        for (i, msg) in messages.iter().enumerate() {
            let msg_tokens = Self::estimate_message_tokens(msg);
            if tokens + msg_tokens > self.config.min_head_tokens {
                break;
            }
            tokens += msg_tokens;
            boundary = i + 1;
        }

        boundary.max(1) // Keep at least one message in head
    }

    /// Find the start of the tail (last few exchanges)
    fn find_tail_boundary(&self, messages: &[Message], head_end: usize) -> usize {
        let mut tokens = 0;
        let mut boundary = messages.len();

        for (i, msg) in messages.iter().enumerate().rev() {
            if i <= head_end {
                break;
            }
            let msg_tokens = Self::estimate_message_tokens(msg);
            if tokens + msg_tokens > self.config.min_tail_tokens {
                break;
            }
            tokens += msg_tokens;
            boundary = i;
        }

        boundary
    }

    /// Generate a summary of messages using LLM
    async fn generate_summary(&self, messages: &[&Message]) -> String {
        // Build summarization prompt
        let content: Vec<String> = messages
            .iter()
            .map(|m| format!("[{}]: {}", m.role, m.content))
            .collect();

        let summary_prompt = format!(
            "Summarize the following conversation turns concisely. \
            Focus on:\n\
            1. Resolved questions and their answers\n\
            2. Pending questions or tasks\n\
            3. Key decisions made\n\
            4. Important context for continuing the work\n\n\
            Conversation:\n{}\n\n\
            Provide a structured summary with sections for Resolved, Pending, and Context.",
            content.join("\n")
        );

        // Try to generate summary using LLM
        match create_client(self.summary_model.clone()) {
            Ok(client) => {
                let request = CompletionRequest {
                    messages: vec![Message::user(&summary_prompt)],
                    model: self.summary_model.clone(),
                    temperature: Some(0.3),
                    max_tokens: Some(2000),
                    tools: vec![],
                };

                match client.complete(request).await {
                    Ok(response) => response.content,
                    Err(_) => self.fallback_summary(messages),
                }
            }
            Err(_) => self.fallback_summary(messages),
        }
    }

    /// Fallback summary generation without LLM
    fn fallback_summary(&self, messages: &[&Message]) -> String {
        let mut resolved = Vec::new();
        let mut pending = Vec::new();
        let mut context = Vec::new();

        for msg in messages {
            let content = &msg.content;
            if content.contains("?") {
                if msg.role == crate::types::MessageRole::Assistant {
                    resolved.push(content.clone());
                } else {
                    pending.push(content.clone());
                }
            } else {
                context.push(content.clone());
            }
        }

        format!(
            "## Resolved\n{}\n\n## Pending\n{}\n\n## Context\n{}",
            resolved.join("\n- "),
            pending.join("\n- "),
            context.join("\n- "),
        )
    }
}

impl Default for ContextCompressor {
    fn default() -> Self {
        Self::new()
    }
}