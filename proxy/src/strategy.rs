// SLAPENIR Strategy Pattern - Pluggable authentication strategies
// Inspired by safe-claude's modular architecture

use axum::http::HeaderMap;
use std::fmt::Debug;

/// Strategy error types
#[derive(Debug, thiserror::Error)]
pub enum StrategyError {
    #[error("Environment variable not found: {0}")]
    EnvVarNotFound(String),

    #[error("Invalid credential format: {0}")]
    InvalidCredential(String),

    #[error("Injection failed: {0}")]
    InjectionFailed(String),
}

/// Authentication strategy trait
///
/// Each strategy implements a specific authentication protocol:
/// - Bearer tokens (OpenAI, Anthropic, GitHub, etc.)
/// - AWS Signature Version 4
/// - HMAC signing
/// - Custom protocols
pub trait AuthStrategy: Send + Sync + Debug {
    /// Strategy name for identification and logging
    fn name(&self) -> &str;

    /// Strategy type (bearer, aws_sigv4, hmac, etc.)
    fn strategy_type(&self) -> &str;

    /// Detect if this strategy should handle the request
    ///
    /// Checks for dummy credentials in headers, body, or query parameters
    fn detect(&self, headers: &HeaderMap, body: &str) -> bool;

    /// Inject real credentials into the request
    ///
    /// Replaces dummy credentials with real ones from environment
    /// Returns the modified body and any header modifications
    fn inject(&self, body: &str, headers: &mut HeaderMap) -> Result<String, StrategyError>;

    /// Validate destination host is whitelisted
    ///
    /// Prevents credential exfiltration to unauthorized hosts
    fn validate_host(&self, host: &str) -> bool;

    /// Get dummy patterns for detection
    ///
    /// Returns patterns that trigger this strategy
    fn dummy_patterns(&self) -> Vec<String>;

    /// Get real credential value (for sanitization)
    ///
    /// Returns the actual credential that should be sanitized from responses
    fn real_credential(&self) -> Option<String>;
}

/// Bearer token strategy
///
/// Handles simple Bearer token authentication used by most REST APIs
#[derive(Debug, Clone)]
pub struct BearerStrategy {
    name: String,
    env_var: String,
    dummy_pattern: String,
    allowed_hosts: Vec<String>,
    real_token: Option<String>,
}

impl BearerStrategy {
    /// Create a new Bearer strategy
    pub fn new(
        name: String,
        env_var: String,
        dummy_pattern: String,
        allowed_hosts: Vec<String>,
    ) -> Result<Self, StrategyError> {
        // Load real token from environment
        let real_token = std::env::var(&env_var).ok();

        if real_token.is_none() {
            tracing::warn!(
                "Bearer strategy '{}': Environment variable '{}' not set",
                name,
                env_var
            );
        }

        Ok(Self {
            name,
            env_var,
            dummy_pattern,
            allowed_hosts,
            real_token,
        })
    }

    /// Check if host matches wildcard pattern
    fn matches_wildcard(pattern: &str, host: &str) -> bool {
        if pattern.starts_with("*.") {
            let base = &pattern[2..];
            host.ends_with(base) || host == base
        } else {
            pattern == host
        }
    }
}

impl AuthStrategy for BearerStrategy {
    fn name(&self) -> &str {
        &self.name
    }

    fn strategy_type(&self) -> &str {
        "bearer"
    }

    fn detect(&self, headers: &HeaderMap, body: &str) -> bool {
        // Check Authorization header
        if let Some(auth_header) = headers.get("authorization") {
            if let Ok(auth_str) = auth_header.to_str() {
                if auth_str.contains(&self.dummy_pattern) {
                    return true;
                }
            }
        }

        // Check X-API-Key header (some APIs use this)
        if let Some(api_key) = headers.get("x-api-key") {
            if let Ok(key_str) = api_key.to_str() {
                if key_str.contains(&self.dummy_pattern) {
                    return true;
                }
            }
        }

        // Check request body
        body.contains(&self.dummy_pattern)
    }

    fn inject(&self, body: &str, headers: &mut HeaderMap) -> Result<String, StrategyError> {
        let real_token = self
            .real_token
            .as_ref()
            .ok_or_else(|| StrategyError::EnvVarNotFound(self.env_var.clone()))?;

        // Replace dummy token in body
        let injected_body = body.replace(&self.dummy_pattern, real_token);

        // Also update Authorization header if present
        if let Some(auth_header) = headers.get_mut("authorization") {
            if let Ok(auth_str) = auth_header.to_str() {
                if auth_str.contains(&self.dummy_pattern) {
                    let new_auth = auth_str.replace(&self.dummy_pattern, real_token);
                    *auth_header = new_auth.parse().map_err(|e| {
                        StrategyError::InjectionFailed(format!("Failed to parse header: {}", e))
                    })?;
                }
            }
        }

        // Update X-API-Key header if present
        if let Some(api_key) = headers.get_mut("x-api-key") {
            if let Ok(key_str) = api_key.to_str() {
                if key_str.contains(&self.dummy_pattern) {
                    let new_key = key_str.replace(&self.dummy_pattern, real_token);
                    *api_key = new_key.parse().map_err(|e| {
                        StrategyError::InjectionFailed(format!("Failed to parse header: {}", e))
                    })?;
                }
            }
        }

        tracing::debug!(
            "Bearer strategy '{}': Injected credential (body: {} bytes)",
            self.name,
            injected_body.len()
        );

        Ok(injected_body)
    }

    fn validate_host(&self, host: &str) -> bool {
        if self.allowed_hosts.is_empty() {
            // If no whitelist specified, allow all (backward compatible)
            tracing::warn!(
                "Bearer strategy '{}': No host whitelist configured (allowing all hosts)",
                self.name
            );
            return true;
        }

        for pattern in &self.allowed_hosts {
            if Self::matches_wildcard(pattern, host) {
                return true;
            }
        }

        tracing::warn!(
            "Bearer strategy '{}': Host '{}' not in whitelist: {:?}",
            self.name,
            host,
            self.allowed_hosts
        );
        false
    }

    fn dummy_patterns(&self) -> Vec<String> {
        vec![self.dummy_pattern.clone()]
    }

    fn real_credential(&self) -> Option<String> {
        self.real_token.clone()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::http::HeaderValue;

    #[test]
    fn test_bearer_strategy_detect_in_header() {
        let strategy = BearerStrategy::new(
            "test".to_string(),
            "TEST_TOKEN".to_string(),
            "DUMMY_TEST".to_string(),
            vec![],
        )
        .unwrap();

        let mut headers = HeaderMap::new();
        headers.insert(
            "authorization",
            HeaderValue::from_static("Bearer DUMMY_TEST"),
        );

        assert!(strategy.detect(&headers, ""));
    }

    #[test]
    fn test_bearer_strategy_detect_in_body() {
        let strategy = BearerStrategy::new(
            "test".to_string(),
            "TEST_TOKEN".to_string(),
            "DUMMY_TEST".to_string(),
            vec![],
        )
        .unwrap();

        let headers = HeaderMap::new();
        let body = r#"{"api_key": "DUMMY_TEST"}"#;

        assert!(strategy.detect(&headers, body));
    }

    #[test]
    fn test_bearer_strategy_inject() {
        std::env::set_var("TEST_BEARER_TOKEN", "real_secret_123");

        let strategy = BearerStrategy::new(
            "test".to_string(),
            "TEST_BEARER_TOKEN".to_string(),
            "DUMMY_TEST".to_string(),
            vec![],
        )
        .unwrap();

        let body = r#"{"api_key": "DUMMY_TEST"}"#;
        let mut headers = HeaderMap::new();

        let result = strategy.inject(body, &mut headers).unwrap();
        assert!(result.contains("real_secret_123"));
        assert!(!result.contains("DUMMY_TEST"));
    }

    #[test]
    fn test_bearer_strategy_validate_host() {
        let strategy = BearerStrategy::new(
            "test".to_string(),
            "TEST_TOKEN".to_string(),
            "DUMMY_TEST".to_string(),
            vec!["api.example.com".to_string(), "*.example.org".to_string()],
        )
        .unwrap();

        assert!(strategy.validate_host("api.example.com"));
        assert!(strategy.validate_host("api.example.org"));
        assert!(strategy.validate_host("sub.example.org"));
        assert!(!strategy.validate_host("evil.com"));
    }

    #[test]
    fn test_bearer_strategy_wildcard_matching() {
        assert!(BearerStrategy::matches_wildcard(
            "*.example.com",
            "api.example.com"
        ));
        assert!(BearerStrategy::matches_wildcard(
            "*.example.com",
            "example.com"
        ));
        assert!(!BearerStrategy::matches_wildcard(
            "*.example.com",
            "evil.com"
        ));
        assert!(BearerStrategy::matches_wildcard(
            "api.example.com",
            "api.example.com"
        ));
        assert!(!BearerStrategy::matches_wildcard(
            "api.example.com",
            "other.example.com"
        ));
    }

    #[test]
    fn test_bearer_strategy_no_token() {
        std::env::remove_var("NONEXISTENT_TOKEN");

        let strategy = BearerStrategy::new(
            "test".to_string(),
            "NONEXISTENT_TOKEN".to_string(),
            "DUMMY_TEST".to_string(),
            vec![],
        )
        .unwrap();

        let body = "test";
        let mut headers = HeaderMap::new();

        let result = strategy.inject(body, &mut headers);
        assert!(result.is_err());
    }
}
