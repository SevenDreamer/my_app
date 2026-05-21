//! Hermes Agent - Self-improving AI Agent
//!
//! Rust port of hermes-agent (https://github.com/NousResearch/hermes-agent)
//!
//! Core features:
//! - Multi-model LLM support (OpenAI, Anthropic, Gemini, etc.)
//! - Memory management and context compression
//! - Skill system with auto-improvement
//! - Tool execution
//! - Cron scheduler

pub mod types;
pub mod agent;
pub mod llm;
pub mod memory;
pub mod tools;
pub mod context;
pub mod cron;

// Re-exports
pub use types::*;
pub use agent::*;
