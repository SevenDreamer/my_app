//! Memory manager - stores and retrieves information across sessions

use async_trait::async_trait;
use anyhow::Result;
use std::sync::Arc;
use tokio::sync::RwLock;
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

use crate::types::{MemoryEntry, MemoryConfig};

/// Memory provider trait - abstract storage backend
#[async_trait]
pub trait MemoryProvider: Send + Sync {
    /// Store a memory entry
    async fn store(&self, key: &str, entry: &MemoryEntry) -> Result<()>;

    /// Recall memories by query
    async fn recall(&self, query: &str, limit: usize) -> Result<Vec<MemoryEntry>>;

    /// Search memories with semantic matching
    async fn search(&self, query: &str) -> Result<Vec<MemoryEntry>>;

    /// Clear all memories
    async fn clear(&self) -> Result<()>;
}

/// In-memory provider with simple keyword matching
pub struct InMemoryProvider {
    entries: Arc<RwLock<Vec<MemoryEntry>>>,
}

impl InMemoryProvider {
    pub fn new() -> Self {
        Self {
            entries: Arc::new(RwLock::new(Vec::new())),
        }
    }
}

impl Default for InMemoryProvider {
    fn default() -> Self {
        Self::new()
    }
}

#[async_trait]
impl MemoryProvider for InMemoryProvider {
    async fn store(&self, key: &str, entry: &MemoryEntry) -> Result<()> {
        let mut entries = self.entries.write().await;
        // Store with key as metadata
        let mut stored_entry = entry.clone();
        stored_entry.metadata.insert("key".to_string(), key.to_string());
        entries.push(stored_entry);
        Ok(())
    }

    async fn recall(&self, query: &str, limit: usize) -> Result<Vec<MemoryEntry>> {
        let entries = self.entries.read().await;

        // Simple keyword matching - find entries that contain query terms
        let query_terms: Vec<&str> = query.split_whitespace().collect();
        let mut matches: Vec<&MemoryEntry> = entries
            .iter()
            .filter(|entry| {
                query_terms.iter().any(|term| {
                    entry.content.contains(term) ||
                    entry.metadata.values().any(|v| v.contains(term))
                })
            })
            .collect();

        // Sort by relevance (simple: by creation time, most recent first)
        matches.sort_by(|a, b| b.created_at.cmp(&a.created_at));

        Ok(matches.iter().take(limit).cloned().cloned().collect())
    }

    async fn search(&self, query: &str) -> Result<Vec<MemoryEntry>> {
        // Same as recall for in-memory provider
        self.recall(query, 10).await
    }

    async fn clear(&self) -> Result<()> {
        let mut entries = self.entries.write().await;
        entries.clear();
        Ok(())
    }
}

/// Memory manager - high-level memory operations
pub struct MemoryManager {
    provider: Arc<dyn MemoryProvider>,
    config: MemoryConfig,
}

impl MemoryManager {
    pub fn new(provider: Arc<dyn MemoryProvider>) -> Self {
        Self {
            provider,
            config: MemoryConfig::default(),
        }
    }

    pub fn with_config(config: MemoryConfig) -> Self {
        Self {
            provider: Arc::new(InMemoryProvider::new()),
            config,
        }
    }

    /// Store a conversation memory
    pub async fn store_conversation(&self, user_message: &str, assistant_response: &str) -> Result<()> {
        let entry = MemoryEntry::new(format!(
            "User: {}\nAssistant: {}", user_message, assistant_response
        ));
        self.provider.store(&format!("conv_{}", entry.id), &entry).await
    }

    /// Store a fact or piece of information
    pub async fn store_fact(&self, content: &str, category: &str) -> Result<()> {
        let mut entry = MemoryEntry::new(content);
        entry.metadata.insert("category".to_string(), category.to_string());
        self.provider.store(&format!("fact_{}", entry.id), &entry).await
    }

    /// Recall relevant memories for a query
    pub async fn recall(&self, query: &str) -> Result<Vec<MemoryEntry>> {
        self.provider.recall(query, self.config.max_recall_results).await
    }

    /// Build context block for LLM prompt
    pub async fn build_context_block(&self, query: &str) -> String {
        match self.recall(query).await {
            Ok(memories) if !memories.is_empty() => {
                let blocks: Vec<String> = memories
                    .iter()
                    .map(|m| format!("- {} (stored: {})", m.content, m.created_at.format("%Y-%m-%d")))
                    .collect();
                format!("## Relevant Memories\n{}\n", blocks.join("\n"))
            }
            _ => String::new(),
        }
    }

    /// Clear all memories
    pub async fn clear(&self) -> Result<()> {
        self.provider.clear().await
    }
}

impl Default for MemoryManager {
    fn default() -> Self {
        Self::with_config(MemoryConfig::default())
    }
}