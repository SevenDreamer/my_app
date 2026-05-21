//! Conversation loop

use anyhow::Result;
use crate::types::{Message, Session, Skill, SkillTrigger};
use crate::llm::{create_client, CompletionRequest};

/// Conversation loop - core agent processing
pub struct ConversationLoop {
    session: Session,
}

impl ConversationLoop {
    pub fn new(session: Session) -> Self {
        Self { session }
    }

    /// Process a user message and return the assistant response
    pub async fn process_user_message(&mut self, message: &str) -> Result<String> {
        // 1. Add user message
        self.session.add_message(Message::user(message));

        // 2. Check skill triggers
        let triggered_skills = self.check_skills(message);

        // 3. Build context
        let context = self.build_context();

        // 4. Create LLM client and call API
        let response = match create_client(self.session.model.clone()) {
            Ok(client) => {
                let request = CompletionRequest {
                    messages: context,
                    model: self.session.model.clone(),
                    temperature: Some(0.7),
                    max_tokens: Some(4096),
                    tools: vec![],
                };

                match client.complete(request).await {
                    Ok(resp) => {
                        // Process tool calls if any
                        if !resp.tool_calls.is_empty() {
                            format!("[Tool calls: {}]", resp.tool_calls.len())
                        } else {
                            resp.content
                        }
                    }
                    Err(e) => format!("[LLM error: {}]", e),
                }
            }
            Err(e) => {
                // Fallback if client creation fails (e.g., missing API key)
                format!("[{}] {}", e, message)
            }
        };

        // 5. Add triggered skills info if any
        let final_response = if !triggered_skills.is_empty() {
            let skill_names: Vec<&str> = triggered_skills.iter().map(|s| s.name.as_str()).collect();
            format!("{}\n[Triggered skills: {}]", response, skill_names.join(", "))
        } else {
            response
        };

        // 6. Add assistant response
        self.session.add_message(Message::assistant(&final_response));

        Ok(final_response)
    }

    /// Check if any skills are triggered by the message
    fn check_skills(&self, message: &str) -> Vec<&Skill> {
        self.session.skills.iter().filter(|skill| {
            match &skill.trigger {
                SkillTrigger::Keyword(kw) => message.contains(kw.as_str()),
                SkillTrigger::Pattern(pattern) => {
                    regex::Regex::new(pattern)
                        .map(|re| re.is_match(message))
                        .unwrap_or(false)
                }
                SkillTrigger::Auto => true,
                SkillTrigger::Manual => false,
            }
        }).collect()
    }

    /// Build the full context for LLM completion
    fn build_context(&self) -> Vec<Message> {
        self.session.messages.clone()
    }

    /// Get the current session
    pub fn session(&self) -> &Session {
        &self.session
    }
}