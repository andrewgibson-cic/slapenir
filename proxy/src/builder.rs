// SLAPENIR Strategy Builder - Builds strategy instances from configuration

use crate::config::{Config, StrategyConfig};
use crate::strategies::AWSSigV4Strategy;
use crate::strategy::{AuthStrategy, BearerStrategy, StrategyError};

/// Build strategy instances from configuration
pub fn build_strategies_from_config(config: &Config) -> Result<Vec<Box<dyn AuthStrategy>>, String> {
    let mut strategies: Vec<Box<dyn AuthStrategy>> = Vec::new();

    for strategy_config in &config.strategies {
        match build_strategy(strategy_config) {
            Ok(strategy) => {
                tracing::info!(
                    "✓ Built strategy '{}' (type: {})",
                    strategy_config.name,
                    strategy_config.strategy_type
                );
                strategies.push(strategy);
            }
            Err(e) => {
                tracing::error!(
                    "✗ Failed to build strategy '{}': {}",
                    strategy_config.name,
                    e
                );
                return Err(format!(
                    "Failed to build strategy '{}': {}",
                    strategy_config.name, e
                ));
            }
        }
    }

    if strategies.is_empty() {
        return Err("No strategies were successfully built".to_string());
    }

    tracing::info!("✓ Built {} strategies total", strategies.len());
    Ok(strategies)
}

/// Build a single strategy from configuration
fn build_strategy(config: &StrategyConfig) -> Result<Box<dyn AuthStrategy>, StrategyError> {
    match config.strategy_type.as_str() {
        "bearer" => {
            let env_var = config.config.env_var.as_ref().ok_or_else(|| {
                StrategyError::InvalidCredential("Bearer strategy missing env_var".to_string())
            })?;

            let dummy_pattern = config.config.dummy_pattern.as_ref().ok_or_else(|| {
                StrategyError::InvalidCredential(
                    "Bearer strategy missing dummy_pattern".to_string(),
                )
            })?;

            let strategy = BearerStrategy::new(
                config.name.clone(),
                env_var.clone(),
                dummy_pattern.clone(),
                config.config.allowed_hosts.clone(),
            )?;

            Ok(Box::new(strategy))
        }

        "aws_sigv4" => {
            let access_key_env = config.config.access_key_env.as_ref().ok_or_else(|| {
                StrategyError::InvalidCredential(
                    "AWS SigV4 strategy missing access_key_env".to_string(),
                )
            })?;

            let secret_key_env = config.config.secret_key_env.as_ref().ok_or_else(|| {
                StrategyError::InvalidCredential(
                    "AWS SigV4 strategy missing secret_key_env".to_string(),
                )
            })?;

            let region = config.config.region.as_ref().ok_or_else(|| {
                StrategyError::InvalidCredential("AWS SigV4 strategy missing region".to_string())
            })?;

            let strategy = AWSSigV4Strategy::new(
                config.name.clone(),
                access_key_env.clone(),
                secret_key_env.clone(),
                region.clone(),
                None, // service is auto-detected from host
                config.config.allowed_hosts.clone(),
            )?;

            Ok(Box::new(strategy))
        }

        "hmac" => {
            // TODO: Implement HMAC strategy in future phase
            Err(StrategyError::InvalidCredential(
                "HMAC strategy not yet implemented".to_string(),
            ))
        }

        _ => Err(StrategyError::InvalidCredential(format!(
            "Unknown strategy type: {}",
            config.strategy_type
        ))),
    }
}

/// Check if host matches any telemetry domains
pub fn is_telemetry_domain(host: &str, telemetry_domains: &[String]) -> bool {
    let host_lower = host.to_lowercase();

    for domain in telemetry_domains {
        let domain_lower = domain.to_lowercase();

        // Wildcard match (*.example.com)
        if let Some(base) = domain_lower.strip_prefix("*.") {
            if host_lower.ends_with(base) || host_lower == base {
                return true;
            }
        }
        // Exact match
        else if host_lower == domain_lower {
            return true;
        }
        // Subdomain match (domain matches as base)
        else if host_lower.ends_with(&format!(".{}", domain_lower)) {
            return true;
        }
    }

    false
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_is_telemetry_domain_exact() {
        let domains = vec!["telemetry.anthropic.com".to_string()];
        assert!(is_telemetry_domain("telemetry.anthropic.com", &domains));
        assert!(!is_telemetry_domain("api.anthropic.com", &domains));
    }

    #[test]
    fn test_is_telemetry_domain_wildcard() {
        let domains = vec!["*.sentry.io".to_string()];
        assert!(is_telemetry_domain("app.sentry.io", &domains));
        assert!(is_telemetry_domain("sentry.io", &domains));
        assert!(!is_telemetry_domain("evil.com", &domains));
    }

    #[test]
    fn test_is_telemetry_domain_subdomain() {
        let domains = vec!["segment.com".to_string()];
        assert!(is_telemetry_domain("segment.com", &domains));
        assert!(is_telemetry_domain("api.segment.com", &domains));
        assert!(!is_telemetry_domain("segment.com.evil.com", &domains));
    }

    #[test]
    fn test_build_bearer_strategy() {
        use crate::config::StrategyParams;

        std::env::set_var("TEST_BUILD_TOKEN", "test_token_123");

        let config = StrategyConfig {
            name: "test".to_string(),
            strategy_type: "bearer".to_string(),
            config: StrategyParams {
                env_var: Some("TEST_BUILD_TOKEN".to_string()),
                dummy_pattern: Some("DUMMY_TEST".to_string()),
                allowed_hosts: vec!["api.example.com".to_string()],
                access_key_env: None,
                secret_key_env: None,
                region: None,
            },
        };

        let strategy = build_strategy(&config).unwrap();
        assert_eq!(strategy.name(), "test");
        assert_eq!(strategy.strategy_type(), "bearer");
    }

    #[test]
    fn test_build_strategy_missing_env_var() {
        use crate::config::StrategyParams;

        let config = StrategyConfig {
            name: "test".to_string(),
            strategy_type: "bearer".to_string(),
            config: StrategyParams {
                env_var: Some("MISSING_ENV_VAR".to_string()),
                dummy_pattern: Some("DUMMY".to_string()),
                allowed_hosts: vec![],
                access_key_env: None,
                secret_key_env: None,
                region: None,
            },
        };

        let result = build_strategy(&config);
        assert!(result.is_ok()); // Strategy builds but warns about missing env var
    }

    #[test]
    fn test_build_strategy_unknown_type() {
        use crate::config::StrategyParams;

        let config = StrategyConfig {
            name: "test".to_string(),
            strategy_type: "unknown".to_string(),
            config: StrategyParams {
                env_var: None,
                dummy_pattern: None,
                allowed_hosts: vec![],
                access_key_env: None,
                secret_key_env: None,
                region: None,
            },
        };

        let result = build_strategy(&config);
        assert!(result.is_err());
    }
}
