//! Skill types

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// Skill trigger type
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", content = "value")]
pub enum SkillTrigger {
    Keyword(String),
    Pattern(String),
    Manual,
    Auto,
}

/// Skill action
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SkillAction {
    pub description: String,
    pub prompt_template: String,
}

/// Agent skill
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Skill {
    pub id: String,
    pub name: String,
    pub description: String,
    pub trigger: SkillTrigger,
    pub actions: Vec<SkillAction>,
    pub usage_count: u32,
    pub created_at: DateTime<Utc>,
}

impl Skill {
    pub fn new(
        name: impl Into<String>,
        description: impl Into<String>,
        trigger: SkillTrigger,
    ) -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            name: name.into(),
            description: description.into(),
            trigger,
            actions: Vec::new(),
            usage_count: 0,
            created_at: Utc::now(),
        }
    }
}

/// Lightweight skill info for FRB
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SkillInfo {
    pub id: String,
    pub name: String,
    pub description: String,
    pub trigger_type: String,
    pub usage_count: u32,
}

impl From<&Skill> for SkillInfo {
    fn from(skill: &Skill) -> Self {
        Self {
            id: skill.id.clone(),
            name: skill.name.clone(),
            description: skill.description.clone(),
            trigger_type: match &skill.trigger {
                SkillTrigger::Keyword(_) => "keyword",
                SkillTrigger::Pattern(_) => "pattern",
                SkillTrigger::Manual => "manual",
                SkillTrigger::Auto => "auto",
            }.to_string(),
            usage_count: skill.usage_count,
        }
    }
}
