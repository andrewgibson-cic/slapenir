// SLAPENIR Auto-Detection - Automatic API strategy discovery
// Scans environment variables and matches against PostgreSQL database of known APIs

use crate::config::{StrategyConfig, StrategyParams};
use crate::strategy::AuthStrategy;
use crate::strategies::AWSSigV4Strategy;
use crate::strategy::BearerStrategy;
use sqlx::postgres::{PgPool, PgPoolOptions};
use sqlx::Row;
use std::collections::HashSet;
use std::env;

/// Auto-detection configuration
#[derive(Debug, Clone)]
pub struct AutoDetectConfig {
    /// Whether auto-detection is enabled
    pub enabled: bool,
    /// Database connection URL
    pub database_url: String,
    /// List of API names to exclude from auto-detection
    pub exclude: Vec<String>,
    /// Maximum number of strategies to auto-detect
    pub max_strategies: usize,
}

impl Default for AutoDetectConfig {
    fn default() -> Self {
        Self {
            enabled: true,
            database_url: String::new(),
            exclude: Vec::new(),
            max_strategies: 100,
        }
    }
}

impl AutoDetectConfig {
    /// Load auto-detect configuration from environment
    pub fn from_env() -> Self {
        Self {
            enabled: env::var("AUTO_DETECT_ENABLED")
                .unwrap_or_else(|_| "true".to_string())
                .parse()
                .unwrap_or(true),
            database_url: env::var("DATABASE_URL").unwrap_or_default(),
            exclude: env::var("AUTO_DETECT_EXCLUDE")
                .map(|s| s.split(',').map(|s| s.trim().to_string()).collect())
                .unwrap_or_default(),
            max_strategies: env::var("AUTO_DETECT_MAX")
                .ok()
                .and_then(|s| s.parse().ok())
                .unwrap_or(100),
        }
    }
}

/// API definition from database
#[derive(Debug, Clone)]
pub struct ApiDefinition {
    pub name: String,
    pub display_name: String,
    pub category: String,
    pub env_vars: Vec<String>,
    pub strategy_type: String,
    pub dummy_prefix: String,
    pub allowed_hosts: Vec<String>,
    pub header_name: Option<String>,
}

/// Result of auto-detection scan
#[derive(Debug)]
pub struct AutoDetectResult {
    /// Strategies that were auto-detected
    pub detected: Vec<StrategyConfig>,
    /// Environment variables that matched known APIs
    pub matched_env_vars: Vec<String>,
    /// Environment variables that didn't match any known API
    pub unmatched_env_vars: Vec<String>,
}

/// Auto-detection scanner
pub struct AutoDetector {
    pool: PgPool,
    config: AutoDetectConfig,
}

impl AutoDetector {
    /// Create a new auto-detector with database connection
    pub async fn new(config: AutoDetectConfig) -> Result<Self, String> {
        if config.database_url.is_empty() {
            return Err("DATABASE_URL not configured".to_string());
        }

        tracing::info!("Connecting to auto-detection database...");

        let pool = PgPoolOptions::new()
            .max_connections(5)
            .connect(&config.database_url)
            .await
            .map_err(|e| format!("Failed to connect to database: {}", e))?;

        tracing::info!("Successfully connected to auto-detection database");

        Ok(Self { pool, config })
    }

    /// Scan environment variables and detect matching APIs
    pub async fn scan(&self) -> Result<AutoDetectResult, String> {
        if !self.config.enabled {
            tracing::info!("Auto-detection is disabled");
            return Ok(AutoDetectResult {
                detected: Vec::new(),
                matched_env_vars: Vec::new(),
                unmatched_env_vars: Vec::new(),
            });
        }

        // Get all environment variables
        let env_vars: HashSet<String> = env::vars().map(|(k, _)| k).collect();
        tracing::debug!("Scanning {} environment variables for known APIs", env_vars.len());

        // Query database for APIs that match any of the env vars
        let apis = self.query_matching_apis(&env_vars).await?;

        let mut detected = Vec::new();
        let mut matched_env_vars = Vec::new();
        let mut unmatched_env_vars = Vec::new();

        for api in apis {
            // Skip excluded APIs
            if self.config.exclude.contains(&api.name) {
                tracing::debug!("Skipping excluded API: {}", api.name);
                continue;
            }

            // Check if any of the API's env vars are set
            let matching_env_var = api
                .env_vars
                .iter()
                .find(|ev| env_vars.contains(*ev));

            if let Some(env_var) = matching_env_var {
                tracing::info!(
                    "Auto-detected API '{}' via environment variable '{}'",
                    api.display_name,
                    env_var
                );

                // Convert to StrategyConfig
                let strategy_config = self.api_to_strategy_config(&api, env_var);
                detected.push(strategy_config);
                matched_env_vars.push(env_var.clone());

                if detected.len() >= self.config.max_strategies {
                    tracing::warn!("Reached max strategies limit ({})", self.config.max_strategies);
                    break;
                }
            }
        }

        // Find unmatched env vars that look like API keys
        for (key, value) in env::vars() {
            if matched_env_vars.contains(&key) {
                continue;
            }

            // Check if it looks like an API key env var
            if Self::looks_like_api_key_env(&key, &value) {
                unmatched_env_vars.push(key);
            }
        }

        tracing::info!(
            "Auto-detection complete: {} APIs detected, {} unmatched potential API keys",
            detected.len(),
            unmatched_env_vars.len()
        );

        if !unmatched_env_vars.is_empty() {
            tracing::debug!(
                "Unmatched potential API keys: {:?}",
                unmatched_env_vars
            );
        }

        Ok(AutoDetectResult {
            detected,
            matched_env_vars,
            unmatched_env_vars,
        })
    }

    /// Query database for APIs matching the given environment variables
    async fn query_matching_apis(&self, env_vars: &HashSet<String>) -> Result<Vec<ApiDefinition>, String> {
        let env_var_list: Vec<String> = env_vars.iter().cloned().collect();

        let rows = sqlx::query(
            r#"
            SELECT DISTINCT
                name, display_name, category::text, env_vars, strategy_type::text,
                dummy_prefix, allowed_hosts, header_name
            FROM api_definitions
            WHERE is_active = true
            AND env_vars && $1::text[]
            ORDER BY name
            "#
        )
        .bind(&env_var_list)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| format!("Failed to query API definitions: {}", e))?;

        let apis: Vec<ApiDefinition> = rows
            .into_iter()
            .map(|row| ApiDefinition {
                name: row.get("name"),
                display_name: row.get("display_name"),
                category: row.get("category"),
                env_vars: row.get("env_vars"),
                strategy_type: row.get("strategy_type"),
                dummy_prefix: row.get("dummy_prefix"),
                allowed_hosts: row.get("allowed_hosts"),
                header_name: row.get("header_name"),
            })
            .collect();

        tracing::debug!("Found {} matching API definitions in database", apis.len());

        Ok(apis)
    }

    /// Convert API definition to StrategyConfig
    fn api_to_strategy_config(&self, api: &ApiDefinition, env_var: &str) -> StrategyConfig {
        StrategyConfig {
            name: api.name.clone(),
            strategy_type: api.strategy_type.clone(),
            config: StrategyParams {
                env_var: Some(env_var.to_string()),
                dummy_pattern: Some(api.dummy_prefix.clone()),
                allowed_hosts: api.allowed_hosts.clone(),
                access_key_env: if api.strategy_type == "aws_sigv4" {
                    Some(env_var.to_string())
                } else {
                    None
                },
                secret_key_env: if api.strategy_type == "aws_sigv4" {
                    Some("AWS_SECRET_ACCESS_KEY".to_string())
                } else {
                    None
                },
                region: if api.strategy_type == "aws_sigv4" {
                    Some("us-east-1".to_string())
                } else {
                    None
                },
            },
        }
    }

    /// Check if an environment variable looks like it might contain an API key
    fn looks_like_api_key_env(key: &str, value: &str) -> bool {
        let key_upper = key.to_uppercase();

        let is_api_key_pattern = key_upper.ends_with("_API_KEY")
            || key_upper.ends_with("_TOKEN")
            || key_upper.ends_with("_SECRET")
            || key_upper.ends_with("_ACCESS_TOKEN")
            || key_upper.ends_with("_AUTH_TOKEN")
            || key_upper.starts_with("API_KEY_")
            || key_upper.contains("APIKEY");

        let value_looks_like_secret = value.len() >= 16
            && (value.starts_with("sk-")
                || value.starts_with("ghp_")
                || value.starts_with("gho_")
                || value.starts_with("xoxb-")
                || value.starts_with("xoxp-")
                || value.starts_with("AKIA")
                || value.starts_with("AIza")
                || value.chars().all(|c| c.is_alphanumeric() || c == '-' || c == '_'));

        is_api_key_pattern && value_looks_like_secret
    }

    /// Build AuthStrategy instances from detected configurations
    pub fn build_strategies(configs: &[StrategyConfig]) -> Result<Vec<Box<dyn AuthStrategy>>, String> {
        let mut strategies: Vec<Box<dyn AuthStrategy>> = Vec::new();

        for config in configs {
            match config.strategy_type.as_str() {
                "bearer" => {
                    let env_var = config.config.env_var.as_ref().ok_or_else(|| {
                        format!("Bearer strategy '{}' missing env_var", config.name)
                    })?;

                    let dummy_pattern = config.config.dummy_pattern.clone().unwrap_or_else(|| {
                        format!("DUMMY_{}", config.name.to_uppercase())
                    });

                    match BearerStrategy::new(
                        config.name.clone(),
                        env_var.clone(),
                        dummy_pattern,
                        config.config.allowed_hosts.clone(),
                    ) {
                        Ok(strategy) => {
                            tracing::debug!("Built bearer strategy for '{}'", config.name);
                            strategies.push(Box::new(strategy));
                        }
                        Err(e) => {
                            tracing::warn!(
                                "Failed to build bearer strategy '{}': {}",
                                config.name, e
                            );
                        }
                    }
                }

                "aws_sigv4" => {
                    let access_key_env = config.config.access_key_env.as_ref().ok_or_else(|| {
                        format!("AWS SigV4 strategy '{}' missing access_key_env", config.name)
                    })?;

                    let secret_key_env = config.config.secret_key_env.as_ref().ok_or_else(|| {
                        format!("AWS SigV4 strategy '{}' missing secret_key_env", config.name)
                    })?;

                    let region = config.config.region.clone().unwrap_or_else(|| "us-east-1".to_string());

                    match AWSSigV4Strategy::new(
                        config.name.clone(),
                        access_key_env.clone(),
                        secret_key_env.clone(),
                        region,
                        None,
                        config.config.allowed_hosts.clone(),
                    ) {
                        Ok(strategy) => {
                            tracing::debug!("Built AWS SigV4 strategy for '{}'", config.name);
                            strategies.push(Box::new(strategy));
                        }
                        Err(e) => {
                            tracing::warn!(
                                "Failed to build AWS SigV4 strategy '{}': {}",
                                config.name, e
                            );
                        }
                    }
                }

                "hmac" => {
                    tracing::warn!(
                        "HMAC strategy '{}' detected but not yet implemented",
                        config.name
                    );
                    if let Some(env_var) = &config.config.env_var {
                        let dummy_pattern = config.config.dummy_pattern.clone().unwrap_or_else(|| {
                            format!("DUMMY_{}", config.name.to_uppercase())
                        });

                        match BearerStrategy::new(
                            config.name.clone(),
                            env_var.clone(),
                            dummy_pattern,
                            config.config.allowed_hosts.clone(),
                        ) {
                            Ok(strategy) => {
                                tracing::debug!("Built HMAC strategy as bearer for '{}'", config.name);
                                strategies.push(Box::new(strategy));
                            }
                            Err(e) => {
                                tracing::warn!(
                                    "Failed to build HMAC strategy '{}': {}",
                                    config.name, e
                                );
                            }
                        }
                    }
                }

                _ => {
                    tracing::warn!("Unknown strategy type '{}' for '{}'", config.strategy_type, config.name);
                }
            }
        }

        Ok(strategies)
    }

    /// Close database connection
    pub async fn close(self) {
        self.pool.close().await;
    }
}

/// Merge auto-detected strategies with manual config
pub fn merge_strategies(
    auto_detected: Vec<StrategyConfig>,
    manual: Vec<StrategyConfig>,
) -> Vec<StrategyConfig> {
    let mut result = manual.clone();
    let manual_names: HashSet<String> = manual.iter().map(|s| s.name.clone()).collect();

    for auto in auto_detected {
        if !manual_names.contains(&auto.name) {
            result.push(auto);
        } else {
            tracing::debug!(
                "Skipping auto-detected '{}' - manual config exists",
                auto.name
            );
        }
    }

    result
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_looks_like_api_key_env() {
        assert!(AutoDetector::looks_like_api_key_env(
            "OPENAI_API_KEY",
            "sk-1234567890abcdef"
        ));
        assert!(AutoDetector::looks_like_api_key_env(
            "GITHUB_TOKEN",
            "ghp_1234567890abcdef"
        ));
        assert!(AutoDetector::looks_like_api_key_env(
            "MY_SECRET_TOKEN",
            "abcdefghij1234567890"
        ));

        assert!(!AutoDetector::looks_like_api_key_env("PATH", "/usr/bin"));
        assert!(!AutoDetector::looks_like_api_key_env("HOME", "/home/user"));
        assert!(!AutoDetector::looks_like_api_key_env("MY_API_KEY", "short"));
    }

    #[test]
    fn test_merge_strategies() {
        let auto = vec![
            StrategyConfig {
                name: "openai".to_string(),
                strategy_type: "bearer".to_string(),
                config: StrategyParams {
                    env_var: Some("OPENAI_API_KEY".to_string()),
                    dummy_pattern: Some("DUMMY_OPENAI".to_string()),
                    allowed_hosts: vec!["api.openai.com".to_string()],
                    access_key_env: None,
                    secret_key_env: None,
                    region: None,
                },
            },
            StrategyConfig {
                name: "anthropic".to_string(),
                strategy_type: "bearer".to_string(),
                config: StrategyParams {
                    env_var: Some("ANTHROPIC_API_KEY".to_string()),
                    dummy_pattern: Some("DUMMY_ANTHROPIC".to_string()),
                    allowed_hosts: vec!["api.anthropic.com".to_string()],
                    access_key_env: None,
                    secret_key_env: None,
                    region: None,
                },
            },
        ];

        let manual = vec![StrategyConfig {
            name: "openai".to_string(),
            strategy_type: "bearer".to_string(),
            config: StrategyParams {
                env_var: Some("MY_CUSTOM_OPENAI_KEY".to_string()),
                dummy_pattern: Some("DUMMY_CUSTOM".to_string()),
                allowed_hosts: vec!["api.openai.com".to_string()],
                access_key_env: None,
                secret_key_env: None,
                region: None,
            },
        }];

        let merged = merge_strategies(auto, manual);

        assert_eq!(merged.len(), 2);
        assert!(merged.iter().any(|s| s.name == "openai"));
        assert!(merged.iter().any(|s| s.name == "anthropic"));

        let openai = merged.iter().find(|s| s.name == "openai").unwrap();
        assert_eq!(openai.config.env_var, Some("MY_CUSTOM_OPENAI_KEY".to_string()));
    }
}
