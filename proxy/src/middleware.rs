// SLAPENIR Middleware - Request/Response Sanitization
// Integrates SecretMap into the HTTP request/response pipeline
//
// SECURITY FIXES:
// - A: Binary-safe sanitization via sanitize_bytes()
// - B: Header sanitization
// - D: Size limits via ProxyConfig

use crate::proxy::{HttpClient, ProxyConfig, DEFAULT_MAX_REQUEST_SIZE, DEFAULT_MAX_RESPONSE_SIZE};
use crate::sanitizer::SecretMap;
use axum::{
    body::Body,
    extract::State,
    http::{Request, Response, StatusCode},
    middleware::Next,
    response::IntoResponse,
};
use std::collections::HashMap;
use std::sync::{Arc, RwLock};

/// Shared application state containing the secret map
#[derive(Clone)]
pub struct AppState {
    pub secret_map: Arc<SecretMap>,
    /// Runtime secrets from repo .env files (registered at work-start)
    pub runtime_secrets: Arc<RwLock<HashMap<String, String>>>,
    pub http_client: HttpClient,
    /// SECURITY FIX D: Configuration with size limits
    pub config: Option<ProxyConfig>,
}

impl AppState {
    /// Create a new AppState with default configuration
    pub fn new(secret_map: Arc<SecretMap>, http_client: HttpClient) -> Self {
        Self {
            secret_map,
            runtime_secrets: Arc::new(RwLock::new(HashMap::new())),
            http_client,
            config: None,
        }
    }

    /// Create an AppState with custom configuration
    pub fn with_config(
        secret_map: Arc<SecretMap>,
        http_client: HttpClient,
        config: ProxyConfig,
    ) -> Self {
        Self {
            secret_map,
            runtime_secrets: Arc::new(RwLock::new(HashMap::new())),
            http_client,
            config: Some(config),
        }
    }

    pub fn register_secrets(&self, secrets: HashMap<String, String>) -> usize {
        let mut rt = self.runtime_secrets.write().unwrap();
        let count = secrets.len();
        rt.extend(secrets);
        count
    }

    pub fn unregister_secrets(&self, keys: &[String]) {
        let mut rt = self.runtime_secrets.write().unwrap();
        for key in keys {
            rt.remove(key);
        }
    }

    pub fn inject_all(&self, data: &str) -> String {
        let rt = self.runtime_secrets.read().unwrap();
        let mut result = self.secret_map.inject(data);
        for (dummy, real) in rt.iter() {
            result = result.replace(dummy.as_str(), real.as_str());
        }
        result
    }

    pub fn sanitize_all(&self, data: &str) -> String {
        let rt = self.runtime_secrets.read().unwrap();
        let mut result = self.secret_map.sanitize(data);
        for (_, real) in rt.iter() {
            result = result.replace(real.as_str(), "[REDACTED]");
        }
        result
    }

    pub fn sanitize_bytes_all(&self, data: &[u8]) -> std::borrow::Cow<'_, [u8]> {
        let rt = self.runtime_secrets.read().unwrap();
        let mut result = self.secret_map.sanitize_bytes(data).into_owned();
        for (_, real) in rt.iter() {
            let real_bytes = real.as_bytes();
            let redacted = b"[REDACTED]";
            let mut i = 0;
            while i + real_bytes.len() <= result.len() {
                if &result[i..i + real_bytes.len()] == real_bytes {
                    let mut new_result = Vec::with_capacity(result.len() + redacted.len());
                    new_result.extend_from_slice(&result[..i]);
                    new_result.extend_from_slice(redacted);
                    new_result.extend_from_slice(&result[i + real_bytes.len()..]);
                    result = new_result;
                    i += redacted.len();
                } else {
                    i += 1;
                }
            }
        }
        std::borrow::Cow::Owned(result)
    }

    pub fn sanitize_headers_all(&self, headers: &axum::http::HeaderMap) -> axum::http::HeaderMap {
        let rt = self.runtime_secrets.read().unwrap();
        let sanitized = self.secret_map.sanitize_headers(headers);
        if rt.is_empty() {
            return sanitized;
        }
        let mut final_headers = axum::http::HeaderMap::new();
        for (name, value) in sanitized.iter() {
            if let Ok(v) = value.to_str() {
                let mut cleaned = v.to_string();
                for (_, real) in rt.iter() {
                    cleaned = cleaned.replace(real.as_str(), "[REDACTED]");
                }
                if let Ok(hv) = axum::http::HeaderValue::from_str(&cleaned) {
                    final_headers.insert(name.clone(), hv);
                    continue;
                }
            }
            final_headers.insert(name.clone(), value.clone());
        }
        final_headers
    }
}

/// Middleware to inject secrets into outbound requests (Agent -> Internet)
///
/// This middleware intercepts requests from the agent and replaces
/// dummy tokens with real secrets before forwarding to external APIs.
pub async fn inject_secrets_middleware(
    State(state): State<AppState>,
    request: Request<Body>,
    next: Next,
) -> impl IntoResponse {
    // Get max request size from config
    let max_size = state
        .config
        .as_ref()
        .map(|c| c.max_request_size)
        .unwrap_or(DEFAULT_MAX_REQUEST_SIZE);

    // Extract request body
    let (parts, body) = request.into_parts();

    // SECURITY FIX D: Read body bytes with size limit
    let bytes = match axum::body::to_bytes(body, max_size).await {
        Ok(bytes) => bytes,
        Err(e) => {
            tracing::error!("Failed to read request body: {}", e);
            return (
                StatusCode::BAD_REQUEST,
                format!("Failed to read request body: {}", e),
            )
                .into_response();
        }
    };

    // Convert to string for pattern matching
    let body_str = match std::str::from_utf8(&bytes) {
        Ok(s) => s,
        Err(e) => {
            tracing::error!("Request body is not valid UTF-8: {}", e);
            return (
                StatusCode::BAD_REQUEST,
                "Request body must be valid UTF-8".to_string(),
            )
                .into_response();
        }
    };

    // Inject real secrets
    let injected = state.inject_all(body_str);
    tracing::debug!(
        "Injected secrets into request body ({} bytes)",
        injected.len()
    );

    // Reconstruct request with modified body
    let new_body = Body::from(injected);
    let request = Request::from_parts(parts, new_body);

    // Continue to next middleware/handler
    next.run(request).await
}

/// Middleware to sanitize secrets from inbound responses (Internet -> Agent)
///
/// This middleware intercepts responses from external APIs and redacts
/// real secrets before returning to the agent.
///
/// SECURITY FIX A: Uses binary-safe sanitization
pub async fn sanitize_secrets_middleware(
    State(state): State<AppState>,
    request: Request<Body>,
    next: Next,
) -> impl IntoResponse {
    // Get max response size from config
    let max_size = state
        .config
        .as_ref()
        .map(|c| c.max_response_size)
        .unwrap_or(DEFAULT_MAX_RESPONSE_SIZE);

    // Pass request through
    let response = next.run(request).await;

    // Extract response parts
    let (parts, body) = response.into_parts();

    // SECURITY FIX D: Read response body with size limit
    let bytes = match axum::body::to_bytes(body, max_size).await {
        Ok(bytes) => bytes,
        Err(e) => {
            tracing::error!("Failed to read response body: {}", e);
            return (
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("Failed to read response body: {}", e),
            )
                .into_response();
        }
    };

    // SECURITY FIX A: Use binary-safe sanitization (works on any bytes)
    let sanitized = state.sanitize_bytes_all(&bytes);
    let sanitized_bytes = sanitized.into_owned();

    tracing::debug!(
        "Sanitized secrets from response body ({} bytes)",
        sanitized_bytes.len()
    );

    // SECURITY FIX A: Paranoid verification
    let verification = state.sanitize_bytes_all(&sanitized_bytes);
    if verification != sanitized_bytes {
        tracing::error!("Secret sanitization failed verification!");
        return (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Secret sanitization failed".to_string(),
        )
            .into_response();
    }

    // SECURITY FIX B: Sanitize response headers
    let sanitized_headers = state.sanitize_headers_all(&parts.headers);

    // SECURITY FIX E: Build headers with correct Content-Length
    let final_headers =
        crate::proxy::build_response_headers(&sanitized_headers, sanitized_bytes.len());

    // Build final response
    let mut response_builder = Response::builder().status(parts.status);
    for (name, value) in final_headers.iter() {
        response_builder = response_builder.header(name, value);
    }

    response_builder
        .body(Body::from(sanitized_bytes))
        .unwrap()
        .into_response()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;

    fn create_test_state() -> AppState {
        let mut secrets = HashMap::new();
        secrets.insert("DUMMY_TOKEN".to_string(), "real_secret_123".to_string());
        secrets.insert("DUMMY_KEY".to_string(), "real_key_456".to_string());

        let secret_map = SecretMap::new(secrets).unwrap();
        AppState::new(Arc::new(secret_map), crate::proxy::create_http_client())
    }

    #[test]
    fn test_app_state_creation() {
        let state = create_test_state();
        assert_eq!(state.secret_map.len(), 2);
    }

    #[test]
    fn test_app_state_clone() {
        let state1 = create_test_state();
        let state2 = state1.clone();

        // Both should reference the same SecretMap
        assert_eq!(state1.secret_map.len(), state2.secret_map.len());
    }

    #[test]
    fn test_app_state_with_config() {
        let mut secrets = HashMap::new();
        secrets.insert("DUMMY".to_string(), "real".to_string());
        let secret_map = SecretMap::new(secrets).unwrap();

        let config = ProxyConfig {
            max_request_size: 1024,
            max_response_size: 2048,
        };

        let state = AppState::with_config(
            Arc::new(secret_map),
            crate::proxy::create_http_client(),
            config,
        );

        assert!(state.config.is_some());
        let cfg = state.config.unwrap();
        assert_eq!(cfg.max_request_size, 1024);
        assert_eq!(cfg.max_response_size, 2048);
    }

    #[test]
    fn test_secret_injection_logic() {
        let state = create_test_state();
        let input = "Authorization: Bearer DUMMY_TOKEN";
        let output = state.secret_map.inject(input);
        assert_eq!(output, "Authorization: Bearer real_secret_123");
    }

    #[test]
    fn test_secret_sanitization_logic() {
        let state = create_test_state();
        let input = "Response: {token: 'real_secret_123'}";
        let output = state.secret_map.sanitize(input);
        assert_eq!(output, "Response: {token: '[REDACTED]'}");
        assert!(!output.contains("real_secret_123"));
    }

    #[test]
    fn test_binary_sanitization_logic() {
        let state = create_test_state();
        // Binary payload with embedded secret
        let mut input = b"Binary data: ".to_vec();
        input.extend_from_slice(b"real_secret_123");
        input.extend_from_slice(b" more data");

        let output = state.secret_map.sanitize_bytes(&input);
        let output_vec = output.into_owned();

        // Secret should be redacted
        assert!(!output_vec.windows(15).any(|w| w == b"real_secret_123"));
        assert!(output_vec.windows(10).any(|w| w == b"[REDACTED]"));
    }

    #[test]
    fn test_sanitization_verification() {
        let state = create_test_state();
        let sanitized = "Response: [REDACTED]";

        // Sanitizing again should return the same thing
        let verification = state.secret_map.sanitize(sanitized);
        assert_eq!(verification, sanitized);
    }

    #[test]
    fn test_multiple_secrets_in_request() {
        let state = create_test_state();
        let input = "Token: DUMMY_TOKEN, Key: DUMMY_KEY";
        let output = state.secret_map.inject(input);
        assert!(output.contains("real_secret_123"));
        assert!(output.contains("real_key_456"));
        assert!(!output.contains("DUMMY_TOKEN"));
        assert!(!output.contains("DUMMY_KEY"));
    }

    #[test]
    fn test_multiple_secrets_in_response() {
        let state = create_test_state();
        let input = "Token: real_secret_123, Key: real_key_456";
        let output = state.secret_map.sanitize(input);
        assert_eq!(output, "Token: [REDACTED], Key: [REDACTED]");
        assert!(!output.contains("real_secret_123"));
        assert!(!output.contains("real_key_456"));
    }

    #[test]
    fn test_header_sanitization() {
        use axum::http::{HeaderMap, HeaderValue};

        let mut secrets = HashMap::new();
        secrets.insert("DUMMY".to_string(), "secret_value".to_string());
        let secret_map = SecretMap::new(secrets).unwrap();
        let state = AppState::new(Arc::new(secret_map), crate::proxy::create_http_client());

        let mut headers = HeaderMap::new();
        headers.insert("x-debug-token", HeaderValue::from_static("secret_value"));
        headers.insert("content-type", HeaderValue::from_static("application/json"));

        let sanitized = state.secret_map.sanitize_headers(&headers);

        // Blocked header should be removed
        assert!(!sanitized.contains_key("x-debug-token"));
        // Safe header should be preserved
        assert!(sanitized.contains_key("content-type"));
    }
}
