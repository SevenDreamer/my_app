//! Tool executor - dispatches tool calls to appropriate handlers

use anyhow::Result;
use std::collections::HashMap;
use std::time::Duration;

use crate::types::{ToolCall, ToolDefinition, ToolResult};
use super::{ShellTool, FileReadTool, FileWriteTool};

/// Tool handler trait
pub trait ToolHandler: Send + Sync {
    /// Execute a tool call and return the result
    fn execute(&self, arguments: &serde_json::Value) -> Result<String>;

    /// Get the tool definition
    fn definition(&self) -> ToolDefinition;
}

/// Tool executor - manages and dispatches tool calls
pub struct ToolExecutor {
    handlers: HashMap<String, Box<dyn ToolHandler>>,
    timeout: Duration,
}

impl ToolExecutor {
    pub fn new() -> Self {
        let mut executor = Self {
            handlers: HashMap::new(),
            timeout: Duration::from_secs(30),
        };

        // Register built-in tools
        executor.register("shell_execute", Box::new(ShellTool::new()));
        executor.register("file_read", Box::new(FileReadTool::new()));
        executor.register("file_write", Box::new(FileWriteTool::new()));

        executor
    }

    /// Register a tool handler
    pub fn register(&mut self, name: &str, handler: Box<dyn ToolHandler>) {
        self.handlers.insert(name.to_string(), handler);
    }

    /// Execute a tool call
    pub async fn execute(&self, call: &ToolCall) -> ToolResult {
        match self.handlers.get(&call.name) {
            Some(handler) => {
                let result = tokio::time::timeout(self.timeout, async {
                    handler.execute(&call.arguments)
                })
                .await;

                match result {
                    Ok(Ok(output)) => ToolResult {
                        tool_call_id: call.id.clone(),
                        output,
                        is_error: false,
                    },
                    Ok(Err(e)) => ToolResult {
                        tool_call_id: call.id.clone(),
                        output: format!("Tool error: {}", e),
                        is_error: true,
                    },
                    Err(_) => ToolResult {
                        tool_call_id: call.id.clone(),
                        output: "Tool execution timed out".to_string(),
                        is_error: true,
                    },
                }
            }
            None => ToolResult {
                tool_call_id: call.id.clone(),
                output: format!("Unknown tool: {}", call.name),
                is_error: true,
            },
        }
    }

    /// Execute multiple tool calls
    pub async fn execute_all(&self, calls: &[ToolCall]) -> Vec<ToolResult> {
        let mut results = Vec::with_capacity(calls.len());
        for call in calls {
            results.push(self.execute(call).await);
        }
        results
    }

    /// Get all registered tool definitions
    pub fn tool_definitions(&self) -> Vec<ToolDefinition> {
        self.handlers.values().map(|h| h.definition()).collect()
    }

    /// Set execution timeout
    pub fn set_timeout(&mut self, timeout: Duration) {
        self.timeout = timeout;
    }
}

impl Default for ToolExecutor {
    fn default() -> Self {
        Self::new()
    }
}