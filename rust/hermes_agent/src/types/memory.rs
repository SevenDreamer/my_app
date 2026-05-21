//! Memory types

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use uuid::Uuid;

/// Memory entry
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MemoryEntry {
    pub id: String,
    pub content: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub embedding: Option<Vec<f32>>,
    pub metadata: HashMap<String, String>,
    pub created_at: DateTime<Utc>,
}

impl MemoryEntry {
    pub fn new(content: impl Into<String>) -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            content: content.into(),
            embedding: None,
            metadata: HashMap::new(),
            created_at: Utc::now(),
        }
    }
}

/// Memory query result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MemoryQueryResult {
    pub entries: Vec<MemoryEntry>,
    pub total: usize,
}

/// Memory provider configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MemoryConfig {
    pub provider_type: String,
    pub max_entries: usize,
    pub similarity_threshold: f32,
    pub max_recall_results: usize,
}

impl Default for MemoryConfig {
    fn default() -> Self {
        Self {
            provider_type: "sqlite".to_string(),
            max_entries: 1000,
            similarity_threshold: 0.7,
            max_recall_results: 10,
        }
    }
}