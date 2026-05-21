//! Conversation loop - core agent processing

use anyhow::Result;
use crate::types::{Message, Session, Skill, SkillTrigger, ToolCall};
use crate::llm::{create_client, CompletionRequest};
use crate::tools::ToolExecutor;
use crate::memory::MemoryManager;
use crate::context::ContextCompressor;

/// Conversation loop - drives the agent through LLM calls and tool execution
pub struct ConversationLoop {
    session: Session,
    tool_executor: ToolExecutor,
    memory_manager: MemoryManager,
    compressor: ContextCompressor,
    max_iterations: usize,
}

impl ConversationLoop {
    pub fn new(session: Session) -> Self {
        Self {
            session,
            tool_executor: ToolExecutor::new(),
            memory_manager: MemoryManager::default(),
            compressor: ContextCompressor::new(),
            max_iterations: 10,
        }
    }

    /// Process a user message and return the assistant response
    pub async fn process_user_message(&mut self, message: &str) -> Result<String> {
        // 1. Add user message
        self.session.add_message(Message::user(message));

        // 2. Build memory context
        let memory_context = self.memory_manager.build_context_block(message).await;

        // 3. Run conversation loop
        let mut iterations = 0;
        let mut response = String::new();

        loop {
            iterations += 1;
            if iterations > self.max_iterations {
                response = "Maximum iterations reached".to_string();
                break;
            }

            // Build context with memory
            let context = self.build_context(&memory_context);

            // Compress if needed
            let context = if self.compressor.needs_compression(&context) {
                self.compressor.compress(&context).await
            } else {
                context
            };

            // Create LLM client and call
            let llm_response = match create_client(self.session.model.clone()) {
                Ok(client) => {
                    let request = CompletionRequest {
                        messages: context,
                        model: self.session.model.clone(),
                        temperature: Some(0.7),
                        max_tokens: Some(4096),
                        tools: self.tool_executor.tool_definitions(),
                    };

                    client.complete(request).await
                }
                Err(e) => Err(e),
            };

            match llm_response {
                Ok(resp) => {
                    // Process tool calls if any
                    if !resp.tool_calls.is_empty() {
                        let tool_calls = resp.tool_calls.clone();
                        let tool_results = self.execute_tools(&tool_calls).await;

                        // Add assistant message with tool calls
                        let mut assistant_msg = Message::assistant(&resp.content);
                        assistant_msg.tool_calls = tool_calls;
                        self.session.add_message(assistant_msg);

                        // Add tool results
                        for result in tool_results {
                            let mut tool_msg = Message::user(&result.output);
                            tool_msg.tool_call_id = Some(result.tool_call_id);
                            self.session.add_message(tool_msg);
                        }

                        // Continue loop to process tool results
                        continue;
                    }

                    response = resp.content;
                    break;
                }
                Err(e) => {
                    response = format!("[LLM error: {}]", e);
                    break;
                }
            }
        }

        // 4. Store in memory
        self.memory_manager.store_conversation(message, &response).await?;

        // 5. Add assistant response
        self.session.add_message(Message::assistant(&response));

        Ok(response)
    }

    /// Execute tool calls
    async fn execute_tools(&self, calls: &[ToolCall]) -> Vec<crate::types::ToolResult> {
        self.tool_executor.execute_all(calls).await
    }

    /// Build the full context for LLM completion
    fn build_context(&self, memory_context: &str) -> Vec<Message> {
        let mut context = Vec::new();

        // Add system message with memory
        let system_content = if memory_context.is_empty() {
            "You are Hermes, a helpful AI assistant.".to_string()
        } else {
            format!("{}\n\n{}", memory_context, "You are Hermes, a helpful AI assistant.")
        };
        context.push(Message::system(&system_content));

        // Add conversation history
        context.extend(self.session.messages.clone());

        context
    }

    /// Get the current session
    pub fn session(&self) -> &Session {
        &self.session
    }
}