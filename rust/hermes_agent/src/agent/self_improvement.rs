//! Self-improvement module - Agent can analyze conversations and create/improve skills

use anyhow::Result;
use crate::llm::{create_client, CompletionRequest};
use crate::types::{Message, Skill, SkillTrigger, SkillAction};
use crate::agent::SkillManager;
use crate::memory::MemoryManager;
use std::sync::Arc;

/// Skill suggestion from the agent
#[derive(Debug, Clone)]
pub struct SkillSuggestion {
    pub name: String,
    pub description: String,
    pub trigger: SkillTrigger,
    pub rationale: String,
}

/// Self-improvement engine
pub struct SelfImprovement {
    skill_manager: Arc<SkillManager>,
    memory_manager: Arc<MemoryManager>,
}

impl SelfImprovement {
    pub fn new(
        skill_manager: Arc<SkillManager>,
        memory_manager: Arc<MemoryManager>,
    ) -> Self {
        Self {
            skill_manager,
            memory_manager,
        }
    }

    /// Analyze a conversation and suggest skills
    pub async fn analyze_conversation(
        &self,
        messages: &[Message],
        model: &str,
    ) -> Result<Vec<SkillSuggestion>> {
        // Build analysis prompt
        let conversation_text: Vec<String> = messages
            .iter()
            .map(|m| format!("[{}]: {}", m.role, m.content))
            .collect();

        let analysis_prompt = format!(
            "Analyze the following conversation and identify patterns that could be \
            automated as skills. A skill should be created when:\n\
            1. The user repeatedly asks for the same type of task\n\
            2. There's a clear pattern that could be triggered automatically\n\
            3. The conversation reveals a reusable workflow\n\n\
            For each suggested skill, provide:\n\
            - name: Short descriptive name\n\
            - description: What the skill does\n\
            - trigger_type: keyword, pattern, or auto\n\
            - trigger_value: The keyword or pattern to trigger on\n\
            - rationale: Why this skill would be useful\n\n\
            Conversation:\n{}\n\n\
            Respond in JSON array format with objects containing name, description, \
            trigger_type, trigger_value, and rationale fields.",
            conversation_text.join("\n")
        );

        // Try to get suggestions from LLM
        let suggestions = match create_client(model.to_string()) {
            Ok(client) => {
                let request = CompletionRequest {
                    messages: vec![Message::user(&analysis_prompt)],
                    model: model.to_string(),
                    temperature: Some(0.5),
                    max_tokens: Some(2000),
                    tools: vec![],
                };

                match client.complete(request).await {
                    Ok(response) => self.parse_suggestions(&response.content),
                    Err(_) => self.fallback_suggestions(messages),
                }
            }
            Err(_) => self.fallback_suggestions(messages),
        };

        Ok(suggestions)
    }

    /// Apply a skill suggestion by creating the skill
    pub async fn apply_suggestion(&self, suggestion: &SkillSuggestion) -> Result<String> {
        self.skill_manager
            .create(
                suggestion.name.clone(),
                suggestion.description.clone(),
                suggestion.trigger.clone(),
            )
            .await
    }

    /// Review and improve existing skills based on usage
    pub async fn review_skills(&self, model: &str) -> Result<Vec<String>> {
        let skills = self.skill_manager.list().await?;
        let mut improvements = Vec::new();

        for skill in &skills {
            // Low usage skills might need better triggers
            if skill.usage_count < 3 {
                improvements.push(format!(
                    "Skill '{}' has low usage ({}). Consider improving its trigger or description.",
                    skill.name, skill.usage_count
                ));
            }
        }

        Ok(improvements)
    }

    /// Parse LLM response into skill suggestions
    fn parse_suggestions(&self, response: &str) -> Vec<SkillSuggestion> {
        // Try to parse as JSON
        let trimmed = response.trim();

        // Extract JSON array from response
        let json_start = trimmed.find('[').unwrap_or(0);
        let json_end = trimmed.rfind(']').map(|i| i + 1).unwrap_or(trimmed.len());
        let json_str = &trimmed[json_start..json_end];

        if let Ok(parsed) = serde_json::from_str::<Vec<serde_json::Value>>(json_str) {
            return parsed
                .iter()
                .filter_map(|item| {
                    let name = item["name"].as_str()?.to_string();
                    let description = item["description"].as_str()?.to_string();
                    let trigger_type = item["trigger_type"].as_str().unwrap_or("keyword");
                    let trigger_value = item["trigger_value"].as_str().unwrap_or("").to_string();
                    let rationale = item["rationale"].as_str().unwrap_or("").to_string();

                    let trigger = match trigger_type {
                        "keyword" => SkillTrigger::Keyword(trigger_value),
                        "pattern" => SkillTrigger::Pattern(trigger_value),
                        "auto" => SkillTrigger::Auto,
                        _ => SkillTrigger::Manual,
                    };

                    Some(SkillSuggestion {
                        name,
                        description,
                        trigger,
                        rationale,
                    })
                })
                .collect();
        }

        Vec::new()
    }

    /// Fallback suggestion logic without LLM
    fn fallback_suggestions(&self, messages: &[Message]) -> Vec<SkillSuggestion> {
        let mut suggestions = Vec::new();

        // Detect repeated commands
        let user_messages: Vec<&str> = messages
            .iter()
            .filter(|m| m.role == crate::types::MessageRole::User)
            .map(|m| m.content.as_str())
            .collect();

        // Check for shell command patterns
        let shell_count = user_messages
            .iter()
            .filter(|m| m.starts_with("run ") || m.starts_with("execute ") || m.contains("sudo"))
            .count();

        if shell_count >= 2 {
            suggestions.push(SkillSuggestion {
                name: "shell_helper".to_string(),
                description: "Help execute shell commands".to_string(),
                trigger: SkillTrigger::Keyword("run".to_string()),
                rationale: "User frequently asks to run commands".to_string(),
            });
        }

        // Check for file operations
        let file_count = user_messages
            .iter()
            .filter(|m| m.contains("file") || m.contains("read") || m.contains("write"))
            .count();

        if file_count >= 2 {
            suggestions.push(SkillSuggestion {
                name: "file_helper".to_string(),
                description: "Help with file operations".to_string(),
                trigger: SkillTrigger::Keyword("file".to_string()),
                rationale: "User frequently works with files".to_string(),
            });
        }

        suggestions
    }
}