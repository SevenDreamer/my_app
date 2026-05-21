//! Conversation loop

use anyhow::Result;
use crate::types::{Message, Session, Skill, SkillTrigger};

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
        let _triggered = self.check_skills(message);

        // 3. Build context with memory
        let _context = self.build_context();

        // 4. Call LLM (placeholder - will be implemented with LLM adapter)
        let response = format!("[Hermes] 收到消息: {}", message);

        // 5. Add assistant response
        self.session.add_message(Message::assistant(&response));

        Ok(response)
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
