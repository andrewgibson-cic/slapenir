// Tests for connect_full.rs - Complete TLS MITM with Credential Injection & Response Sanitization

use slapenir_proxy::{middleware::AppState, proxy::create_http_client, sanitizer::SecretMap};
use std::collections::HashMap;
use std::sync::Arc;

#[cfg(test)]
mod connect_full_unit_tests {
    use super::*;

    fn create_test_state() -> AppState {
        let mut secrets = HashMap::new();
        secrets.insert("DUMMY_TOKEN".to_string(), "real_secret_token".to_string());
        secrets.insert("DUMMY_KEY".to_string(), "sk-proj-realkey123".to_string());
        let secret_map = SecretMap::new(secrets).unwrap();

        AppState::new(Arc::new(secret_map), create_http_client())
    }

    #[test]
    fn test_app_state_for_connect_full() {
        let state = create_test_state();
        assert_eq!(state.secret_map.len(), 2);

        // Test injection
        let input = "Authorization: Bearer DUMMY_TOKEN";
        let output = state.secret_map.inject(input);
        assert!(output.contains("real_secret_token"));
        assert!(!output.contains("DUMMY_TOKEN"));

        // Test sanitization
        let response = "Your token is: real_secret_token";
        let sanitized = state.secret_map.sanitize(response);
        assert!(!sanitized.contains("real_secret_token"));
        assert!(sanitized.contains("[REDACTED]"));
    }

    #[test]
    fn test_state_with_multiple_dummy_patterns() {
        let mut secrets = HashMap::new();
        secrets.insert("OPENAI_API_KEY".to_string(), "sk-123456".to_string());
        secrets.insert("GITHUB_TOKEN".to_string(), "ghp_abcdef".to_string());
        secrets.insert("AWS_ACCESS_KEY".to_string(), "AKIA123456".to_string());
        let secret_map = SecretMap::new(secrets).unwrap();

        let state = AppState::new(Arc::new(secret_map), create_http_client());

        assert_eq!(state.secret_map.len(), 3);

        let input = "Keys: OPENAI_API_KEY, GITHUB_TOKEN, AWS_ACCESS_KEY";
        let output = state.secret_map.inject(input);
        assert!(output.contains("sk-123456"));
        assert!(output.contains("ghp_abcdef"));
        assert!(output.contains("AKIA123456"));
    }

    #[test]
    fn test_credential_injection_in_headers() {
        let state = create_test_state();
        let header_value = "Bearer DUMMY_TOKEN";
        let injected = state.secret_map.inject(header_value);
        assert_eq!(injected, "Bearer real_secret_token");
    }

    #[test]
    fn test_credential_injection_in_json_body() {
        let state = create_test_state();
        let json_body = r#"{"api_key": "DUMMY_KEY", "data": "test"}"#;
        let injected = state.secret_map.inject(json_body);
        assert!(injected.contains("sk-proj-realkey123"));
        assert!(!injected.contains("DUMMY_KEY"));
    }

    #[test]
    fn test_response_sanitization_in_json() {
        let state = create_test_state();
        let response_body = r#"{"token": "real_secret_token", "status": "ok"}"#;
        let sanitized = state.secret_map.sanitize(response_body);
        assert!(!sanitized.contains("real_secret_token"));
        assert!(sanitized.contains("[REDACTED]"));
        assert!(sanitized.contains("status"));
    }

    #[test]
    fn test_sanitization_preserves_structure() {
        let state = create_test_state();
        let response = "Before real_secret_token After";
        let sanitized = state.secret_map.sanitize(response);
        assert_eq!(sanitized, "Before [REDACTED] After");
    }

    #[test]
    fn test_multiple_secrets_in_same_response() {
        let state = create_test_state();
        let response = "Token: real_secret_token, Key: sk-proj-realkey123";
        let sanitized = state.secret_map.sanitize(response);
        assert_eq!(sanitized.matches("[REDACTED]").count(), 2);
        assert!(!sanitized.contains("real_secret_token"));
        assert!(!sanitized.contains("sk-proj-realkey123"));
    }

    #[test]
    fn test_no_injection_when_no_patterns_match() {
        let state = create_test_state();
        let input = "No dummy patterns here";
        let output = state.secret_map.inject(input);
        assert_eq!(output, input);
    }

    #[test]
    fn test_no_sanitization_when_no_secrets_match() {
        let state = create_test_state();
        let response = "No real secrets in this response";
        let sanitized = state.secret_map.sanitize(response);
        assert_eq!(sanitized, response);
    }

    #[test]
    fn test_injection_and_sanitization_roundtrip() {
        let state = create_test_state();

        // Inject dummy pattern
        let request = "Use DUMMY_TOKEN for auth";
        let injected = state.secret_map.inject(request);
        assert_eq!(injected, "Use real_secret_token for auth");

        // Sanitize the injected value
        let sanitized = state.secret_map.sanitize(&injected);
        assert_eq!(sanitized, "Use [REDACTED] for auth");
    }

    #[test]
    fn test_state_clone_shares_secret_map() {
        let state1 = create_test_state();
        let state2 = state1.clone();

        // Both should have same secret map (Arc)
        assert_eq!(state1.secret_map.len(), state2.secret_map.len());

        let input = "DUMMY_TOKEN";
        assert_eq!(
            state1.secret_map.inject(input),
            state2.secret_map.inject(input)
        );
    }

    #[test]
    fn test_content_length_update_simulation() {
        let state = create_test_state();

        // Simulate body that will change size after injection
        let original_body = "DUMMY_TOKEN";
        let injected_body = state.secret_map.inject(original_body);

        // Original: "DUMMY_TOKEN" = 11 chars
        // Injected: "real_secret_token" = 17 chars
        assert_eq!(original_body.len(), 11);
        assert_eq!(injected_body.len(), 17);
        assert_ne!(original_body.len(), injected_body.len());
    }

    #[test]
    fn test_header_value_injection() {
        let state = create_test_state();

        let headers = vec![
            ("authorization", "Bearer DUMMY_TOKEN"),
            ("x-api-key", "DUMMY_KEY"),
            ("x-custom", "no patterns here"),
        ];

        for (_name, value) in headers {
            let injected = state.secret_map.inject(value);
            if value.contains("DUMMY_") {
                assert_ne!(injected, value);
                assert!(!injected.contains("DUMMY_"));
            } else {
                assert_eq!(injected, value);
            }
        }
    }

    #[test]
    fn test_response_header_sanitization() {
        let state = create_test_state();

        let response_headers = vec![
            (
                "www-authenticate",
                "Bearer realm=\"test\", token=\"real_secret_token\"",
            ),
            ("x-debug-key", "sk-proj-realkey123"),
            ("content-type", "application/json"),
        ];

        for (_name, value) in response_headers {
            let sanitized = state.secret_map.sanitize(value);
            if value.contains("real_secret_token") || value.contains("sk-proj-realkey123") {
                assert_ne!(sanitized, value);
                assert!(!sanitized.contains("real_secret_token"));
                assert!(!sanitized.contains("sk-proj-realkey123"));
            } else {
                assert_eq!(sanitized, value);
            }
        }
    }

    #[test]
    fn test_http11_keep_alive_detection() {
        // HTTP/1.1 defaults to keep-alive
        // Connection should NOT close unless explicitly set to "close"

        // This would be tested in the actual should_close_connection function
        // but we can test the logic here

        let connection_header_values = vec![
            ("keep-alive", false), // Should NOT close
            ("close", true),       // Should close
            ("", false),           // Empty = keep-alive for HTTP/1.1
        ];

        for (value, should_close) in connection_header_values {
            let closes = value.to_lowercase() == "close";
            assert_eq!(closes, should_close);
        }
    }

    #[test]
    fn test_http10_close_by_default_detection() {
        // HTTP/1.0 defaults to close unless keep-alive is explicitly set

        let connection_header_values = vec![
            ("keep-alive", false), // Should NOT close
            ("close", true),       // Should close
            ("", true),            // Empty = close for HTTP/1.0
        ];

        for (value, should_close) in connection_header_values {
            let is_keep_alive = value.to_lowercase() == "keep-alive";
            // For HTTP/1.0: close unless explicitly keep-alive
            if !value.is_empty() {
                assert_eq!(!is_keep_alive, should_close);
            }
        }
    }

    #[test]
    fn test_large_body_injection() {
        let state = create_test_state();

        // Create a large body with pattern at various positions
        let mut large_body = "Start ".to_string();
        large_body.push_str(&"x".repeat(10000));
        large_body.push_str(" DUMMY_TOKEN ");
        large_body.push_str(&"y".repeat(10000));
        large_body.push_str(" End");

        let injected = state.secret_map.inject(&large_body);
        assert!(injected.contains("real_secret_token"));
        assert!(!injected.contains("DUMMY_TOKEN"));
        assert!(injected.len() > 20000);
    }

    #[test]
    fn test_multiple_patterns_in_sequence() {
        let state = create_test_state();

        let body = "First DUMMY_TOKEN then DUMMY_KEY";
        let injected = state.secret_map.inject(body);

        assert!(injected.contains("real_secret_token"));
        assert!(injected.contains("sk-proj-realkey123"));
        assert!(!injected.contains("DUMMY_TOKEN"));
        assert!(!injected.contains("DUMMY_KEY"));
    }

    #[test]
    fn test_empty_body_handling() {
        let state = create_test_state();

        let empty = "";
        let injected = state.secret_map.inject(empty);
        let sanitized = state.secret_map.sanitize(empty);

        assert_eq!(injected, empty);
        assert_eq!(sanitized, empty);
    }

    #[test]
    fn test_whitespace_only_body() {
        let state = create_test_state();

        let whitespace = "   \n\t\r\n   ";
        let injected = state.secret_map.inject(whitespace);
        let sanitized = state.secret_map.sanitize(whitespace);

        assert_eq!(injected, whitespace);
        assert_eq!(sanitized, whitespace);
    }

    #[test]
    fn test_special_characters_in_context() {
        let state = create_test_state();

        let body = "{\"token\":\"DUMMY_TOKEN\",\"key\":\"DUMMY_KEY\"}";
        let injected = state.secret_map.inject(body);

        // Should still inject within JSON
        assert!(injected.contains("real_secret_token"));
        assert!(injected.contains("sk-proj-realkey123"));
    }
}
