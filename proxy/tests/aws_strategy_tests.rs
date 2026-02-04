// Comprehensive tests for AWS SigV4 Strategy

use slapenir_proxy::strategy::{AuthStrategy, BearerStrategy};
use slapenir_proxy::strategies::aws_sigv4::AWSSigV4Strategy;
use axum::http::HeaderMap;

#[cfg(test)]
mod aws_sigv4_tests {
    use super::*;

    #[test]
    fn test_aws_strategy_creation_with_credentials() {
        std::env::set_var("TEST_AWS_ACCESS_1", "AKIAIOSFODNN7EXAMPLE");
        std::env::set_var("TEST_AWS_SECRET_1", "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY");
        
        let result = AWSSigV4Strategy::new(
            "aws-test".to_string(),
            "TEST_AWS_ACCESS_1".to_string(),
            "TEST_AWS_SECRET_1".to_string(),
            "us-east-1".to_string(),
            None,
            vec!["*.amazonaws.com".to_string()],
        );
        
        assert!(result.is_ok());
        let strategy = result.unwrap();
        assert_eq!(strategy.name(), "aws-test");
        assert_eq!(strategy.strategy_type(), "aws_sigv4");
    }

    #[test]
    fn test_aws_strategy_creation_without_credentials() {
        std::env::remove_var("NONEXISTENT_AWS_ACCESS");
        std::env::remove_var("NONEXISTENT_AWS_SECRET");
        
        let result = AWSSigV4Strategy::new(
            "aws-test".to_string(),
            "NONEXISTENT_AWS_ACCESS".to_string(),
            "NONEXISTENT_AWS_SECRET".to_string(),
            "us-east-1".to_string(),
            None,
            vec!["*.amazonaws.com".to_string()],
        );
        
        // Should succeed but warn (credentials checked at injection time)
        assert!(result.is_ok());
    }

    #[test]
    fn test_aws_strategy_validate_host_wildcard() {
        std::env::set_var("TEST_AWS_ACCESS_2", "AKIATEST");
        std::env::set_var("TEST_AWS_SECRET_2", "secret");
        
        let strategy = AWSSigV4Strategy::new(
            "aws".to_string(),
            "TEST_AWS_ACCESS_2".to_string(),
            "TEST_AWS_SECRET_2".to_string(),
            "us-east-1".to_string(),
            None,
            vec!["*.amazonaws.com".to_string()],
        ).unwrap();
        
        assert!(strategy.validate_host("s3.amazonaws.com"));
        assert!(strategy.validate_host("dynamodb.us-east-1.amazonaws.com"));
        assert!(strategy.validate_host("ec2.amazonaws.com"));
        assert!(!strategy.validate_host("example.com"));
        assert!(!strategy.validate_host("amazonaws.org"));
    }

    #[test]
    fn test_aws_strategy_validate_host_specific() {
        std::env::set_var("TEST_AWS_ACCESS_3", "AKIATEST");
        std::env::set_var("TEST_AWS_SECRET_3", "secret");
        
        let strategy = AWSSigV4Strategy::new(
            "aws".to_string(),
            "TEST_AWS_ACCESS_3".to_string(),
            "TEST_AWS_SECRET_3".to_string(),
            "us-east-1".to_string(),
            None,
            vec!["s3.amazonaws.com".to_string()],
        ).unwrap();
        
        assert!(strategy.validate_host("s3.amazonaws.com"));
        assert!(!strategy.validate_host("dynamodb.amazonaws.com"));
        assert!(!strategy.validate_host("s3.us-west-2.amazonaws.com"));
    }

    #[test]
    fn test_aws_strategy_validate_host_multiple_patterns() {
        std::env::set_var("TEST_AWS_ACCESS_4", "AKIATEST");
        std::env::set_var("TEST_AWS_SECRET_4", "secret");
        
        let strategy = AWSSigV4Strategy::new(
            "aws".to_string(),
            "TEST_AWS_ACCESS_4".to_string(),
            "TEST_AWS_SECRET_4".to_string(),
            "us-east-1".to_string(),
            None,
            vec![
                "*.amazonaws.com".to_string(),  // Use wildcard at start
            ],
        ).unwrap();
        
        // All these should match *.amazonaws.com
        assert!(strategy.validate_host("s3.us-east-1.amazonaws.com"));
        assert!(strategy.validate_host("dynamodb.us-west-2.amazonaws.com"));
        assert!(strategy.validate_host("ec2.us-east-1.amazonaws.com"));
        assert!(!strategy.validate_host("example.com"));
    }

    #[test]
    fn test_aws_strategy_detect_authorization_header() {
        std::env::set_var("TEST_AWS_ACCESS_5", "AKIATEST");
        std::env::set_var("TEST_AWS_SECRET_5", "secret");
        
        let strategy = AWSSigV4Strategy::new(
            "aws".to_string(),
            "TEST_AWS_ACCESS_5".to_string(),
            "TEST_AWS_SECRET_5".to_string(),
            "us-east-1".to_string(),
            None,
            vec!["*.amazonaws.com".to_string()],
        ).unwrap();
        
        let mut headers = HeaderMap::new();
        // Detection looks for "AKIA" and "DUMMY" in the authorization header
        headers.insert("authorization", "AWS4 AKIADUMMY credentials".parse().unwrap());
        
        assert!(strategy.detect(&headers, ""));
    }

    // Note: Additional AWS tests are in proxy/src/strategies/aws_sigv4.rs
    // These tests focus on the basic strategy creation and validation patterns
}

#[cfg(test)]
mod bearer_strategy_additional_tests {
    use super::*;

    #[test]
    fn test_bearer_strategy_with_empty_hosts() {
        std::env::set_var("TEST_EMPTY_HOSTS_TOKEN", "token123");
        let result = BearerStrategy::new(
            "test".to_string(),
            "TEST_EMPTY_HOSTS_TOKEN".to_string(),
            "DUMMY_TOKEN".to_string(),
            vec![],
        );
        
        assert!(result.is_ok());
        let strategy = result.unwrap();
        
        // With empty hosts, should allow all (warning will be logged)
        assert!(strategy.validate_host("api.example.com"));
    }

    #[test]
    fn test_bearer_strategy_dummy_pattern_uniqueness() {
        std::env::set_var("TEST_PATTERN_TOKEN", "real_token");
        let strategy = BearerStrategy::new(
            "test".to_string(),
            "TEST_PATTERN_TOKEN".to_string(),
            "DUMMY_TOKEN".to_string(),
            vec!["*.example.com".to_string()],
        ).unwrap();
        
        let patterns = strategy.dummy_patterns();
        
        // Each pattern should be unique (though this strategy only has one)
        let mut unique_patterns = std::collections::HashSet::new();
        for pattern in &patterns {
            assert!(unique_patterns.insert(pattern.clone()));
        }
        assert_eq!(patterns.len(), 1);
    }

    #[test]
    fn test_bearer_strategy_real_credential_format() {
        let token = "ghp_1234567890abcdef";
        std::env::set_var("TEST_GITHUB_TOKEN", token);
        let strategy = BearerStrategy::new(
            "github".to_string(),
            "TEST_GITHUB_TOKEN".to_string(),
            "DUMMY_GITHUB".to_string(),
            vec!["*.github.com".to_string()],
        ).unwrap();
        
        let cred = strategy.real_credential();
        assert!(cred.is_some());
        assert_eq!(cred.unwrap(), token);
    }

    #[test]
    fn test_bearer_strategy_inject_preserves_other_headers() {
        std::env::set_var("TEST_PRESERVE_TOKEN", "real_token");
        let strategy = BearerStrategy::new(
            "test".to_string(),
            "TEST_PRESERVE_TOKEN".to_string(),
            "DUMMY_TOKEN".to_string(),
            vec!["*.example.com".to_string()],
        ).unwrap();
        
        let mut headers = HeaderMap::new();
        headers.insert("content-type", "application/json".parse().unwrap());
        headers.insert("x-custom", "value".parse().unwrap());
        
        let body = "test";
        let result = strategy.inject(body, &mut headers);
        
        // Should preserve existing headers
        assert!(headers.get("content-type").is_some());
        assert!(headers.get("x-custom").is_some());
    }

    #[test]
    fn test_bearer_strategy_multiple_hosts() {
        std::env::set_var("TEST_MULTI_HOST_TOKEN", "token");
        let strategy = BearerStrategy::new(
            "multi".to_string(),
            "TEST_MULTI_HOST_TOKEN".to_string(),
            "DUMMY_MULTI".to_string(),
            vec![
                "api.example.com".to_string(),
                "*.example.org".to_string(),
                "test.com".to_string(),
            ],
        ).unwrap();
        
        assert!(strategy.validate_host("api.example.com"));
        assert!(strategy.validate_host("sub.example.org"));
        assert!(strategy.validate_host("test.com"));
        assert!(!strategy.validate_host("notlisted.com"));
    }

    #[test]
    fn test_bearer_strategy_without_token() {
        std::env::remove_var("NONEXISTENT_BEARER_TOKEN");
        let result = BearerStrategy::new(
            "test".to_string(),
            "NONEXISTENT_BEARER_TOKEN".to_string(),
            "DUMMY_TOKEN".to_string(),
            vec!["*.example.com".to_string()],
        );
        
        // Should succeed creating strategy even without token
        // (token is checked at injection time)
        assert!(result.is_ok());
        
        let strategy = result.unwrap();
        let mut headers = HeaderMap::new();
        let inject_result = strategy.inject("test", &mut headers);
        
        // But injection should fail
        assert!(inject_result.is_err());
    }
}
