//! Session persistence using SQLite

use anyhow::Result;
use sqlx::{SqlitePool, sqlite::SqlitePoolOptions};
use std::path::Path;
use std::sync::Arc;
use tokio::sync::RwLock;

use crate::types::{Session, SessionInfo, Message, MessageRole};

/// Session database store
pub struct SessionStore {
    pool: SqlitePool,
}

impl SessionStore {
    /// Create a new session store with SQLite backend
    pub async fn new(db_path: &str) -> Result<Self> {
        // Ensure parent directory exists
        let path = Path::new(db_path);
        if let Some(parent) = path.parent() {
            if !parent.exists() {
                std::fs::create_dir_all(parent)?;
            }
        }

        let pool = SqlitePoolOptions::new()
            .max_connections(5)
            .connect(&format!("sqlite:{}?mode=rwc", db_path))
            .await?;

        // Run migrations
        Self::run_migrations(&pool).await?;

        Ok(Self { pool })
    }

    /// Create an in-memory session store
    pub async fn in_memory() -> Result<Self> {
        let pool = SqlitePoolOptions::new()
            .max_connections(1)
            .connect("sqlite::memory:")
            .await?;

        Self::run_migrations(&pool).await?;

        Ok(Self { pool })
    }

    async fn run_migrations(pool: &SqlitePool) -> Result<()> {
        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS sessions (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                model TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS messages (
                id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL,
                role TEXT NOT NULL,
                content TEXT NOT NULL,
                timestamp TEXT NOT NULL,
                FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
            );

            CREATE INDEX IF NOT EXISTS idx_messages_session ON messages(session_id);
            "#,
        )
        .execute(pool)
        .await?;

        Ok(())
    }

    /// Save a session
    pub async fn save_session(&self, session: &Session) -> Result<()> {
        sqlx::query(
            r#"
            INSERT OR REPLACE INTO sessions (id, title, model, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?)
            "#,
        )
        .bind(&session.id)
        .bind(&session.title)
        .bind(&session.model)
        .bind(session.created_at.to_rfc3339())
        .bind(session.updated_at.to_rfc3339())
        .execute(&self.pool)
        .await?;

        // Save messages
        for msg in &session.messages {
            self.save_message(&session.id, msg).await?;
        }

        Ok(())
    }

    /// Save a message
    pub async fn save_message(&self, session_id: &str, message: &Message) -> Result<()> {
        let role = match message.role {
            MessageRole::System => "system",
            MessageRole::User => "user",
            MessageRole::Assistant => "assistant",
            MessageRole::Tool => "tool",
        };

        sqlx::query(
            r#"
            INSERT OR REPLACE INTO messages (id, session_id, role, content, timestamp)
            VALUES (?, ?, ?, ?, ?)
            "#,
        )
        .bind(&message.id)
        .bind(session_id)
        .bind(role)
        .bind(&message.content)
        .bind(message.timestamp.to_rfc3339())
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    /// Load a session by ID
    pub async fn load_session(&self, id: &str) -> Result<Option<Session>> {
        let session_row = sqlx::query_as::<_, (String, String, String, String, String)>(
            "SELECT id, title, model, created_at, updated_at FROM sessions WHERE id = ?",
        )
        .bind(id)
        .fetch_optional(&self.pool)
        .await?;

        if let Some((id, title, model, created_at, updated_at)) = session_row {
            let messages = self.load_messages(&id).await?;

            let session = Session {
                id,
                title,
                messages,
                model,
                skills: vec![], // Skills are managed separately
                created_at: chrono::DateTime::parse_from_rfc3339(&created_at)?.with_timezone(&chrono::Utc),
                updated_at: chrono::DateTime::parse_from_rfc3339(&updated_at)?.with_timezone(&chrono::Utc),
            };

            Ok(Some(session))
        } else {
            Ok(None)
        }
    }

    /// Load messages for a session
    pub async fn load_messages(&self, session_id: &str) -> Result<Vec<Message>> {
        let rows = sqlx::query_as::<_, (String, String, String, String)>(
            "SELECT id, role, content, timestamp FROM messages WHERE session_id = ? ORDER BY timestamp ASC",
        )
        .bind(session_id)
        .fetch_all(&self.pool)
        .await?;

        let messages = rows
            .into_iter()
            .map(|(id, role, content, timestamp)| {
                let role = match role.as_str() {
                    "system" => MessageRole::System,
                    "user" => MessageRole::User,
                    "assistant" => MessageRole::Assistant,
                    "tool" => MessageRole::Tool,
                    _ => MessageRole::User,
                };

                Message {
                    id,
                    role,
                    content,
                    timestamp: chrono::DateTime::parse_from_rfc3339(&timestamp)
                        .unwrap_or_else(|_| chrono::Utc::now().into())
                        .with_timezone(&chrono::Utc),
                    tool_calls: vec![],
                    tool_call_id: None,
                }
            })
            .collect();

        Ok(messages)
    }

    /// List all sessions
    pub async fn list_sessions(&self) -> Result<Vec<SessionInfo>> {
        let rows = sqlx::query_as::<_, (String, String, String, String, String)>(
            "SELECT id, title, model, created_at, updated_at FROM sessions ORDER BY updated_at DESC",
        )
        .fetch_all(&self.pool)
        .await?;

        let sessions = rows
            .into_iter()
            .map(|(id, title, model, created_at, updated_at)| {
                // Count messages for this session
                SessionInfo {
                    id,
                    title,
                    model,
                    message_count: 0, // Will be filled separately
                    created_at,
                    updated_at,
                }
            })
            .collect();

        Ok(sessions)
    }

    /// Delete a session
    pub async fn delete_session(&self, id: &str) -> Result<()> {
        sqlx::query("DELETE FROM sessions WHERE id = ?")
            .bind(id)
            .execute(&self.pool)
            .await?;

        Ok(())
    }

    /// Update session model
    pub async fn update_model(&self, id: &str, model: &str) -> Result<()> {
        sqlx::query("UPDATE sessions SET model = ?, updated_at = ? WHERE id = ?")
            .bind(model)
            .bind(chrono::Utc::now().to_rfc3339())
            .bind(id)
            .execute(&self.pool)
            .await?;

        Ok(())
    }

    /// Get message count for a session
    pub async fn message_count(&self, session_id: &str) -> Result<usize> {
        let count: (i64,) = sqlx::query_as(
            "SELECT COUNT(*) FROM messages WHERE session_id = ?",
        )
        .bind(session_id)
        .fetch_one(&self.pool)
        .await?;

        Ok(count.0 as usize)
    }
}