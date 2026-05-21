//! Memory manager

use async_trait::async_trait;
use anyhow::Result;
use std::sync::Arc;
use tokio::sync::RwLock;

use crate::types::{MemoryEntry, MemoryConfig, MemoryQueryResult};

/// Memory provider trait
#[async_trait]
pub trait MemoryProvider: Send + Sync {
    /// Store a memory entry
    async fn store(&self, key: &str, entry: &MemoryEntry) -> Result<()>;

    /// Recall memories by query
    async fn recall(&self, query: &str, limit: usize) -> Result<Vec<MemoryEntry>>;

    /// Search memories
    async fn search(&self, query: &str) -> Result<Vec<MemoryEntry>>;
}

/// In-memory provider (placeholder)
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
    async fn store(&self, _key: &str, entry: &MemoryEntry) -> Result<()> {
        let mut entries = self.entries.write().await;
        entries.push(entry.clone());
        Ok(())
    }

    async fn recall(&self, _query: &str, limit: usize) -> Result<Vec<MemoryEntry>> {
        let entries = self.entries.read().await;
        Ok(entries.iter().take(limit).cloned().collect())
    }

    async fn search(&self, _query: &str) -> Result<Vec<MemoryEntry>> {
        // Placeholder - simple return all
        let entries = self.entries.read().await;
        Ok(entries.clone())
    }
}

/// Memory manager
pub struct MemoryManager {
    provider: Box<dyn MemoryProvider>,
}

impl MemoryManager {
    pub fn new(provider: Box<dyn MemoryProvider>) -> Self {
        Self { provider }
    }

    pub fn with_config(_config: MemoryConfig) -> Self {
        Self::new(Box::new(InMemoryProvider::new()))
    }

    pub async fn store(&self, key: &str, content: &str) -> Result<()> {
        let entry = MemoryEntry::new(content);
        self.provider.store(key, &entry).await
    }

    pub async fn recall(&self, query: &str, limit: usize) -> Result<Vec<MemoryEntry>> {
        self.provider.recall(query, limit).await
    }
}