//! Shell execution tool

use anyhow::Result;
use serde_json::Value;

use super::executor::ToolHandler;
use crate::types::ToolDefinition;

/// Shell command execution tool
pub struct ShellTool {
    timeout: std::time::Duration,
}

impl ShellTool {
    pub fn new() -> Self {
        Self {
            timeout: std::time::Duration::from_secs(30),
        }
    }

    pub fn with_timeout(timeout: std::time::Duration) -> Self {
        Self { timeout }
    }
}

impl ToolHandler for ShellTool {
    fn execute(&self, arguments: &Value) -> Result<String> {
        let command = arguments["command"]
            .as_str()
            .ok_or_else(|| anyhow::anyhow!("Missing 'command' argument"))?;

        let output = std::process::Command::new("sh")
            .arg("-c")
            .arg(command)
            .output()?;

        let stdout = String::from_utf8_lossy(&output.stdout).to_string();
        let stderr = String::from_utf8_lossy(&output.stderr).to_string();

        if output.status.success() {
            if stderr.is_empty() {
                Ok(stdout)
            } else {
                Ok(format!("{}\n[stderr]: {}", stdout, stderr))
            }
        } else {
            let code = output.status.code().unwrap_or(-1);
            anyhow::bail!("Exit code {}: {}\n{}", code, stdout, stderr)
        }
    }

    fn definition(&self) -> ToolDefinition {
        ToolDefinition::new(
            "shell_execute",
            "Execute a shell command and return the output",
            serde_json::json!({
                "type": "object",
                "properties": {
                    "command": {
                        "type": "string",
                        "description": "The shell command to execute"
                    }
                },
                "required": ["command"]
            }),
        )
    }
}

impl Default for ShellTool {
    fn default() -> Self {
        Self::new()
    }
}