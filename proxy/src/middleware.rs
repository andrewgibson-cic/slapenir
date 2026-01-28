// SLAPENIR Middleware - Request/Response Sanitization
use crate::proxy::HttpClient;
// Integrates SecretMap into the HTTP request/response pipeline

use crate::sanitizer::SecretMap;
use axum::{
    body::Body,
    extract::State,
    http::{Request, Response, StatusCode},
    middleware::Next,
    response::IntoResponse,
};
use std::sync::Arc;

/// Shared application state containing the secret map
#[derive(Clone)]
pub struct AppState {
    pub secret_map: Arc<SecretMap>,
    pub http_client: HttpClient,
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
    // Extract request body
    let (parts, body) = request.into_parts();
    
    // Read body bytes
    let bytes = match axum::body::to_bytes(body, usize::MAX).await {
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
    let injected = state.secret_map.inject(body_str);
    tracing::debug!("Injected secrets into request body ({} bytes)", injected.len());

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
pub async fn sanitize_secrets_middleware(
    State(state): State<AppState>,
    request: Request<Body>,
    next: Next,
) -> impl IntoResponse {
    // Pass request through
    let response = next.run(request).await;

    // Extract response parts
    let (parts, body) = response.into_parts();

    // Read response body
    let bytes = match axum::body::to_bytes(body, usize::MAX).await {
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

    // Convert to string
    let body_str = match std::str::from_utf8(&bytes) {
        Ok(s) => s,
        Err(e) => {
            tracing::warn!("Response body is not valid UTF-8, returning as-is: {}", e);
            // Return original bytes if not UTF-8
            return Response::from_parts(parts, Body::from(bytes)).into_response();
        }
    };

    // Sanitize real secrets
    let sanitized = state.secret_map.sanitize(body_str);
    tracing::debug!(
        "Sanitized secrets from response body ({} bytes)",
        sanitized.len()
    );

    // Verify no real secrets remain (paranoid check)
    let verification = state.secret_map.sanitize(&sanitized);
    if verification != sanitized {
        tracing::error!("Secret sanitization failed verification!");
        return (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Secret sanitization failed".to_string(),
        )
            .into_response();
    }

    // Reconstruct response with sanitized body
    let new_body = Body::from(sanitized);
    Response::from_parts(parts, new_body).into_response()
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
        AppState {
            secret_map: Arc::new(secret_map),
            http_client: crate::proxy::create_http_client(),
        }
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
}