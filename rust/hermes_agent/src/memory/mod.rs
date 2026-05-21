//! Memory management

mod manager;

pub use manager::*;

// Re-export memory types
pub use crate::types::{MemoryEntry, MemoryConfig, MemoryQueryResult};