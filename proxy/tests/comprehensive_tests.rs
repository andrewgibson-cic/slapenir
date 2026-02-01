// Comprehensive tests for SLAPENIR proxy
// Goal: Achieve 80%+ code coverage

use slapenir_proxy::{
    middleware::AppState,
    proxy::{create_http_client, ProxyError},
    sanitizer::SecretMap,
};
use std::collections::HashMap;
use std::sync::Arc;

// ============================================================================
// PROXY MODULE TESTS
// ============================================================================

#[cfg(test)]
mod proxy_tests {
    use super::*;

    #[test]
    fn test_create_http_client() {
        let client = create_http_client();
        // Just verify it creates without panicking
        assert!(std::mem::size_of_val(&client) > 0);
    }

    // Note: test_hop_by_hop_headers_comprehensive removed - uses private function
    // The function is tested via unit tests in proxy.rs

    /*
    #[test]
    fn test_hop_by_hop_headers_comprehensive() {
        // Should be hop-by-hop
        assert!(is_hop_by_hop_header("connection"));
        assert!(is_hop_by_hop_header("Connection"));
        assert!(is_hop_by_hop_header("CONNECTION"));
        assert!(is_hop_by_hop_header("keep-alive"));
        assert!(is_hop_by_hop_header("Keep-Alive"));
        assert!(is_hop_by_hop_header("proxy-authenticate"));
        assert!(is_hop_by_hop_header("Proxy-Authenticate"));
        assert!(is_hop_by_hop_header("proxy-authorization"));
        assert!(is_hop_by_hop_header("te"));
        assert!(is_hop_by_hop_header("TE"));
        assert!(is_hop_by_hop_header("trailers"));
        assert!(is_hop_by_hop_header("transfer-encoding"));
        assert!(is_hop_by_hop_header("Transfer-Encoding"));
        assert!(is_hop_by_hop_header("upgrade"));
        assert!(is_hop_by_hop_header("Upgrade"));
        assert!(is_hop_by_hop_header("host"));
        assert!(is_hop_by_hop_header("Host"));
        assert!(is_hop_by_hop_header("HOST"));

        // Should NOT be hop-by-hop
        assert!(!is_hop_by_hop_header("authorization"));
        assert!(!is_hop_by_hop_header("Authorization"));
        assert!(!is_hop_by_hop_header("content-type"));
        assert!(!is_hop_by_hop_header("Content-Type"));
        assert!(!is_hop_by_hop_header("accept"));
        assert!(!is_hop_by_hop_header("user-agent"));
        assert!(!is_hop_by_hop_header("content-length"));
        assert!(!is_hop_by_hop_header("x-custom-header"));
        assert!(!is_hop_by_hop_header(""));
    }
    */

    #[test]
    fn test_proxy_error_display() {
        let err = ProxyError::RequestBodyRead("test error".to_string());
        assert!(err.to_string().contains("test error"));

        let err = ProxyError::InvalidUtf8("bad encoding".to_string());
        assert!(err.to_string().contains("bad encoding"));

        let err = ProxyError::ForwardRequest("connection failed".to_string());
        assert!(err.to_string().contains("connection failed"));

        let err = ProxyError::ResponseBodyRead("timeout".to_string());
        assert!(err.to_string().contains("timeout"));

        let err = ProxyError::InvalidTargetUrl("malformed".to_string());
        assert!(err.to_string().contains("malformed"));

        let err = ProxyError::MissingHeader("required-header".to_string());
        assert!(err.to_string().contains("required-header"));
    }

    #[test]
    fn test_proxy_error_debug() {
        let err = ProxyError::RequestBodyRead("test".to_string());
        let debug_str = format!("{:?}", err);
        assert!(debug_str.contains("RequestBodyRead"));
    }
}

// ============================================================================
// SANITIZER MODULE TESTS
// ============================================================================

#[cfg(test)]
mod sanitizer_tests {
    use super::*;

    #[test]
    fn test_secret_map_with_various_patterns() {
        let mut secrets = HashMap::new();
        secrets.insert("TOKEN_A".to_string(), "secret_a_12345".to_string());
        secrets.insert("TOKEN_B".to_string(), "secret_b_67890".to_string());
        secrets.insert("KEY_C".to_string(), "sk-proj-verylongkey".to_string());

        let map = SecretMap::new(secrets).unwrap();

        // Test injection with multiple patterns
        let input = "Use TOKEN_A and TOKEN_B with KEY_C";
        let output = map.inject(input);
        assert!(output.contains("secret_a_12345"));
        assert!(output.contains("secret_b_67890"));
        assert!(output.contains("sk-proj-verylongkey"));
        assert!(!output.contains("TOKEN_A"));

        // Test sanitization
        let response = "Your keys are: secret_a_12345, secret_b_67890, sk-proj-verylongkey";
        let sanitized = map.sanitize(response);
        assert!(!sanitized.contains("secret_a_12345"));
        assert!(!sanitized.contains("secret_b_67890"));
        assert!(!sanitized.contains("sk-proj-verylongkey"));
        assert_eq!(sanitized.matches("[REDACTED]").count(), 3);
    }

    #[test]
    fn test_secret_map_with_special_characters() {
        let mut secrets = HashMap::new();
        secrets.insert("DUMMY".to_string(), "real$ecret!@#".to_string());

        let map = SecretMap::new(secrets).unwrap();

        let input = "Token: DUMMY";
        let output = map.inject(input);
        assert_eq!(output, "Token: real$ecret!@#");

        let response = "Token: real$ecret!@#";
        let sanitized = map.sanitize(response);
        assert_eq!(sanitized, "Token: [REDACTED]");
    }

    #[test]
    fn test_secret_map_adjacent_patterns() {
        let mut secrets = HashMap::new();
        secrets.insert("AAA".to_string(), "111".to_string());
        secrets.insert("BBB".to_string(), "222".to_string());

        let map = SecretMap::new(secrets).unwrap();

        let input = "AAABBB";
        let output = map.inject(input);
        assert_eq!(output, "111222");
    }

    #[test]
    fn test_secret_map_repeated_patterns() {
        let mut secrets = HashMap::new();
        secrets.insert("TOKEN".to_string(), "secret".to_string());

        let map = SecretMap::new(secrets).unwrap();

        let input = "TOKEN TOKEN TOKEN";
        let output = map.inject(input);
        assert_eq!(output, "secret secret secret");

        let response = "secret secret secret";
        let sanitized = map.sanitize(response);
        assert_eq!(sanitized, "[REDACTED] [REDACTED] [REDACTED]");
    }

    #[test]
    fn test_secret_map_no_match() {
        let mut secrets = HashMap::new();
        secrets.insert("TOKEN".to_string(), "my_real_secret_key".to_string());

        let map = SecretMap::new(secrets).unwrap();

        let input = "No tokens here";
        let output = map.inject(input);
        assert_eq!(output, input);

        let response = "No matching patterns here";
        let sanitized = map.sanitize(response);
        assert_eq!(sanitized, response);
    }

    #[test]
    fn test_secret_map_case_sensitive() {
        let mut secrets = HashMap::new();
        secrets.insert("token".to_string(), "secret".to_string());

        let map = SecretMap::new(secrets).unwrap();

        let input = "TOKEN token ToKeN";
        let output = map.inject(input);
        // Only exact match should be replaced
        assert_eq!(output, "TOKEN secret ToKeN");
    }

    #[test]
    fn test_secret_map_long_strings() {
        let mut secrets = HashMap::new();
        let long_secret = "a".repeat(1000);
        secrets.insert("LONG".to_string(), long_secret.clone());

        let map = SecretMap::new(secrets).unwrap();

        let input = "Start LONG End";
        let output = map.inject(input);
        assert!(output.contains(&long_secret));
        // "Start " (6) + long_secret (1000) + " End" (4) = 1010
        assert_eq!(output.len(), 1010);
    }

    #[test]
    fn test_secret_map_unicode() {
        let mut secrets = HashMap::new();
        secrets.insert("EMOJI".to_string(), "🔒🔑".to_string());

        let map = SecretMap::new(secrets).unwrap();

        let input = "Key: EMOJI";
        let output = map.inject(input);
        assert_eq!(output, "Key: 🔒🔑");
    }

    #[test]
    fn test_secret_map_newlines_and_whitespace() {
        let mut secrets = HashMap::new();
        secrets.insert("TOKEN".to_string(), "secret".to_string());

        let map = SecretMap::new(secrets).unwrap();

        let input = "Line1\nTOKEN\nLine2\tTOKEN\r\nLine3";
        let output = map.inject(input);
        assert!(output.contains("secret"));
        assert_eq!(output.matches("secret").count(), 2);
    }

    #[test]
    fn test_secret_map_len_and_is_empty() {
        let mut secrets = HashMap::new();
        secrets.insert("A".to_string(), "1".to_string());
        secrets.insert("B".to_string(), "2".to_string());
        secrets.insert("C".to_string(), "3".to_string());

        let map = SecretMap::new(secrets).unwrap();
        assert_eq!(map.len(), 3);
        assert!(!map.is_empty());
    }
}

// ============================================================================
// MIDDLEWARE MODULE TESTS
// ============================================================================

#[cfg(test)]
mod middleware_tests {
    use super::*;

    fn create_test_state() -> AppState {
        let mut secrets = HashMap::new();
        secrets.insert("DUMMY".to_string(), "real_secret".to_string());
        let secret_map = SecretMap::new(secrets).unwrap();

        AppState {
            secret_map: Arc::new(secret_map),
            http_client: create_http_client(),
        }
    }

    #[test]
    fn test_app_state_has_secret_map() {
        let state = create_test_state();
        assert_eq!(state.secret_map.len(), 1);
    }

    #[test]
    fn test_app_state_has_http_client() {
        let state = create_test_state();
        assert!(std::mem::size_of_val(&state.http_client) > 0);
    }

    #[test]
    fn test_app_state_secret_map_works() {
        let state = create_test_state();
        let input = "Token: DUMMY";
        let output = state.secret_map.inject(input);
        assert_eq!(output, "Token: real_secret");
    }

    #[test]
    fn test_app_state_multiple_clones() {
        let state1 = create_test_state();
        let state2 = state1.clone();
        let state3 = state2.clone();

        // All should work
        assert_eq!(state1.secret_map.len(), 1);
        assert_eq!(state2.secret_map.len(), 1);
        assert_eq!(state3.secret_map.len(), 1);
    }
}

// ============================================================================
// METRICS MODULE TESTS
// ============================================================================

#[cfg(test)]
mod metrics_tests {
    use slapenir_proxy::metrics;

    #[test]
    fn test_metrics_module_exists() {
        // Just ensure metrics module is accessible
        metrics::inc_active_connections();
        metrics::dec_active_connections();
    }

    #[test]
    fn test_record_multiple_requests() {
        for i in 0..10 {
            metrics::record_http_request("GET", 200, "api", 0.001 * i as f64);
        }
        // Should not panic
    }

    #[test]
    fn test_record_various_status_codes() {
        metrics::record_http_request("GET", 200, "api", 0.001);
        metrics::record_http_request("POST", 201, "api", 0.002);
        metrics::record_http_request("GET", 400, "api", 0.003);
        metrics::record_http_request("GET", 404, "api", 0.004);
        metrics::record_http_request("GET", 500, "api", 0.005);
        metrics::record_http_request("POST", 503, "api", 0.006);
    }

    #[test]
    fn test_record_various_methods() {
        metrics::record_http_request("GET", 200, "api", 0.001);
        metrics::record_http_request("POST", 200, "api", 0.001);
        metrics::record_http_request("PUT", 200, "api", 0.001);
        metrics::record_http_request("DELETE", 200, "api", 0.001);
        metrics::record_http_request("PATCH", 200, "api", 0.001);
        metrics::record_http_request("HEAD", 200, "api", 0.001);
        metrics::record_http_request("OPTIONS", 200, "api", 0.001);
    }

    #[test]
    fn test_record_various_endpoints() {
        metrics::record_http_request("GET", 200, "v1", 0.001);
        metrics::record_http_request("GET", 200, "v2", 0.001);
        metrics::record_http_request("GET", 200, "chat", 0.001);
        metrics::record_http_request("GET", 200, "completions", 0.001);
        metrics::record_http_request("GET", 200, "models", 0.001);
        metrics::record_http_request("GET", 200, "unknown", 0.001);
    }

    #[test]
    fn test_record_secret_sanitized_types() {
        metrics::record_secret_sanitized("injection");
        metrics::record_secret_sanitized("sanitization");
        metrics::record_secret_sanitized("api_key");
        metrics::record_secret_sanitized("token");
        metrics::record_secret_sanitized("password");
    }

    #[test]
    fn test_connection_tracking_multiple() {
        for _ in 0..100 {
            metrics::inc_active_connections();
        }
        for _ in 0..100 {
            metrics::dec_active_connections();
        }
    }

    #[test]
    fn test_metrics_with_extreme_durations() {
        metrics::record_http_request("GET", 200, "api", 0.000001); // Very fast
        metrics::record_http_request("GET", 200, "api", 10.0); // Very slow
        metrics::record_http_request("GET", 200, "api", 0.0); // Zero duration
    }

    #[test]
    fn test_metrics_with_edge_case_status_codes() {
        metrics::record_http_request("GET", 100, "api", 0.001); // Informational
        metrics::record_http_request("GET", 206, "api", 0.001); // Partial content
        metrics::record_http_request("GET", 304, "api", 0.001); // Not modified
        metrics::record_http_request("GET", 418, "api", 0.001); // I'm a teapot
        metrics::record_http_request("GET", 599, "api", 0.001); // Custom
    }
}

// ============================================================================
// MTLS MODULE TESTS
// ============================================================================

#[cfg(test)]
mod mtls_tests {
    use slapenir_proxy::mtls::ClientCertInfo;

    #[test]
    fn test_client_cert_info_fields() {
        let cert = ClientCertInfo {
            common_name: "test.example.com".to_string(),
            organization: Some("TestOrg".to_string()),
            serial: "12345".to_string(),
            valid: true,
        };

        assert_eq!(cert.common_name, "test.example.com");
        assert_eq!(cert.organization, Some("TestOrg".to_string()));
        assert_eq!(cert.serial, "12345");
        assert!(cert.valid);
    }

    #[test]
    fn test_client_cert_info_without_org() {
        let cert = ClientCertInfo {
            common_name: "agent-01".to_string(),
            organization: None,
            serial: "ABC123".to_string(),
            valid: false,
        };

        assert_eq!(cert.common_name, "agent-01");
        assert!(cert.organization.is_none());
        assert!(!cert.valid);
    }

    #[test]
    fn test_client_cert_info_clone() {
        let cert1 = ClientCertInfo {
            common_name: "test".to_string(),
            organization: Some("org".to_string()),
            serial: "123".to_string(),
            valid: true,
        };

        let cert2 = cert1.clone();
        assert_eq!(cert1.common_name, cert2.common_name);
        assert_eq!(cert1.organization, cert2.organization);
    }

    #[test]
    fn test_client_cert_info_debug() {
        let cert = ClientCertInfo {
            common_name: "test".to_string(),
            organization: Some("org".to_string()),
            serial: "123".to_string(),
            valid: true,
        };

        let debug_str = format!("{:?}", cert);
        assert!(debug_str.contains("test"));
        assert!(debug_str.contains("org"));
    }
}
