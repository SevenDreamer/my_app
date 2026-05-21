//! Skill manager - manages agent skills

use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use anyhow::Result;

use crate::types::{Skill, SkillInfo, SkillTrigger, SkillAction};

/// Skill manager - handles skill creation, retrieval, and execution
pub struct SkillManager {
    skills: Arc<RwLock<HashMap<String, Skill>>>,
}

impl SkillManager {
    pub fn new() -> Self {
        Self {
            skills: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    /// Create a new skill
    pub async fn create(
        &self,
        name: String,
        description: String,
        trigger: SkillTrigger,
    ) -> Result<String> {
        let skill = Skill::new(name, description, trigger);
        let id = skill.id.clone();

        let mut skills = self.skills.write().await;
        skills.insert(id.clone(), skill);

        Ok(id)
    }

    /// Get a skill by ID
    pub async fn get(&self, id: &str) -> Result<Option<Skill>> {
        let skills = self.skills.read().await;
        Ok(skills.get(id).cloned())
    }

    /// List all skills
    pub async fn list(&self) -> Result<Vec<SkillInfo>> {
        let skills = self.skills.read().await;
        Ok(skills.values().map(SkillInfo::from).collect())
    }

    /// Update a skill
    pub async fn update(&self, id: &str, skill: Skill) -> Result<()> {
        let mut skills = self.skills.write().await;
        if skills.contains_key(id) {
            skills.insert(id.to_string(), skill);
        }
        Ok(())
    }

    /// Delete a skill
    pub async fn delete(&self, id: &str) -> Result<()> {
        let mut skills = self.skills.write().await;
        skills.remove(id);
        Ok(())
    }

    /// Increment usage count for a skill
    pub async fn increment_usage(&self, id: &str) -> Result<()> {
        let mut skills = self.skills.write().await;
        if let Some(skill) = skills.get_mut(id) {
            skill.usage_count += 1;
        }
        Ok(())
    }

    /// Add an action to a skill
    pub async fn add_action(&self, id: &str, action: SkillAction) -> Result<()> {
        let mut skills = self.skills.write().await;
        if let Some(skill) = skills.get_mut(id) {
            skill.actions.push(action);
        }
        Ok(())
    }

    /// Find skills triggered by a message
    pub async fn find_triggered(&self, message: &str) -> Result<Vec<Skill>> {
        let skills = self.skills.read().await;
        let triggered: Vec<Skill> = skills
            .values()
            .filter(|skill| match &skill.trigger {
                SkillTrigger::Keyword(kw) => message.contains(kw.as_str()),
                SkillTrigger::Pattern(pattern) => {
                    regex::Regex::new(pattern)
                        .map(|re| re.is_match(message))
                        .unwrap_or(false)
                }
                SkillTrigger::Auto => true,
                SkillTrigger::Manual => false,
            })
            .cloned()
            .collect();

        Ok(triggered)
    }

    /// Load skills from storage
    pub async fn load_skills(&self, skills_list: Vec<Skill>) -> Result<()> {
        let mut skills = self.skills.write().await;
        for skill in skills_list {
            skills.insert(skill.id.clone(), skill);
        }
        Ok(())
    }
}

impl Default for SkillManager {
    fn default() -> Self {
        Self::new()
    }
}