//! File operation tools

use anyhow::Result;
use serde_json::Value;
use std::path::Path;

use super::executor::ToolHandler;
use crate::types::ToolDefinition;

/// File read tool
pub struct FileReadTool;

impl FileReadTool {
    pub fn new() -> Self {
        Self
    }
}

impl ToolHandler for FileReadTool {
    fn execute(&self, arguments: &Value) -> Result<String> {
        let path = arguments["path"]
            .as_str()
            .ok_or_else(|| anyhow::anyhow!("Missing 'path' argument"))?;

        let content = std::fs::read_to_string(Path::new(path))?;

        // Truncate large files
        if content.len() > 10000 {
            Ok(format!("{}... (truncated, {} bytes total)", &content[..10000], content.len()))
        } else {
            Ok(content)
        }
    }

    fn definition(&self) -> ToolDefinition {
        ToolDefinition::new(
            "file_read",
            "Read a file from the filesystem",
            serde_json::json!({
                "type": "object",
                "properties": {
                    "path": {
                        "type": "string",
                        "description": "The file path to read"
                    }
                },
                "required": ["path"]
            }),
        )
    }
}

impl Default for FileReadTool {
    fn default() -> Self {
        Self::new()
    }
}

/// File write tool
pub struct FileWriteTool;

impl FileWriteTool {
    pub fn new() -> Self {
        Self
    }
}

impl ToolHandler for FileWriteTool {
    fn execute(&self, arguments: &Value) -> Result<String> {
        let path = arguments["path"]
            .as_str()
            .ok_or_else(|| anyhow::anyhow!("Missing 'path' argument"))?;

        let content = arguments["content"]
            .as_str()
            .ok_or_else(|| anyhow::anyhow!("Missing 'content' argument"))?;

        // Ensure parent directory exists
        let parent = Path::new(path).parent();
        if let Some(parent) = parent {
            if !parent.exists() {
                std::fs::create_dir_all(parent)?;
            }
        }

        std::fs::write(Path::new(path), content)?;

        Ok(format!("Written {} bytes to {}", content.len(), path))
    }

    fn definition(&self) -> ToolDefinition {
        ToolDefinition::new(
            "file_write",
            "Write content to a file",
            serde_json::json!({
                "type": "object",
                "properties": {
                    "path": {
                        "type": "string",
                        "description": "The file path to write"
                    },
                    "content": {
                        "type": "string",
                        "description": "The content to write"
                    }
                },
                "required": ["path", "content"]
            }),
        )
    }
}

impl Default for FileWriteTool {
    fn default() -> Self {
        Self::new()
    }
}