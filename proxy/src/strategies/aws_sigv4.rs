// AWS Signature Version 4 Strategy
// Implements AWS request signing for all AWS services

use crate::strategy::{AuthStrategy, StrategyError};
use axum::http::HeaderMap;
use aws_credential_types::Credentials;
use aws_sigv4::http_request::{
    sign, SignableBody, SignableRequest, SigningSettings,
};
use aws_sigv4::sign::v4;
use std::time::SystemTime;

/// AWS SigV4 authentication strategy
///
/// Handles AWS Signature Version 4 signing for all AWS services:
/// - S3, EC2, Lambda, DynamoDB, etc.
/// - All AWS regions
/// - Temporary credentials (STS)
#[derive(Debug, Clone)]
pub struct AWSSigV4Strategy {
    name: String,
    access_key: Option<String>,
    secret_key: Option<String>,
    session_token: Option<String>,
    region: String,
    service: String,
    allowed_hosts: Vec<String>,
}

impl AWSSigV4Strategy {
    /// Create a new AWS SigV4 strategy
    pub fn new(
        name: String,
        access_key_env: String,
        secret_key_env: String,
        region: String,
        service: Option<String>,
        allowed_hosts: Vec<String>,
    ) -> Result<Self, StrategyError> {
        // Load credentials from environment
        let access_key = std::env::var(&access_key_env).ok();
        let secret_key = std::env::var(&secret_key_env).ok();
        
        // Optional session token for temporary credentials
        let session_token = std::env::var(format!("{}_SESSION_TOKEN", access_key_env)).ok();
        
        if access_key.is_none() || secret_key.is_none() {
            tracing::warn!(
                "AWS SigV4 strategy '{}': Credentials not fully loaded (env vars may be missing)",
                name
            );
        }
        
        // Default service is determined from host if not specified
        let service = service.unwrap_or_else(|| "execute-api".to_string());
        
        Ok(Self {
            name,
            access_key,
            secret_key,
            session_token,
            region,
            service,
            allowed_hosts,
        })
    }
    
    /// Extract AWS service from hostname
    /// Examples:
    /// - s3.amazonaws.com -> s3
    /// - dynamodb.us-east-1.amazonaws.com -> dynamodb
    /// - lambda.eu-west-1.amazonaws.com -> lambda
    fn extract_service_from_host(host: &str) -> String {
        if let Some(first_part) = host.split('.').next() {
            // Handle special cases
            match first_part {
                "s3" | "ec2" | "lambda" | "dynamodb" | "sqs" | "sns" => {
                    return first_part.to_string();
                }
                _ => {}
            }
            
            // For other services, return the first part
            first_part.to_string()
        } else {
            "execute-api".to_string()
        }
    }
    
    /// Extract region from hostname if present
    /// Examples:
    /// - dynamodb.us-east-1.amazonaws.com -> Some("us-east-1")
    /// - s3.amazonaws.com -> None (use default)
    fn extract_region_from_host(host: &str) -> Option<String> {
        let parts: Vec<&str> = host.split('.').collect();
        if parts.len() >= 3 {
            // Check if second part looks like a region (contains hyphens)
            if parts[1].contains('-') {
                return Some(parts[1].to_string());
            }
        }
        None
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
    
    /// Sign an HTTP request using AWS Signature Version 4
    fn sign_request(
        &self,
        method: &str,
        uri: &str,
        headers: &HeaderMap,
        body: &str,
        host: &str,
    ) -> Result<(String, Vec<(String, String)>), StrategyError> {
        let access_key = self.access_key.as_ref()
            .ok_or_else(|| StrategyError::EnvVarNotFound("AWS_ACCESS_KEY_ID".to_string()))?;
        let secret_key = self.secret_key.as_ref()
            .ok_or_else(|| StrategyError::EnvVarNotFound("AWS_SECRET_ACCESS_KEY".to_string()))?;
        
        // Determine service and region from host if possible
        let service = if self.service == "execute-api" {
            Self::extract_service_from_host(host)
        } else {
            self.service.clone()
        };
        
        let region = Self::extract_region_from_host(host)
            .unwrap_or_else(|| self.region.clone());
        
        // Create AWS credentials
        let credentials = if let Some(token) = &self.session_token {
            Credentials::new(
                access_key,
                secret_key,
                Some(token.to_string()),
                None,
                "slapenir-proxy",
            )
        } else {
            Credentials::new(
                access_key,
                secret_key,
                None,
                None,
                "slapenir-proxy",
            )
        };
        
        // Prepare signing parameters
        let identity = credentials.into();
        let signing_settings = SigningSettings::default();
        let signing_params = v4::SigningParams::builder()
            .identity(&identity)
            .region(&region)
            .name(&service)
            .time(SystemTime::now())
            .settings(signing_settings)
            .build()
            .map_err(|e| StrategyError::InjectionFailed(format!("Failed to build signing params: {}", e)))?;
        
        // Build signable request
        let mut signable_headers = vec![];
        for (name, value) in headers.iter() {
            if let Ok(value_str) = value.to_str() {
                signable_headers.push((name.as_str(), value_str));
            }
        }
        
        let signable_body = if body.is_empty() {
            SignableBody::Bytes(&[])
        } else {
            SignableBody::Bytes(body.as_bytes())
        };
        
        let signable_request = SignableRequest::new(
            method,
            uri,
            signable_headers.iter().map(|(k, v)| (*k, *v)),
            signable_body,
        ).map_err(|e| StrategyError::InjectionFailed(format!("Failed to create signable request: {}", e)))?;
        
        // Sign the request
        let (signing_instructions, _signature) = sign(signable_request, &signing_params.into())
            .map_err(|e| StrategyError::InjectionFailed(format!("Failed to sign request: {}", e)))?
            .into_parts();
        
        // Extract signed headers
        let mut new_headers = vec![];
        for (name, value) in signing_instructions.headers() {
            new_headers.push((name.to_string(), value.to_string()));
        }
        
        tracing::debug!(
            "AWS SigV4 '{}': Signed request for service={}, region={}",
            self.name, service, region
        );
        
        Ok((body.to_string(), new_headers))
    }
}

impl AuthStrategy for AWSSigV4Strategy {
    fn name(&self) -> &str {
        &self.name
    }
    
    fn strategy_type(&self) -> &str {
        "aws_sigv4"
    }
    
    fn detect(&self, headers: &HeaderMap, body: &str) -> bool {
        // Check for dummy AWS access key patterns in Authorization header
        if let Some(auth_header) = headers.get("authorization") {
            if let Ok(auth_str) = auth_header.to_str() {
                // Look for AWS access key patterns (AKIA followed by 16 chars)
                if auth_str.contains("AKIA") && auth_str.contains("DUMMY") {
                    return true;
                }
            }
        }
        
        // Check for dummy access keys in body
        if body.contains("AKIA") && body.contains("DUMMY") {
            return true;
        }
        
        false
    }
    
    fn inject(&self, body: &str, headers: &mut HeaderMap) -> Result<String, StrategyError> {
        // For AWS SigV4, we need to sign the entire request
        // This is more complex than simple token replacement
        
        // Extract request details
        let method = headers.get("method")
            .and_then(|v| v.to_str().ok())
            .unwrap_or("POST");
        
        let uri = headers.get("uri")
            .and_then(|v| v.to_str().ok())
            .unwrap_or("/");
        
        let host = headers.get("host")
            .and_then(|v| v.to_str().ok())
            .ok_or_else(|| StrategyError::InjectionFailed("Missing host header".to_string()))?;
        
        // Sign the request
        let (signed_body, signed_headers) = self.sign_request(method, uri, headers, body, host)?;
        
        // Update headers with signed values
        for (name, value) in signed_headers {
            if let (Ok(header_name), Ok(header_value)) = (
                name.parse::<axum::http::HeaderName>(),
                value.parse::<axum::http::HeaderValue>()
            ) {
                headers.insert(header_name, header_value);
            }
        }
        
        tracing::debug!(
            "AWS SigV4 strategy '{}': Injected signature (body: {} bytes)",
            self.name,
            signed_body.len()
        );
        
        Ok(signed_body)
    }
    
    fn validate_host(&self, host: &str) -> bool {
        if self.allowed_hosts.is_empty() {
            tracing::warn!(
                "AWS SigV4 strategy '{}': No host whitelist configured (allowing all hosts)",
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
            "AWS SigV4 strategy '{}': Host '{}' not in whitelist: {:?}",
            self.name, host, self.allowed_hosts
        );
        false
    }
    
    fn dummy_patterns(&self) -> Vec<String> {
        vec![
            "AKIADUMMY".to_string(),
            "AKIA00000000DUMMY".to_string(),
        ]
    }
    
    fn real_credential(&self) -> Option<String> {
        self.access_key.clone()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::http::HeaderValue;

    #[test]
    fn test_extract_service_from_host() {
        assert_eq!(AWSSigV4Strategy::extract_service_from_host("s3.amazonaws.com"), "s3");
        assert_eq!(AWSSigV4Strategy::extract_service_from_host("dynamodb.us-east-1.amazonaws.com"), "dynamodb");
        assert_eq!(AWSSigV4Strategy::extract_service_from_host("lambda.eu-west-1.amazonaws.com"), "lambda");
    }

    #[test]
    fn test_extract_region_from_host() {
        assert_eq!(
            AWSSigV4Strategy::extract_region_from_host("dynamodb.us-east-1.amazonaws.com"),
            Some("us-east-1".to_string())
        );
        assert_eq!(
            AWSSigV4Strategy::extract_region_from_host("s3.amazonaws.com"),
            None
        );
    }

    #[test]
    fn test_matches_wildcard() {
        assert!(AWSSigV4Strategy::matches_wildcard("*.amazonaws.com", "s3.amazonaws.com"));
        assert!(AWSSigV4Strategy::matches_wildcard("*.amazonaws.com", "amazonaws.com"));
        assert!(!AWSSigV4Strategy::matches_wildcard("*.amazonaws.com", "evil.com"));
    }

    #[test]
    fn test_aws_strategy_creation() {
        std::env::set_var("TEST_AWS_ACCESS_KEY", "AKIATEST123");
        std::env::set_var("TEST_AWS_SECRET_KEY", "secret123");
        
        let strategy = AWSSigV4Strategy::new(
            "test-aws".to_string(),
            "TEST_AWS_ACCESS_KEY".to_string(),
            "TEST_AWS_SECRET_KEY".to_string(),
            "us-east-1".to_string(),
            None,
            vec!["*.amazonaws.com".to_string()],
        ).unwrap();
        
        assert_eq!(strategy.name(), "test-aws");
        assert_eq!(strategy.strategy_type(), "aws_sigv4");
        assert_eq!(strategy.region, "us-east-1");
    }

    #[test]
    fn test_aws_strategy_detect() {
        std::env::set_var("TEST_AWS_ACCESS_KEY_2", "AKIATEST");
        std::env::set_var("TEST_AWS_SECRET_KEY_2", "secret");
        
        let strategy = AWSSigV4Strategy::new(
            "test".to_string(),
            "TEST_AWS_ACCESS_KEY_2".to_string(),
            "TEST_AWS_SECRET_KEY_2".to_string(),
            "us-east-1".to_string(),
            None,
            vec![],
        ).unwrap();
        
        let mut headers = HeaderMap::new();
        headers.insert("authorization", HeaderValue::from_static("AWS4 AKIADUMMY..."));
        
        assert!(strategy.detect(&headers, ""));
    }

    #[test]
    fn test_aws_strategy_validate_host() {
        std::env::set_var("TEST_AWS_ACCESS_KEY_3", "AKIATEST");
        std::env::set_var("TEST_AWS_SECRET_KEY_3", "secret");
        
        let strategy = AWSSigV4Strategy::new(
            "test".to_string(),
            "TEST_AWS_ACCESS_KEY_3".to_string(),
            "TEST_AWS_SECRET_KEY_3".to_string(),
            "us-east-1".to_string(),
            None,
            vec!["*.amazonaws.com".to_string()],
        ).unwrap();
        
        assert!(strategy.validate_host("s3.amazonaws.com"));
        assert!(strategy.validate_host("dynamodb.us-east-1.amazonaws.com"));
        assert!(!strategy.validate_host("evil.com"));
    }
}
