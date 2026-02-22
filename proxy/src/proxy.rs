// SLAPENIR Proxy Handler - HTTP Forwarding with Sanitization
// Forwards requests to LLM APIs with secret injection/sanitization
//
// SECURITY FIXES:
// - A: Non-UTF-8 bypass via sanitize_bytes()
// - B: Header sanitization via sanitize_headers()
// - D: Memory limits via ProxyConfig
// - E: Content-Length recalculation

use crate::metrics;
use crate::middleware::AppState;
use axum::{
    body::Body,
    extract::{Request, State},
    http::{HeaderMap, HeaderValue, Method, StatusCode, Uri},
    response::{IntoResponse, Response},
};
use hyper_util::{
    client::legacy::{connect::HttpConnector, Client},
    rt::TokioExecutor,
};
use std::time::Instant;
use thiserror::Error;

/// Default maximum request body size (10 MB)
pub const DEFAULT_MAX_REQUEST_SIZE: usize = 10 * 1024 * 1024;
/// Default maximum response body size (100 MB)
pub const DEFAULT_MAX_RESPONSE_SIZE: usize = 100 * 1024 * 1024;

/// HTTP client for forwarding requests
pub type HttpClient = Client<HttpConnector, Body>;

/// Create a configured HTTP client for proxying
pub fn create_http_client() -> HttpClient {
    Client::builder(TokioExecutor::new()).build_http()
}

/// Proxy configuration with security limits
#[derive(Debug, Clone)]
pub struct ProxyConfig {
    /// Maximum request body size in bytes (prevents OOM)
    pub max_request_size: usize,
    /// Maximum response body size in bytes (prevents OOM)
    pub max_response_size: usize,
}

impl Default for ProxyConfig {
    fn default() -> Self {
        Self {
            max_request_size: DEFAULT_MAX_REQUEST_SIZE,
            max_response_size: DEFAULT_MAX_RESPONSE_SIZE,
        }
    }
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

    #[error("Request body too large (max {0} bytes)")]
    RequestBodyTooLarge(usize),

    #[error("Response body too large (max {0} bytes)")]
    ResponseBodyTooLarge(usize),
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
            ProxyError::RequestBodyTooLarge(_) | ProxyError::ResponseBodyTooLarge(_) => {
                (StatusCode::PAYLOAD_TOO_LARGE, self.to_string())
            }
        };

        (status, message).into_response()
    }
}

/// Build sanitized response headers with correct Content-Length
///
/// SECURITY FIX E: Recalculates Content-Length after body modification
/// Removes checksums (ETag, Content-MD5) since body was modified
pub fn build_response_headers(original_headers: &HeaderMap, body_len: usize) -> HeaderMap {
    let mut headers = HeaderMap::new();

    // Set correct Content-Length for sanitized body
    headers.insert(
        axum::http::header::CONTENT_LENGTH,
        HeaderValue::from(body_len),
    );

    // Copy safe headers, excluding those that become invalid after body modification
    for (name, value) in original_headers.iter() {
        let name_str = name.as_str().to_lowercase();

        match name_str.as_str() {
            // Skip - we set these ourselves
            "content-length" | "transfer-encoding" => continue,

            // Skip - body was modified, these are now invalid
            "etag" | "content-md5" | "content-crc32" => {
                tracing::debug!("Removing checksum header after sanitization: {}", name_str);
                continue;
            }

            // Skip blocked headers (security)
            "x-debug-token" | "x-debug-info" | "server-timing" | "x-runtime" => {
                tracing::debug!("Removing blocked header: {}", name_str);
                continue;
            }

            // Copy everything else
            _ => {
                headers.insert(name.clone(), value.clone());
            }
        }
    }

    headers
}

/// Main proxy handler for LLM API requests
///
/// This handler:
/// 1. Reads the incoming request body (with size limit - FIX D)
/// 2. Injects real secrets (dummy -> real)
/// 3. Forwards to the target LLM API
/// 4. Reads the response (with size limit - FIX D)
/// 5. Sanitizes secrets from the response (binary-safe - FIX A)
/// 6. Sanitizes response headers (FIX B)
/// 7. Rebuilds headers with correct Content-Length (FIX E)
/// 8. Returns to the agent
pub async fn proxy_handler(
    State(state): State<AppState>,
    method: Method,
    uri: Uri,
    headers: HeaderMap,
    request: Request,
) -> Result<Response, ProxyError> {
    let start_time = Instant::now();
    metrics::inc_active_connections();

    // Get config (use defaults if not configured)
    let config = state.config.clone().unwrap_or_default();
    let max_request_size = config.max_request_size;
    let max_response_size = config.max_response_size;

    tracing::debug!("Proxying request: {} {}", method, uri);

    // Extract endpoint for metrics (first part of path)
    let endpoint = uri.path().split('/').nth(1).unwrap_or("unknown");

    // SECURITY FIX D: Read request body with size limit
    let body_bytes = axum::body::to_bytes(request.into_body(), max_request_size)
        .await
        .map_err(|e| {
            let err_str = e.to_string();
            if err_str.contains("length limit") {
                ProxyError::RequestBodyTooLarge(max_request_size)
            } else {
                ProxyError::RequestBodyRead(err_str)
            }
        })?;

    // Convert to UTF-8 string for sanitization
    let body_str =
        std::str::from_utf8(&body_bytes).map_err(|e| ProxyError::InvalidUtf8(e.to_string()))?;

    // Record request size
    metrics::HTTP_REQUEST_SIZE_BYTES.observe(body_bytes.len() as f64);

    // Step 1: Inject real secrets into the request
    let injected_body = state.secret_map.inject(body_str);
    tracing::debug!(
        "Injected secrets into request ({} bytes)",
        injected_body.len()
    );

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
    let response = state
        .http_client
        .request(forwarded_request)
        .await
        .map_err(|e| ProxyError::ForwardRequest(e.to_string()))?;

    // Extract response parts
    let (parts, body) = response.into_parts();
    // Convert hyper Incoming body to axum Body
    let body = Body::new(body);

    // SECURITY FIX D: Read response body with size limit
    let response_bytes = axum::body::to_bytes(body, max_response_size)
        .await
        .map_err(|e| {
            let err_str = e.to_string();
            if err_str.contains("length limit") {
                ProxyError::ResponseBodyTooLarge(max_response_size)
            } else {
                ProxyError::ResponseBodyRead(err_str)
            }
        })?;

    // Record response size
    metrics::HTTP_RESPONSE_SIZE_BYTES.observe(response_bytes.len() as f64);

    // SECURITY FIX A: Use binary-safe sanitization for ALL responses
    // This prevents bypass via non-UTF-8 payloads
    let sanitized_bytes = state.secret_map.sanitize_bytes(&response_bytes);
    let sanitized_body = sanitized_bytes.into_owned();

    tracing::debug!(
        "Sanitized secrets from response ({} bytes)",
        sanitized_body.len()
    );

    // SECURITY FIX A: Paranoid verification on sanitized bytes
    let verification = state.secret_map.sanitize_bytes(&sanitized_body);
    if verification != sanitized_body {
        tracing::error!("Secret sanitization failed verification!");
        return Err(ProxyError::ResponseBodyRead(
            "Sanitization verification failed".to_string(),
        ));
    }

    // SECURITY FIX B: Sanitize response headers
    let sanitized_headers = state.secret_map.sanitize_headers(&parts.headers);

    // SECURITY FIX E: Build response with correct Content-Length
    let final_headers = build_response_headers(&sanitized_headers, sanitized_body.len());

    // Record metrics
    let duration = start_time.elapsed().as_secs_f64();
    let status = parts.status.as_u16();

    // Build the final response
    let mut response_builder = Response::builder().status(status);
    for (name, value) in final_headers.iter() {
        response_builder = response_builder.header(name, value);
    }

    let response = response_builder
        .body(Body::from(sanitized_body))
        .map_err(|e| ProxyError::ResponseBodyRead(format!("Failed to build response: {}", e)))?;

    metrics::record_http_request(method.as_str(), status, endpoint, duration);
    metrics::dec_active_connections();

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
        let path_and_query = uri.path_and_query().map(|pq| pq.as_str()).unwrap_or("");

        return Ok(format!(
            "{}{}",
            target_str.trim_end_matches('/'),
            path_and_query
        ));
    }

    // Default to OpenAI API
    let base_url =
        std::env::var("OPENAI_API_URL").unwrap_or_else(|_| "https://api.openai.com".to_string());

    let path_and_query = uri.path_and_query().map(|pq| pq.as_str()).unwrap_or("/");

    Ok(format!(
        "{}{}",
        base_url.trim_end_matches('/'),
        path_and_query
    ))
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
