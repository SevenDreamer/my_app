//! Embedding provider for semantic search

use async_trait::async_trait;
use anyhow::Result;
use reqwest::Client as HttpClient;
use serde::{Deserialize, Serialize};

/// Embedding provider trait
#[async_trait]
pub trait EmbeddingProvider: Send + Sync {
    /// Generate embeddings for text
    async fn embed(&self, text: &str) -> Result<Vec<f32>>;

    /// Get the embedding dimension
    fn dimension(&self) -> usize;
}

/// OpenAI embedding provider
pub struct OpenAIEmbedding {
    client: HttpClient,
    api_key: String,
    model: String,
}

impl OpenAIEmbedding {
    pub fn new(api_key: String) -> Self {
        Self {
            client: HttpClient::new(),
            api_key,
            model: "text-embedding-3-small".to_string(),
        }
    }

    pub fn with_model(api_key: String, model: String) -> Self {
        Self {
            client: HttpClient::new(),
            api_key,
            model,
        }
    }
}

#[derive(Debug, Serialize)]
struct EmbeddingRequest {
    model: String,
    input: String,
}

#[derive(Debug, Deserialize)]
struct EmbeddingResponse {
    data: Vec<EmbeddingData>,
}

#[derive(Debug, Deserialize)]
struct EmbeddingData {
    embedding: Vec<f32>,
}

#[async_trait]
impl EmbeddingProvider for OpenAIEmbedding {
    async fn embed(&self, text: &str) -> Result<Vec<f32>> {
        let request = EmbeddingRequest {
            model: self.model.clone(),
            input: text.to_string(),
        };

        let response = self
            .client
            .post("https://api.openai.com/v1/embeddings")
            .header("Authorization", format!("Bearer {}", self.api_key))
            .header("Content-Type", "application/json")
            .json(&request)
            .send()
            .await?;

        let status = response.status();
        if !status.is_success() {
            let error_text = response.text().await?;
            anyhow::bail!("OpenAI embedding error: {} - {}", status, error_text);
        }

        let api_response: EmbeddingResponse = response.json().await?;
        let embedding = api_response
            .data
            .first()
            .map(|d| d.embedding.clone())
            .ok_or_else(|| anyhow::anyhow!("No embedding in response"))?;

        Ok(embedding)
    }

    fn dimension(&self) -> usize {
        match self.model.as_str() {
            "text-embedding-3-small" => 1536,
            "text-embedding-3-large" => 3072,
            "text-embedding-ada-002" => 1536,
            _ => 1536,
        }
    }
}

/// Mock embedding provider for testing (uses simple hash-based embeddings)
pub struct MockEmbedding {
    dimension: usize,
}

impl MockEmbedding {
    pub fn new() -> Self {
        Self { dimension: 128 }
    }
}

impl Default for MockEmbedding {
    fn default() -> Self {
        Self::new()
    }
}

#[async_trait]
impl EmbeddingProvider for MockEmbedding {
    async fn embed(&self, text: &str) -> Result<Vec<f32>> {
        // Simple hash-based embedding for testing
        let bytes = text.as_bytes();
        let mut embedding = vec![0.0; self.dimension];

        for (i, byte) in bytes.iter().cycle().take(self.dimension * 10).enumerate() {
            embedding[i % self.dimension] += *byte as f32 / 255.0;
        }

        // Normalize
        let norm: f32 = embedding.iter().map(|x| x * x).sum::<f32>().sqrt();
        if norm > 0.0 {
            for x in &mut embedding {
                *x /= norm;
            }
        }

        Ok(embedding)
    }

    fn dimension(&self) -> usize {
        self.dimension
    }
}

/// Cosine similarity between two vectors
pub fn cosine_similarity(a: &[f32], b: &[f32]) -> f32 {
    if a.len() != b.len() {
        return 0.0;
    }

    let dot: f32 = a.iter().zip(b.iter()).map(|(x, y)| x * y).sum();
    let norm_a: f32 = a.iter().map(|x| x * x).sum::<f32>().sqrt();
    let norm_b: f32 = b.iter().map(|x| x * x).sum::<f32>().sqrt();

    if norm_a == 0.0 || norm_b == 0.0 {
        return 0.0;
    }

    dot / (norm_a * norm_b)
}