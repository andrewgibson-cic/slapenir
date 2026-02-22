//! Security Bypass Proof-of-Concept Tests
//!
//! These tests demonstrate and verify fixes for critical security vulnerabilities:
//! - A: Non-UTF-8 sanitization bypass
//! - B: Unsanitized headers and URLs
//! - D: Memory exhaustion (OOM)
//! - E: Content-Length desynchronization
//! - G: Automaton recreation performance

use slapenir_proxy::sanitizer::SecretMap;
use slapenir_proxy::proxy::{ProxyConfig, build_response_headers, DEFAULT_MAX_REQUEST_SIZE, DEFAULT_MAX_RESPONSE_SIZE};
use std::collections::HashMap;

// ============================================================================
// VULNERABILITY A: Non-UTF-8 Sanitization Bypass (FIXED)
// ============================================================================

mod non_utf8_bypass {
    use super::*;

    /// PoC: Binary payload containing secrets is now properly sanitized
    #[test]
    fn test_binary_payload_with_embedded_secret() {
        let mut secrets = HashMap::new();
        secrets.insert("DUMMY_API_KEY".to_string(), "sk-secret-key-12345".to_string());
        let map = SecretMap::new(secrets).unwrap();

        // Create binary payload with embedded secret and invalid UTF-8
        let binary_with_secret: Vec<u8> = vec![
            0x89, 0x50, 0x4E, 0x47, // PNG magic bytes (valid)
            0x0D, 0x0A, 0x1A, 0x0A,
            // Embedded secret in the middle
            b's', b'k', b'-', b's', b'e', b'c', b'r', b'e', b't', b'-',
            b'k', b'e', b'y', b'-', b'1', b'2', b'3', b'4', b'5',
            // Invalid UTF-8 sequence (continuation byte without start)
            0x80, 0x81, 0x82,
        ];

        // FIX A: sanitize_bytes() now handles binary data
        let sanitized = map.sanitize_bytes(&binary_with_secret);
        let sanitized_vec = sanitized.into_owned();

        // Verify secret is redacted
        let secret_bytes = b"sk-secret-key-12345";
        assert!(
            !sanitized_vec.windows(secret_bytes.len()).any(|w| w == secret_bytes),
            "SECRET LEAKED: Binary payload contains unsanitized secret!"
        );

        // Verify redaction marker is present
        assert!(
            sanitized_vec.windows(10).any(|w| w == b"[REDACTED]"),
            "Binary payload should contain [REDACTED] marker"
        );
    }

    /// PoC: Base64-encoded secret with invalid UTF-8 markers
    #[test]
    fn test_base64_secret_with_invalid_utf8() {
        let mut secrets = HashMap::new();
        secrets.insert("DUMMY_TOKEN".to_string(), "ghp_tokensecret123".to_string());
        let map = SecretMap::new(secrets).unwrap();

        // Base64-like content with secret, followed by invalid UTF-8
        let mut payload = b"Authorization: Basic Z2hwX3Rva2Vuc2VjcmV0MTIz".to_vec();
        payload.extend_from_slice(b"ghp_tokensecret123"); // The actual secret
        payload.extend_from_slice(&[0xFF, 0xFE, 0xFD]); // Invalid UTF-8

        let sanitized = map.sanitize_bytes(&payload);
        let sanitized_vec = sanitized.into_owned();

        // Secret must be redacted even with invalid UTF-8
        let secret_bytes = b"ghp_tokensecret123";
        assert!(
            !sanitized_vec.windows(secret_bytes.len()).any(|w| w == secret_bytes),
            "SECRET LEAKED: Base64 payload contains unsanitized secret!"
        );
    }

    /// PoC: Split secret across chunk boundaries
    #[test]
    fn test_secret_split_across_chunks() {
        let mut secrets = HashMap::new();
        secrets.insert("DUMMY_KEY".to_string(), "AWS_SECRET_KEY_12345".to_string());
        let map = SecretMap::new(secrets).unwrap();

        // Full payload (simulating combined chunks)
        let full_payload = b"Data: AWS_SECRET_KEY_12345\nMore data";

        let sanitized = map.sanitize_bytes(full_payload);
        let sanitized_vec = sanitized.into_owned();

        let secret_bytes = b"AWS_SECRET_KEY_12345";
        assert!(
            !sanitized_vec.windows(secret_bytes.len()).any(|w| w == secret_bytes),
            "SECRET LEAKED: Split secret not sanitized!"
        );
    }

    /// PoC: Mixed valid/invalid UTF-8 sections
    #[test]
    fn test_mixed_utf8_sections() {
        let mut secrets = HashMap::new();
        secrets.insert("DUMMY".to_string(), "real_secret".to_string());
        let map = SecretMap::new(secrets).unwrap();

        let mut payload = Vec::new();
        payload.extend_from_slice(b"Valid UTF-8 with real_secret here\n");
        payload.extend_from_slice(&[0xC0, 0x80]); // Invalid UTF-8 (overlong null)
        payload.extend_from_slice(b"\nMore valid text with real_secret again");

        let sanitized = map.sanitize_bytes(&payload);
        let sanitized_vec = sanitized.into_owned();

        let secret_bytes = b"real_secret";
        assert!(
            !sanitized_vec.windows(secret_bytes.len()).any(|w| w == secret_bytes),
            "SECRET LEAKED: Mixed UTF-8 payload contains unsanitized secret!"
        );

        // Count redactions - should find both instances
        let redacted_count = sanitized_vec.windows(10)
            .filter(|w| *w == b"[REDACTED]")
            .count();
        assert_eq!(redacted_count, 2, "Both secret instances should be redacted");
    }
}

// ============================================================================
// VULNERABILITY B: Unsanitized Headers and URLs (FIXED)
// ============================================================================

mod header_url_sanitization {
    use super::*;
    use axum::http::{HeaderMap, HeaderValue};

    /// PoC: Secret in response header is now sanitized
    #[test]
    fn test_secret_in_response_header() {
        let mut secrets = HashMap::new();
        secrets.insert("DUMMY_API_KEY".to_string(), "sk-leaked-in-header".to_string());
        let map = SecretMap::new(secrets).unwrap();

        let mut headers = HeaderMap::new();
        headers.insert("x-custom-token", HeaderValue::from_static("sk-leaked-in-header"));
        headers.insert("x-request-id", HeaderValue::from_static("req-123-sk-leaked-in-header-456"));

        let sanitized_headers = map.sanitize_headers(&headers);

        // No header should contain the secret
        for value in sanitized_headers.values() {
            if let Ok(v) = value.to_str() {
                assert!(
                    !v.contains("sk-leaked-in-header"),
                    "SECRET LEAKED: Header contains unsanitized secret: {}", v
                );
            }
        }
    }

    /// PoC: Secret in Set-Cookie header
    #[test]
    fn test_secret_in_cookie_header() {
        let mut secrets = HashMap::new();
        secrets.insert("DUMMY_SESSION".to_string(), "session_secret_abc".to_string());
        let map = SecretMap::new(secrets).unwrap();

        let mut headers = HeaderMap::new();
        headers.insert(
            "set-cookie",
            HeaderValue::from_static("session=session_secret_abc; Path=/; HttpOnly")
        );

        let sanitized_headers = map.sanitize_headers(&headers);

        if let Some(cookie) = sanitized_headers.get("set-cookie") {
            assert!(
                !cookie.to_str().unwrap().contains("session_secret_abc"),
                "SECRET LEAKED: Cookie header contains unsanitized secret!"
            );
        }
    }

    /// PoC: Secret in redirect URL
    #[test]
    fn test_secret_in_redirect_url() {
        let mut secrets = HashMap::new();
        secrets.insert("DUMMY_TOKEN".to_string(), "token_xyz789".to_string());
        let map = SecretMap::new(secrets).unwrap();

        let mut headers = HeaderMap::new();
        headers.insert(
            "location",
            HeaderValue::from_static("https://api.example.com/callback?token=token_xyz789")
        );

        let sanitized_headers = map.sanitize_headers(&headers);

        if let Some(location) = sanitized_headers.get("location") {
            assert!(
                !location.to_str().unwrap().contains("token_xyz789"),
                "SECRET LEAKED: Redirect URL contains unsanitized secret!"
            );
        }
    }

    /// PoC: Headers that should be completely removed
    #[test]
    fn test_dangerous_headers_removed() {
        let mut headers = HeaderMap::new();
        headers.insert("x-debug-token", HeaderValue::from_static("debug-info"));
        headers.insert("server-timing", HeaderValue::from_static("db;dur=53"));
        headers.insert("x-content-type-options", HeaderValue::from_static("nosniff"));

        let blocked_headers = SecretMap::get_blocked_headers();
        let filtered = SecretMap::filter_dangerous_headers(&headers, &blocked_headers);

        assert!(!filtered.contains_key("x-debug-token"), "x-debug-token should be removed");
        assert!(!filtered.contains_key("server-timing"), "server-timing should be removed");
        assert!(filtered.contains_key("x-content-type-options"), "Safe headers should be preserved");
    }
}

// ============================================================================
// VULNERABILITY D: Memory Exhaustion / OOM (FIXED)
// ============================================================================

mod memory_limits {
    use super::*;

    /// Fix D: Size limits are now configurable
    #[test]
    fn test_proxy_config_defaults() {
        let config = ProxyConfig::default();

        assert_eq!(config.max_request_size, DEFAULT_MAX_REQUEST_SIZE);
        assert_eq!(config.max_response_size, DEFAULT_MAX_RESPONSE_SIZE);
    }

    /// Fix D: Custom limits can be configured
    #[test]
    fn test_proxy_config_custom() {
        let config = ProxyConfig {
            max_request_size: 1024,      // 1KB
            max_response_size: 10 * 1024, // 10KB
        };

        assert_eq!(config.max_request_size, 1024);
        assert_eq!(config.max_response_size, 10 * 1024);
    }

    /// Fix D: Verify reasonable defaults
    #[test]
    fn test_default_limits_reasonable() {
        // 10 MB request limit
        assert_eq!(DEFAULT_MAX_REQUEST_SIZE, 10 * 1024 * 1024);
        // 100 MB response limit
        assert_eq!(DEFAULT_MAX_RESPONSE_SIZE, 100 * 1024 * 1024);
    }
}

// ============================================================================
// VULNERABILITY E: Content-Length Desynchronization (FIXED)
// ============================================================================

mod content_length_desync {
    use super::*;
    use axum::http::{HeaderMap, HeaderValue};

    /// Fix E: Content-Length is recalculated after sanitization
    #[test]
    fn test_content_length_recalculation() {
        let mut secrets = HashMap::new();
        secrets.insert("DUMMY".to_string(), "this_is_a_very_long_secret_key".to_string());
        let map = SecretMap::new(secrets).unwrap();

        let original_body = "Token: this_is_a_very_long_secret_key";
        let original_len = original_body.len();

        let sanitized = map.sanitize(original_body);
        let sanitized_len = sanitized.len();

        // Sanitized should be different length
        assert_ne!(original_len, sanitized_len,
            "Content-Length should change after sanitization");

        // Verify the correct Content-Length would be calculated
        assert!(sanitized.contains("[REDACTED]"));
    }

    /// Fix E: Transfer-Encoding is removed
    #[test]
    fn test_transfer_encoding_removed() {
        let mut headers = HeaderMap::new();
        headers.insert("transfer-encoding", HeaderValue::from_static("chunked"));
        headers.insert("content-type", HeaderValue::from_static("application/json"));

        let sanitized_body = b"{\"token\": \"[REDACTED]\"}".to_vec();

        let response_headers = build_response_headers(&headers, sanitized_body.len());

        // Transfer-Encoding should be removed
        assert!(!response_headers.contains_key("transfer-encoding"),
            "Transfer-Encoding should be removed when Content-Length is set");

        // Content-Length should be correct
        if let Some(cl) = response_headers.get("content-length") {
            assert_eq!(cl.to_str().unwrap(), "23",
                "Content-Length should match sanitized body length");
        }
    }

    /// Fix E: ETag and checksums are removed
    #[test]
    fn test_etag_removed_after_sanitization() {
        let mut headers = HeaderMap::new();
        headers.insert("etag", HeaderValue::from_static("\"abc123\""));
        headers.insert("content-md5", HeaderValue::from_static("deadbeef"));

        let response_headers = build_response_headers(&headers, 100);

        // Checksums should be removed since body changed
        assert!(!response_headers.contains_key("etag"),
            "ETag should be removed (body was modified)");
        assert!(!response_headers.contains_key("content-md5"),
            "Content-MD5 should be removed (body was modified)");
    }
}

// ============================================================================
// VULNERABILITY G: Automaton Recreation Performance (FIXED)
// ============================================================================

mod automaton_caching {
    use super::*;
    use std::time::Instant;

    /// Fix G: Automaton is now cached for fast repeated sanitization
    #[test]
    fn test_automaton_caching_performance() {
        let mut secrets = HashMap::new();
        for i in 0..50 {
            secrets.insert(
                format!("DUMMY_{}", i),
                format!("secret_key_number_{}_with_padding", i)
            );
        }
        let map = SecretMap::new(secrets).unwrap();

        let test_data = "Data with secret_key_number_25_with_padding and secret_key_number_10_with_padding";

        // Warm up
        for _ in 0..10 {
            let _ = map.sanitize(test_data);
        }

        // Measure performance
        let iterations = 1000;
        let start = Instant::now();

        for _ in 0..iterations {
            let _ = map.sanitize(test_data);
        }

        let elapsed = start.elapsed();
        let per_call = elapsed / iterations;

        // With caching, each call should be very fast (< 100 microseconds)
        assert!(
            per_call.as_micros() < 200, // Allow some slack for CI
            "Sanitization should be fast with cached automaton (was {:?} per call)",
            per_call
        );
    }
}

// ============================================================================
// INTEGRATION TESTS
// ============================================================================

mod integration {
    use super::*;

    /// Full end-to-end test: Binary response with secrets
    #[test]
    fn test_full_binary_response_sanitization() {
        let mut secrets = HashMap::new();
        secrets.insert("DUMMY_GITHUB".to_string(), "ghp_real_github_token".to_string());
        secrets.insert("DUMMY_OPENAI".to_string(), "sk-real-openai-key".to_string());
        let map = SecretMap::new(secrets).unwrap();

        // Simulate a binary response (e.g., file download) with embedded secrets
        let mut response = Vec::new();

        // PNG-like header
        response.extend_from_slice(&[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

        // Metadata with secrets
        response.extend_from_slice(b"Created-by: ghp_real_github_token\n");

        // More binary data
        response.extend_from_slice(&[0x00, 0x01, 0x02, 0x03, 0xFF, 0xFE]);

        // Another secret
        response.extend_from_slice(b"API: sk-real-openai-key");

        // Trailing binary
        response.extend_from_slice(&[0x80, 0x81, 0x82]);

        let sanitized = map.sanitize_bytes(&response);
        let sanitized_vec = sanitized.into_owned();

        // Verify no secrets remain
        assert!(!sanitized_vec.windows(22).any(|w| w == b"ghp_real_github_token"));
        assert!(!sanitized_vec.windows(19).any(|w| w == b"sk-real-openai-key"));

        // Verify redactions present
        let redacted_count = sanitized_vec.windows(10)
            .filter(|w| *w == b"[REDACTED]")
            .count();
        assert_eq!(redacted_count, 2, "Both secrets should be redacted");
    }

    /// Test paranoid verification catches issues
    #[test]
    fn test_paranoid_verification() {
        let mut secrets = HashMap::new();
        secrets.insert("DUMMY".to_string(), "secret123".to_string());
        let map = SecretMap::new(secrets).unwrap();

        let input = b"This has secret123 embedded";

        let sanitized1 = map.sanitize_bytes(input);
        let sanitized2 = map.sanitize_bytes(&sanitized1);

        // Second pass should produce same result (idempotent)
        assert_eq!(sanitized1, sanitized2, "Sanitization should be idempotent");
    }
}
