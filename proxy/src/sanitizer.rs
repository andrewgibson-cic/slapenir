// SLAPENIR Sanitizer - Zero-Knowledge Credential Sanitization
// Uses Aho-Corasick for efficient streaming pattern matching
//
// SECURITY FIXES:
// - A: Non-UTF-8 bypass via sanitize_bytes()
// - B: Header sanitization via sanitize_headers()
// - G: Cached automaton for performance

use crate::metrics;
use crate::strategy::AuthStrategy;
use aho_corasick::{AhoCorasick, AhoCorasickBuilder};
use axum::http::{HeaderMap, HeaderValue};
use std::borrow::Cow;
use std::collections::HashMap;
use zeroize::{Zeroize, ZeroizeOnDrop};

/// Headers that should be completely removed from responses (security risk)
const BLOCKED_HEADERS: &[&str] = &[
    "x-debug-token",
    "x-debug-info",
    "server-timing",
    "x-runtime",
    "x-request-debug",
];

/// Secure secret mapping that zeros memory on drop
#[derive(Clone, Zeroize, ZeroizeOnDrop)]
pub struct SecretMap {
    /// Automaton for dummy -> real injection
    #[zeroize(skip)]
    patterns: AhoCorasick,
    /// CACHED automaton for real -> [REDACTED] sanitization (Fix G)
    #[zeroize(skip)]
    sanitize_patterns: AhoCorasick,
    /// Real secrets (will be zeroized on drop)
    real_secrets: Vec<String>,
    /// Dummy placeholders
    dummy_secrets: Vec<String>,
    /// Byte representations of real secrets for binary sanitization
    #[zeroize(skip)]
    real_secrets_bytes: Vec<Vec<u8>>,
}

impl SecretMap {
    /// Create a new SecretMap from dummy -> real mappings
    pub fn new(secrets: HashMap<String, String>) -> Result<Self, String> {
        if secrets.is_empty() {
            return Err("Secret map cannot be empty".to_string());
        }

        let dummy_secrets: Vec<String> = secrets.keys().cloned().collect();
        let real_secrets: Vec<String> = secrets.values().cloned().collect();

        // Build Aho-Corasick automaton for injection (dummy -> real)
        let patterns = AhoCorasickBuilder::new()
            .ascii_case_insensitive(false)
            .build(&dummy_secrets)
            .map_err(|e| format!("Failed to build pattern matcher: {}", e))?;

        // SECURITY FIX G: Build sanitize automaton ONCE, cache it
        let sanitize_patterns = AhoCorasickBuilder::new()
            .ascii_case_insensitive(false)
            .build(&real_secrets)
            .map_err(|e| format!("Failed to build sanitize pattern matcher: {}", e))?;

        // SECURITY FIX A: Pre-compute byte representations for binary sanitization
        let real_secrets_bytes: Vec<Vec<u8>> =
            real_secrets.iter().map(|s| s.as_bytes().to_vec()).collect();

        Ok(Self {
            patterns,
            sanitize_patterns,
            real_secrets,
            dummy_secrets,
            real_secrets_bytes,
        })
    }

    /// Inject real secrets into outbound data (Agent -> Internet)
    pub fn inject(&self, data: &str) -> String {
        self.patterns.replace_all(data, &self.real_secrets)
    }

    /// Sanitize real secrets from inbound UTF-8 data (Internet -> Agent)
    ///
    /// Uses cached automaton for O(1) setup per call (Fix G)
    pub fn sanitize(&self, data: &str) -> String {
        let redacted: Vec<String> = self
            .real_secrets
            .iter()
            .map(|_| "[REDACTED]".to_string())
            .collect();

        // Count secrets being sanitized
        let matches = self.sanitize_patterns.find_iter(data).count();
        if matches > 0 {
            for _ in 0..matches {
                metrics::record_secret_sanitized("sanitization");
            }
        }

        self.sanitize_patterns.replace_all(data, &redacted)
    }

    /// SECURITY FIX A: Sanitize real secrets from binary/non-UTF-8 data
    ///
    /// This prevents the bypass where non-UTF-8 responses were returned unsanitized.
    /// Works on raw bytes, so it handles binary payloads, invalid UTF-8, etc.
    pub fn sanitize_bytes(&self, data: &[u8]) -> Cow<'_, [u8]> {
        // Build byte-based patterns for matching
        let byte_patterns = AhoCorasickBuilder::new()
            .ascii_case_insensitive(false)
            .build(&self.real_secrets_bytes)
            .expect("Failed to build byte pattern matcher");

        let redacted: Vec<&[u8]> = self
            .real_secrets_bytes
            .iter()
            .map(|_| b"[REDACTED]" as &[u8])
            .collect();

        // Count secrets being sanitized
        let matches = byte_patterns.find_iter(data).count();
        if matches > 0 {
            for _ in 0..matches {
                metrics::record_secret_sanitized("binary_sanitization");
            }
        }

        byte_patterns.replace_all_bytes(data, &redacted).into()
    }

    /// SECURITY FIX B: Sanitize secrets from HTTP headers
    ///
    /// Prevents secret leakage through response headers like:
    /// - X-Debug-Token
    /// - Set-Cookie
    /// - WWW-Authenticate
    /// - Location (redirect URLs)
    pub fn sanitize_headers(&self, headers: &HeaderMap) -> HeaderMap {
        let mut sanitized = HeaderMap::new();

        for (name, value) in headers.iter() {
            let name_str = name.as_str();

            // Skip blocked headers entirely
            if Self::is_blocked_header(name_str) {
                tracing::debug!("Removing blocked header: {}", name_str);
                continue;
            }

            // Try to sanitize the header value
            if let Ok(v) = value.to_str() {
                let sanitized_value = self.sanitize(v);
                if let Ok(hv) = HeaderValue::from_str(&sanitized_value) {
                    sanitized.insert(name.clone(), hv);
                    continue;
                }
            }

            // If sanitization fails, keep original (non-UTF-8 headers are rare)
            sanitized.insert(name.clone(), value.clone());
        }

        sanitized
    }

    /// Check if a header should be completely removed
    fn is_blocked_header(name: &str) -> bool {
        BLOCKED_HEADERS.contains(&name.to_lowercase().as_str())
    }

    /// Get the list of blocked headers for testing
    pub fn get_blocked_headers() -> Vec<&'static str> {
        BLOCKED_HEADERS.to_vec()
    }

    /// Filter dangerous headers from a HeaderMap
    pub fn filter_dangerous_headers(
        headers: &HeaderMap,
        blocked: &[&str],
    ) -> HeaderMap {
        let mut filtered = HeaderMap::new();

        for (name, value) in headers.iter() {
            let name_lower = name.as_str().to_lowercase();
            if !blocked.iter().any(|b| b.to_lowercase() == name_lower) {
                filtered.insert(name.clone(), value.clone());
            }
        }

        filtered
    }

    pub fn len(&self) -> usize {
        self.real_secrets.len()
    }

    pub fn is_empty(&self) -> bool {
        self.real_secrets.is_empty()
    }

    /// Create a new SecretMap from authentication strategies
    ///
    /// This is the preferred method when using the strategy pattern
    pub fn from_strategies(strategies: &[Box<dyn AuthStrategy>]) -> Result<Self, String> {
        if strategies.is_empty() {
            return Err("No strategies provided".to_string());
        }

        let mut dummy_secrets = Vec::new();
        let mut real_secrets = Vec::new();

        for strategy in strategies {
            // Get real credential from strategy first
            if let Some(real_cred) = strategy.real_credential() {
                // Only include dummy patterns for strategies with real credentials
                let dummies = strategy.dummy_patterns();
                dummy_secrets.extend(dummies);
                real_secrets.push(real_cred);
            } else {
                tracing::debug!(
                    "Strategy '{}' has no real credential loaded (skipping)",
                    strategy.name()
                );
            }
        }

        if dummy_secrets.is_empty() || real_secrets.is_empty() {
            return Err("No valid credentials found in strategies. Add API keys to your .env file.".to_string());
        }

        if dummy_secrets.len() != real_secrets.len() {
            return Err(format!(
                "Mismatch: {} dummy patterns but {} real credentials",
                dummy_secrets.len(),
                real_secrets.len()
            ));
        }

        // Build Aho-Corasick automaton for injection (dummy -> real)
        let patterns = AhoCorasickBuilder::new()
            .ascii_case_insensitive(false)
            .build(&dummy_secrets)
            .map_err(|e| format!("Failed to build pattern matcher: {}", e))?;

        // SECURITY FIX G: Build sanitize automaton ONCE, cache it
        let sanitize_patterns = AhoCorasickBuilder::new()
            .ascii_case_insensitive(false)
            .build(&real_secrets)
            .map_err(|e| format!("Failed to build sanitize pattern matcher: {}", e))?;

        // SECURITY FIX A: Pre-compute byte representations for binary sanitization
        let real_secrets_bytes: Vec<Vec<u8>> =
            real_secrets.iter().map(|s| s.as_bytes().to_vec()).collect();

        tracing::info!(
            "✓ Built SecretMap from {} strategies ({} patterns)",
            strategies.len(),
            dummy_secrets.len()
        );

        Ok(Self {
            patterns,
            sanitize_patterns,
            real_secrets,
            dummy_secrets,
            real_secrets_bytes,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn create_test_map() -> SecretMap {
        let mut secrets = HashMap::new();
        secrets.insert("DUMMY_GITHUB".to_string(), "ghp_realtoken123".to_string());
        secrets.insert("DUMMY_OPENAI".to_string(), "sk-realkey456".to_string());
        secrets.insert("DUMMY_AWS".to_string(), "AKIA_AWSKEY789".to_string());
        SecretMap::new(secrets).unwrap()
    }

    #[test]
    fn test_secret_map_creation() {
        let map = create_test_map();
        assert_eq!(map.len(), 3);
        assert!(!map.is_empty());
    }

    #[test]
    fn test_empty_secret_map_fails() {
        let secrets = HashMap::new();
        let result = SecretMap::new(secrets);
        assert!(result.is_err());
    }

    #[test]
    fn test_inject_single_token() {
        let map = create_test_map();
        let input = "Authorization: Bearer DUMMY_GITHUB";
        let output = map.inject(input);
        assert_eq!(output, "Authorization: Bearer ghp_realtoken123");
    }

    #[test]
    fn test_inject_multiple_tokens() {
        let map = create_test_map();
        let input = "GitHub: DUMMY_GITHUB, OpenAI: DUMMY_OPENAI";
        let output = map.inject(input);
        assert_eq!(output, "GitHub: ghp_realtoken123, OpenAI: sk-realkey456");
    }

    #[test]
    fn test_sanitize_single_secret() {
        let map = create_test_map();
        let input = "Response: {token: 'ghp_realtoken123'}";
        let output = map.sanitize(input);
        assert_eq!(output, "Response: {token: '[REDACTED]'}");
    }

    #[test]
    fn test_roundtrip() {
        let map = create_test_map();
        let original = "Request with DUMMY_GITHUB token";
        let injected = map.inject(original);
        assert_eq!(injected, "Request with ghp_realtoken123 token");
        let sanitized = map.sanitize(&injected);
        assert_eq!(sanitized, "Request with [REDACTED] token");
        assert!(!sanitized.contains("ghp_realtoken123"));
    }

    #[test]
    fn test_empty_string() {
        let map = create_test_map();
        assert_eq!(map.inject(""), "");
        assert_eq!(map.sanitize(""), "");
    }

    #[test]
    fn test_from_strategies() {
        use crate::strategy::BearerStrategy;

        // Set up test environment variables
        std::env::set_var("TEST_STRATEGY_TOKEN_1", "real_token_123");
        std::env::set_var("TEST_STRATEGY_TOKEN_2", "real_token_456");

        let strategies: Vec<Box<dyn AuthStrategy>> = vec![
            Box::new(
                BearerStrategy::new(
                    "test1".to_string(),
                    "TEST_STRATEGY_TOKEN_1".to_string(),
                    "DUMMY_TEST_1".to_string(),
                    vec![],
                )
                .unwrap(),
            ),
            Box::new(
                BearerStrategy::new(
                    "test2".to_string(),
                    "TEST_STRATEGY_TOKEN_2".to_string(),
                    "DUMMY_TEST_2".to_string(),
                    vec![],
                )
                .unwrap(),
            ),
        ];

        let map = SecretMap::from_strategies(&strategies).unwrap();
        assert_eq!(map.len(), 2);

        // Test injection
        let input = "Token1: DUMMY_TEST_1, Token2: DUMMY_TEST_2";
        let injected = map.inject(input);
        assert!(injected.contains("real_token_123"));
        assert!(injected.contains("real_token_456"));

        // Test sanitization
        let response = "Response with real_token_123 and real_token_456";
        let sanitized = map.sanitize(response);
        assert!(sanitized.contains("[REDACTED]"));
        assert!(!sanitized.contains("real_token"));
    }

    #[test]
    fn test_from_strategies_empty() {
        let strategies: Vec<Box<dyn AuthStrategy>> = vec![];
        let result = SecretMap::from_strategies(&strategies);
        assert!(result.is_err());
    }
}
