//! Cron scheduler - scheduled task execution

use std::sync::Arc;
use tokio::sync::RwLock;
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use anyhow::Result;

/// Scheduled task
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScheduledTask {
    pub id: String,
    pub name: String,
    pub cron_expression: String,
    pub command: String,
    pub enabled: bool,
    pub last_run: Option<DateTime<Utc>>,
    pub next_run: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
}

impl ScheduledTask {
    pub fn new(name: String, cron_expression: String, command: String) -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            name,
            cron_expression,
            command,
            enabled: true,
            last_run: None,
            next_run: None,
            created_at: Utc::now(),
        }
    }
}

/// Lightweight task info for FRB
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaskInfo {
    pub id: String,
    pub name: String,
    pub cron_expression: String,
    pub enabled: bool,
    pub last_run: Option<String>,
    pub next_run: Option<String>,
}

impl From<&ScheduledTask> for TaskInfo {
    fn from(task: &ScheduledTask) -> Self {
        Self {
            id: task.id.clone(),
            name: task.name.clone(),
            cron_expression: task.cron_expression.clone(),
            enabled: task.enabled,
            last_run: task.last_run.map(|d| d.to_rfc3339()),
            next_run: task.next_run.map(|d| d.to_rfc3339()),
        }
    }
}

/// Cron scheduler - manages scheduled tasks
pub struct CronScheduler {
    tasks: Arc<RwLock<Vec<ScheduledTask>>>,
}

impl CronScheduler {
    pub fn new() -> Self {
        Self {
            tasks: Arc::new(RwLock::new(Vec::new())),
        }
    }

    /// Add a new scheduled task
    pub async fn add_task(&self, name: String, cron_expression: String, command: String) -> Result<String> {
        let task = ScheduledTask::new(name, cron_expression, command);
        let id = task.id.clone();

        let mut tasks = self.tasks.write().await;
        tasks.push(task);

        Ok(id)
    }

    /// Get a task by ID
    pub async fn get_task(&self, id: &str) -> Result<Option<ScheduledTask>> {
        let tasks = self.tasks.read().await;
        Ok(tasks.iter().find(|t| t.id == id).cloned())
    }

    /// List all tasks
    pub async fn list_tasks(&self) -> Result<Vec<TaskInfo>> {
        let tasks = self.tasks.read().await;
        Ok(tasks.iter().map(TaskInfo::from).collect())
    }

    /// Enable a task
    pub async fn enable_task(&self, id: &str) -> Result<()> {
        let mut tasks = self.tasks.write().await;
        if let Some(task) = tasks.iter_mut().find(|t| t.id == id) {
            task.enabled = true;
        }
        Ok(())
    }

    /// Disable a task
    pub async fn disable_task(&self, id: &str) -> Result<()> {
        let mut tasks = self.tasks.write().await;
        if let Some(task) = tasks.iter_mut().find(|t| t.id == id) {
            task.enabled = false;
        }
        Ok(())
    }

    /// Delete a task
    pub async fn delete_task(&self, id: &str) -> Result<()> {
        let mut tasks = self.tasks.write().await;
        tasks.retain(|t| t.id != id);
        Ok(())
    }

    /// Execute a task manually
    pub async fn execute_task(&self, id: &str) -> Result<String> {
        let tasks = self.tasks.read().await;
        if let Some(task) = tasks.iter().find(|t| t.id == id) {
            // Execute the command
            let output = std::process::Command::new("sh")
                .arg("-c")
                .arg(&task.command)
                .output();

            match output {
                Ok(output) => {
                    let stdout = String::from_utf8_lossy(&output.stdout).to_string();
                    let stderr = String::from_utf8_lossy(&output.stderr).to_string();

                    if output.status.success() {
                        Ok(format!("{}\n{}", stdout, stderr))
                    } else {
                        Err(anyhow::anyhow!("Task failed: {}", stderr))
                    }
                }
                Err(e) => Err(anyhow::anyhow!("Failed to execute task: {}", e)),
            }
        } else {
            Err(anyhow::anyhow!("Task not found: {}", id))
        }
    }

    /// Check and run due tasks
    pub async fn check_and_run(&self) -> Result<Vec<String>> {
        let mut results = Vec::new();
        let mut tasks = self.tasks.write().await;

        for task in tasks.iter_mut() {
            if task.enabled {
                // Simple check: if no next_run, schedule it
                if task.next_run.is_none() {
                    task.next_run = Some(Utc::now());
                }

                // Check if due
                if let Some(next_run) = task.next_run {
                    if next_run <= Utc::now() {
                        // Execute task
                        let output = std::process::Command::new("sh")
                            .arg("-c")
                            .arg(&task.command)
                            .output();

                        let result = match output {
                            Ok(o) => String::from_utf8_lossy(&o.stdout).to_string(),
                            Err(e) => format!("Error: {}", e),
                        };

                        results.push(format!("[{}] {}", task.name, result));

                        // Update timestamps
                        task.last_run = Some(Utc::now());
                        task.next_run = Some(Utc::now() + chrono::Duration::hours(1)); // Simple: next hour
                    }
                }
            }
        }

        Ok(results)
    }
}

impl Default for CronScheduler {
    fn default() -> Self {
        Self::new()
    }
}