//! Vector store memory provider - semantic search using embeddings

use async_trait::async_trait;
use anyhow::Result;
use std::sync::Arc;
use tokio::sync::RwLock;

use super::embedding::{EmbeddingProvider, MockEmbedding, cosine_similarity};
use super::manager::MemoryProvider;
use crate::types::MemoryEntry;

/// Vector store entry with pre-computed embedding
struct VectorEntry {
    entry: MemoryEntry,
    embedding: Vec<f32>,
}

/// Vector store memory provider with semantic search
pub struct VectorStoreProvider {
    entries: Arc<RwLock<Vec<VectorEntry>>>,
    embedding_provider: Arc<dyn EmbeddingProvider>,
}

impl VectorStoreProvider {
    pub fn new(provider: Arc<dyn EmbeddingProvider>) -> Self {
        Self {
            entries: Arc::new(RwLock::new(Vec::new())),
            embedding_provider: provider,
        }
    }

    /// Create with mock embedding provider (for testing)
    pub fn mock() -> Self {
        Self::new(Arc::new(MockEmbedding::new()))
    }
}

impl Default for VectorStoreProvider {
    fn default() -> Self {
        Self::mock()
    }
}

#[async_trait]
impl MemoryProvider for VectorStoreProvider {
    async fn store(&self, key: &str, entry: &MemoryEntry) -> Result<()> {
        // Generate embedding for the content
        let embedding = self.embedding_provider.embed(&entry.content).await.unwrap_or_default();

        let mut stored_entry = entry.clone();
        stored_entry.metadata.insert("key".to_string(), key.to_string());
        stored_entry.embedding = Some(embedding.clone());

        let mut entries = self.entries.write().await;
        entries.push(VectorEntry {
            entry: stored_entry,
            embedding,
        });

        Ok(())
    }

    async fn recall(&self, query: &str, limit: usize) -> Result<Vec<MemoryEntry>> {
        let query_embedding = self.embedding_provider.embed(query).await.unwrap_or_default();

        let entries = self.entries.read().await;

        // Calculate similarity scores
        let mut scored: Vec<(f32, &VectorEntry)> = entries
            .iter()
            .map(|e| {
                let sim = if e.embedding.is_empty() || query_embedding.is_empty() {
                    // Fallback to keyword matching
                    if e.entry.content.contains(query) { 0.5 } else { 0.0 }
                } else {
                    cosine_similarity(&query_embedding, &e.embedding)
                };
                (sim, e)
            })
            .collect();

        // Sort by similarity (descending)
        scored.sort_by(|a, b| b.0.partial_cmp(&a.0).unwrap_or(std::cmp::Ordering::Equal));

        Ok(scored
            .iter()
            .take(limit)
            .map(|(_, e)| {
                let mut entry = e.entry.clone();
                entry.embedding = None; // Don't send embeddings to clients
                entry
            })
            .collect())
    }

    async fn search(&self, query: &str) -> Result<Vec<MemoryEntry>> {
        self.recall(query, 10).await
    }

    async fn clear(&self) -> Result<()> {
        let mut entries = self.entries.write().await;
        entries.clear();
        Ok(())
    }
}