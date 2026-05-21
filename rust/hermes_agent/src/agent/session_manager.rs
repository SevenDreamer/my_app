//! Session manager

use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use anyhow::Result;

use crate::types::{Session, SessionInfo, Message, MessageInfo};

/// Session manager (in-memory for now)
pub struct SessionManager {
    sessions: Arc<RwLock<HashMap<String, Session>>>,
}

impl SessionManager {
    pub fn new() -> Self {
        Self {
            sessions: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    /// Create a new session
    pub async fn create(&self, title: String, model: String) -> Result<String> {
        let session = Session::new(title, model);
        let id = session.id.clone();

        let mut sessions = self.sessions.write().await;
        sessions.insert(id.clone(), session);

        Ok(id)
    }

    /// Get all sessions
    pub async fn list(&self) -> Result<Vec<SessionInfo>> {
        let sessions = self.sessions.read().await;
        Ok(sessions.values().map(SessionInfo::from).collect())
    }

    /// Get a session by ID
    pub async fn get(&self, id: &str) -> Result<Option<Session>> {
        let sessions = self.sessions.read().await;
        Ok(sessions.get(id).cloned())
    }

    /// Delete a session
    pub async fn delete(&self, id: &str) -> Result<()> {
        let mut sessions = self.sessions.write().await;
        sessions.remove(id);
        Ok(())
    }

    /// Get messages for a session
    pub async fn get_messages(&self, id: &str) -> Result<Vec<MessageInfo>> {
        let sessions = self.sessions.read().await;
        let session = sessions.get(id);

        Ok(session
            .map(|s| s.messages.iter().map(|m| MessageInfo {
                id: m.id.clone(),
                role: match m.role {
                    crate::types::MessageRole::System => "system",
                    crate::types::MessageRole::User => "user",
                    crate::types::MessageRole::Assistant => "assistant",
                    crate::types::MessageRole::Tool => "tool",
                },
                content: m.content.clone(),
                timestamp: m.timestamp.to_rfc3339(),
            }).collect())
            .unwrap_or_default())
    }

    /// Add a message to a session
    pub async fn add_message(&self, id: &str, message: Message) -> Result<()> {
        let mut sessions = self.sessions.write().await;
        let session = sessions.get_mut(id);

        if let Some(session) = session {
            session.add_message(message);
        }

        Ok(())
    }

    /// Set model for a session
    pub async fn set_model(&self, id: &str, model: &str) -> Result<()> {
        let mut sessions = self.sessions.write().await;
        let session = sessions.get_mut(id);

        if let Some(session) = session {
            session.model = model.to_string();
            session.updated_at = chrono::Utc::now();
        }

        Ok(())
    }
}

impl Default for SessionManager {
    fn default() -> Self {
        Self::new()
    }
}