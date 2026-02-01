// SLAPENIR Configuration - YAML-based strategy configuration
// Inspired by safe-claude's flexible configuration system

use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;

/// Main configuration structure
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    /// Authentication strategies
    pub strategies: Vec<StrategyConfig>,

    /// Security settings
    #[serde(default)]
    pub security: SecurityConfig,

    /// Logging configuration
    #[serde(default)]
    pub logging: LoggingConfig,
}

/// Strategy configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StrategyConfig {
    /// Strategy name for identification
    pub name: String,

    /// Strategy type (bearer, aws_sigv4, hmac, etc.)
    #[serde(rename = "type")]
    pub strategy_type: String,

    /// Strategy-specific configuration
    pub config: StrategyParams,
}

/// Strategy parameters (flexible key-value pairs)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StrategyParams {
    /// Environment variable name for the credential
    #[serde(skip_serializing_if = "Option::is_none")]
    pub env_var: Option<String>,

    /// Dummy pattern to detect in requests
    #[serde(skip_serializing_if = "Option::is_none")]
    pub dummy_pattern: Option<String>,

    /// Allowed destination hosts for this credential
    #[serde(default)]
    pub allowed_hosts: Vec<String>,

    /// AWS-specific: access key environment variable
    #[serde(skip_serializing_if = "Option::is_none")]
    pub access_key_env: Option<String>,

    /// AWS-specific: secret key environment variable
    #[serde(skip_serializing_if = "Option::is_none")]
    pub secret_key_env: Option<String>,

    /// AWS-specific: region
    #[serde(skip_serializing_if = "Option::is_none")]
    pub region: Option<String>,
}

/// Security configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SecurityConfig {
    /// Fail mode: "closed" (block on error) or "open" (allow on error)
    #[serde(default = "default_fail_mode")]
    pub fail_mode: String,

    /// Enable telemetry blocking
    #[serde(default = "default_true")]
    pub block_telemetry: bool,

    /// List of telemetry domains to block
    #[serde(default)]
    pub telemetry_domains: Vec<String>,
}

impl Default for SecurityConfig {
    fn default() -> Self {
        Self {
            fail_mode: "closed".to_string(),
            block_telemetry: true,
            telemetry_domains: vec![
                "telemetry.anthropic.com".to_string(),
                "sentry.io".to_string(),
                "*.sentry.io".to_string(),
                "segment.com".to_string(),
                "*.segment.com".to_string(),
                "mixpanel.com".to_string(),
                "*.mixpanel.com".to_string(),
            ],
        }
    }
}

/// Logging configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LoggingConfig {
    /// Log level: debug, info, warn, error
    #[serde(default = "default_log_level")]
    pub level: String,

    /// Log format: json or text
    #[serde(default = "default_log_format")]
    pub format: String,
}

impl Default for LoggingConfig {
    fn default() -> Self {
        Self {
            level: "info".to_string(),
            format: "json".to_string(),
        }
    }
}

// Default value functions for serde
fn default_fail_mode() -> String {
    "closed".to_string()
}

fn default_true() -> bool {
    true
}

fn default_log_level() -> String {
    "info".to_string()
}

fn default_log_format() -> String {
    "json".to_string()
}

impl Config {
    /// Load configuration from YAML file
    pub fn from_file<P: AsRef<Path>>(path: P) -> Result<Self, String> {
        let content = fs::read_to_string(path.as_ref())
            .map_err(|e| format!("Failed to read config file: {}", e))?;

        Self::from_yaml(&content)
    }

    /// Parse configuration from YAML string
    pub fn from_yaml(yaml: &str) -> Result<Self, String> {
        serde_yaml::from_str(yaml).map_err(|e| format!("Failed to parse config YAML: {}", e))
    }

    /// Validate configuration
    pub fn validate(&self) -> Result<(), String> {
        if self.strategies.is_empty() {
            return Err("No strategies configured".to_string());
        }

        for strategy in &self.strategies {
            // Validate strategy name is not empty
            if strategy.name.is_empty() {
                return Err("Strategy name cannot be empty".to_string());
            }

            // Validate strategy type
            match strategy.strategy_type.as_str() {
                "bearer" | "aws_sigv4" | "hmac" => {}
                _ => {
                    return Err(format!(
                        "Unknown strategy type '{}' for strategy '{}'",
                        strategy.strategy_type, strategy.name
                    ));
                }
            }

            // Validate bearer strategy has required fields
            if strategy.strategy_type == "bearer" {
                if strategy.config.env_var.is_none() {
                    return Err(format!(
                        "Bearer strategy '{}' missing env_var",
                        strategy.name
                    ));
                }
                if strategy.config.dummy_pattern.is_none() {
                    return Err(format!(
                        "Bearer strategy '{}' missing dummy_pattern",
                        strategy.name
                    ));
                }
            }

            // Validate AWS SigV4 strategy has required fields
            if strategy.strategy_type == "aws_sigv4" {
                if strategy.config.access_key_env.is_none()
                    || strategy.config.secret_key_env.is_none()
                {
                    return Err(format!(
                        "AWS SigV4 strategy '{}' missing access_key_env or secret_key_env",
                        strategy.name
                    ));
                }
            }
        }

        // Validate fail mode
        match self.security.fail_mode.as_str() {
            "closed" | "open" => {}
            _ => {
                return Err(format!(
                    "Invalid fail_mode '{}', must be 'closed' or 'open'",
                    self.security.fail_mode
                ));
            }
        }

        Ok(())
    }

    /// Load configuration with fallback to default
    pub fn load_or_default() -> Self {
        // Try to load from default location
        let config_paths = vec!["config.yaml", "proxy/config.yaml", "/app/config.yaml"];

        for path in config_paths {
            if Path::new(path).exists() {
                match Self::from_file(path) {
                    Ok(config) => {
                        tracing::info!("✓ Loaded configuration from {}", path);
                        if let Err(e) = config.validate() {
                            tracing::error!("Configuration validation failed: {}", e);
                            continue;
                        }
                        return config;
                    }
                    Err(e) => {
                        tracing::warn!("Failed to load config from {}: {}", path, e);
                    }
                }
            }
        }

        // Fall back to default configuration
        tracing::warn!("⚠ Using default configuration (no config.yaml found)");
        Self::default_config()
    }

    /// Default configuration for backward compatibility
    fn default_config() -> Self {
        Self {
            strategies: vec![
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
            ],
            security: SecurityConfig::default(),
            logging: LoggingConfig::default(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_valid_config() {
        let yaml = r#"
strategies:
  - name: openai
    type: bearer
    config:
      env_var: OPENAI_API_KEY
      dummy_pattern: DUMMY_OPENAI
      allowed_hosts:
        - api.openai.com

security:
  fail_mode: closed
  block_telemetry: true

logging:
  level: info
  format: json
"#;

        let config = Config::from_yaml(yaml).unwrap();
        assert_eq!(config.strategies.len(), 1);
        assert_eq!(config.strategies[0].name, "openai");
        assert_eq!(config.security.fail_mode, "closed");
    }

    #[test]
    fn test_validate_missing_strategies() {
        let config = Config {
            strategies: vec![],
            security: SecurityConfig::default(),
            logging: LoggingConfig::default(),
        };

        assert!(config.validate().is_err());
    }

    #[test]
    fn test_validate_invalid_fail_mode() {
        let mut config = Config::default_config();
        config.security.fail_mode = "invalid".to_string();

        assert!(config.validate().is_err());
    }

    #[test]
    fn test_default_config() {
        let config = Config::default_config();
        assert!(!config.strategies.is_empty());
        assert_eq!(config.security.fail_mode, "closed");
        assert!(config.security.block_telemetry);
    }
}
