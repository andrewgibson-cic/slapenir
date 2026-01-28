// SLAPENIR Proxy Handler - HTTP Forwarding with Sanitization
// Forwards requests to LLM APIs with secret injection/sanitization

use crate::middleware::AppState;
use axum::{
    body::Body,
    extract::{Request, State},
    http::{HeaderMap, Method, StatusCode, Uri},
    response::{IntoResponse, Response},
};
use hyper_util::{
    client::legacy::{connect::HttpConnector, Client},
    rt::TokioExecutor,
};
use thiserror::Error;

/// HTTP client for forwarding requests
pub type HttpClient = Client<HttpConnector, Body>;

/// Create a configured HTTP client for proxying
pub fn create_http_client() -> HttpClient {
    Client::builder(TokioExecutor::new()).build_http()
}

/// Proxy error types
#[derive(Debug, Error)]
pub enum ProxyError {
    #[error("Failed to read request body: {0}")]
    RequestBodyRead(String),
    
    #[error("Request body is not valid UTF-8: {0}")]
    InvalidUtf8(String),
    
    #[error("Failed to forward request: {0}")]
    ForwardRequest(String),
    
    #[error("Failed to read response body: {0}")]
    ResponseBodyRead(String),
    
    #[error("Invalid target URL: {0}")]
    InvalidTargetUrl(String),
    
    #[error("Missing required header: {0}")]
    MissingHeader(String),
}

impl IntoResponse for ProxyError {
    fn into_response(self) -> Response {
        let (status, message) = match self {
            ProxyError::RequestBodyRead(_) | ProxyError::InvalidUtf8(_) => {
                (StatusCode::BAD_REQUEST, self.to_string())
            }
            ProxyError::ForwardRequest(_) | ProxyError::ResponseBodyRead(_) => {
                (StatusCode::BAD_GATEWAY, self.to_string())
            }
            ProxyError::InvalidTargetUrl(_) | ProxyError::MissingHeader(_) => {
                (StatusCode::BAD_REQUEST, self.to_string())
            }
        };
        
        (status, message).into_response()
    }
}

/// Main proxy handler for LLM API requests
///
/// This handler:
/// 1. Reads the incoming request body
/// 2. Injects real secrets (dummy -> real)
/// 3. Forwards to the target LLM API
/// 4. Reads the response
/// 5. Sanitizes secrets from the response (real -> [REDACTED])
/// 6. Returns to the agent
pub async fn proxy_handler(
    State(state): State<AppState>,
    method: Method,
    uri: Uri,
    headers: HeaderMap,
    request: Request,
) -> Result<Response, ProxyError> {
    tracing::debug!("Proxying request: {} {}", method, uri);
    
    // Extract the request body
    let body_bytes = axum::body::to_bytes(request.into_body(), usize::MAX)
        .await
        .map_err(|e| ProxyError::RequestBodyRead(e.to_string()))?;
    
    // Convert to UTF-8 string for sanitization
    let body_str = std::str::from_utf8(&body_bytes)
        .map_err(|e| ProxyError::InvalidUtf8(e.to_string()))?;
    
    // Step 1: Inject real secrets into the request
    let injected_body = state.secret_map.inject(body_str);
    tracing::debug!("Injected secrets into request ({} bytes)", injected_body.len());
    
    // Determine target URL
    let target_url = determine_target_url(&headers, &uri)?;
    tracing::info!("Forwarding request to: {}", target_url);
    
    // Build the forwarded request
    let target_uri: Uri = target_url
        .parse()
        .map_err(|e| ProxyError::InvalidTargetUrl(format!("Failed to parse URL: {}", e)))?;
    
    let mut forwarded_request = hyper::Request::builder()
        .method(method.clone())
        .uri(target_uri);
    
    // Copy relevant headers (skip hop-by-hop headers)
    for (name, value) in headers.iter() {
        let name_str = name.as_str();
        if !is_hop_by_hop_header(name_str) {
            forwarded_request = forwarded_request.header(name, value);
        }
    }
    
    let forwarded_request = forwarded_request
        .body(Body::from(injected_body))
        .map_err(|e| ProxyError::ForwardRequest(format!("Failed to build request: {}", e)))?;
    
    // Execute the request
    let response = state.http_client
        .request(forwarded_request)
        .await
        .map_err(|e| ProxyError::ForwardRequest(e.to_string()))?;
    
    // Extract response parts
    let (parts, body) = response.into_parts();
    // Convert hyper Incoming body to axum Body
    let body = Body::new(body);

    
    // Read response body
    let response_bytes = axum::body::to_bytes(body, usize::MAX)
        .await
        .map_err(|e| ProxyError::ResponseBodyRead(e.to_string()))?;
    
    // Convert to UTF-8 (if not valid UTF-8, return as-is)
    let response_str = match std::str::from_utf8(&response_bytes) {
        Ok(s) => s,
        Err(_) => {
            tracing::warn!("Response body is not valid UTF-8, returning as-is");
            let response = Response::from_parts(parts, Body::from(response_bytes));
            return Ok(response);
        }
    };
    
    // Step 2: Sanitize real secrets from the response
    let sanitized_body = state.secret_map.sanitize(response_str);
    tracing::debug!("Sanitized secrets from response ({} bytes)", sanitized_body.len());
    
    // Paranoid verification: ensure no secrets leaked through
    let verification = state.secret_map.sanitize(&sanitized_body);
    if verification != sanitized_body {
        tracing::error!("Secret sanitization failed verification!");
        return Err(ProxyError::ResponseBodyRead(
            "Sanitization verification failed".to_string(),
        ));
    }
    
    // Build the response
    let response = Response::from_parts(parts, Body::from(sanitized_body));
    
    tracing::info!("Proxy request completed successfully");
    Ok(response)
}

/// Determine the target URL based on headers and configuration
fn determine_target_url(headers: &HeaderMap, uri: &Uri) -> Result<String, ProxyError> {
    // Check for X-Target-URL header (allows agent to specify target)
    if let Some(target) = headers.get("x-target-url") {
        let target_str = target
            .to_str()
            .map_err(|e| ProxyError::InvalidTargetUrl(e.to_string()))?;
        
        // Ensure the path and query are appended
        let path_and_query = uri.path_and_query()
            .map(|pq| pq.as_str())
            .unwrap_or("");
        
        return Ok(format!("{}{}", target_str.trim_end_matches('/'), path_and_query));
    }
    
    // Default to OpenAI API
    let base_url = std::env::var("OPENAI_API_URL")
        .unwrap_or_else(|_| "https://api.openai.com".to_string());
    
    let path_and_query = uri.path_and_query()
        .map(|pq| pq.as_str())
        .unwrap_or("/");
    
    Ok(format!("{}{}", base_url.trim_end_matches('/'), path_and_query))
}

/// Check if a header is hop-by-hop (should not be forwarded)
fn is_hop_by_hop_header(name: &str) -> bool {
    matches!(
        name.to_lowercase().as_str(),
        "connection"
            | "keep-alive"
            | "proxy-authenticate"
            | "proxy-authorization"
            | "te"
            | "trailers"
            | "transfer-encoding"
            | "upgrade"
            | "host" // We set this based on target URL
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_is_hop_by_hop_header() {
        assert!(is_hop_by_hop_header("connection"));
        assert!(is_hop_by_hop_header("Connection"));
        assert!(is_hop_by_hop_header("HOST"));
        assert!(!is_hop_by_hop_header("authorization"));
        assert!(!is_hop_by_hop_header("content-type"));
    }

    #[test]
    fn test_determine_target_url_default() {
        let headers = HeaderMap::new();
        let uri: Uri = "/v1/chat/completions".parse().unwrap();
        
        let result = determine_target_url(&headers, &uri).unwrap();
        assert!(result.contains("/v1/chat/completions"));
    }

    #[test]
    fn test_determine_target_url_with_header() {
        let mut headers = HeaderMap::new();
        use axum::http::HeaderValue;
        headers.insert(
            "x-target-url",
            HeaderValue::from_static("https://api.anthropic.com"),
        );
        let uri: Uri = "/v1/messages".parse().unwrap();
        
        let result = determine_target_url(&headers, &uri).unwrap();
        assert_eq!(result, "https://api.anthropic.com/v1/messages");
    }

    #[test]
    fn test_determine_target_url_with_query() {
        let headers = HeaderMap::new();
        let uri: Uri = "/v1/models?limit=10".parse().unwrap();
        
        let result = determine_target_url(&headers, &uri).unwrap();
        assert!(result.contains("/v1/models?limit=10"));
    }
}