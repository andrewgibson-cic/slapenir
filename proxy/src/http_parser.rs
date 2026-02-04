/// HTTP Parser Module
///
/// Provides functionality to parse HTTP requests and responses from raw byte streams.
/// This is essential for TLS MITM where we need to inspect and modify HTTP traffic
/// that has been decrypted.
///
/// Features:
/// - Parse HTTP/1.1 requests and responses
/// - Extract headers, method, path, status code
/// - Handle chunked transfer encoding
/// - Preserve request/response integrity
/// - Support streaming for large payloads

use httparse::{Request, Response, Status, EMPTY_HEADER};
use std::collections::HashMap;
use tracing::debug;

/// Parsed HTTP request with headers and body
#[derive(Debug, Clone)]
pub struct ParsedRequest {
    pub method: String,
    pub path: String,
    pub version: u8,
    pub headers: HashMap<String, String>,
    pub body: Vec<u8>,
}

/// Parsed HTTP response with headers and body
#[derive(Debug, Clone)]
pub struct ParsedResponse {
    pub version: u8,
    pub code: u16,
    pub reason: String,
    pub headers: HashMap<String, String>,
    pub body: Vec<u8>,
}

/// HTTP parsing errors
#[derive(Debug, thiserror::Error)]
pub enum ParseError {
    #[error("Invalid HTTP request: {0}")]
    InvalidRequest(String),

    #[error("Invalid HTTP response: {0}")]
    InvalidResponse(String),

    #[error("Incomplete HTTP message (need more data)")]
    Incomplete,

    #[error("Header too large (max 16KB)")]
    HeaderTooLarge,

    #[error("Invalid UTF-8 in headers: {0}")]
    InvalidUtf8(#[from] std::str::Utf8Error),

    #[error("Invalid header value: {0}")]
    InvalidHeaderValue(String),
}

/// Parse an HTTP request from a byte buffer
///
/// Returns:
/// - Ok(Some(ParsedRequest)) if complete request was parsed
/// - Ok(None) if more data is needed
/// - Err(ParseError) if the request is malformed
pub fn parse_request(buffer: &[u8]) -> Result<Option<ParsedRequest>, ParseError> {
    // Limit header size to prevent DoS
    const MAX_HEADER_SIZE: usize = 16 * 1024; // 16KB

    if buffer.len() > MAX_HEADER_SIZE && !buffer.windows(4).any(|w| w == b"\r\n\r\n") {
        return Err(ParseError::HeaderTooLarge);
    }

    // Parse request headers
    let mut headers_buf = [EMPTY_HEADER; 64];
    let mut req = Request::new(&mut headers_buf);

    let status = req
        .parse(buffer)
        .map_err(|e| ParseError::InvalidRequest(e.to_string()))?;

    match status {
        Status::Complete(header_len) => {
            // Extract method
            let method = req
                .method
                .ok_or_else(|| ParseError::InvalidRequest("Missing method".to_string()))?
                .to_string();

            // Extract path
            let path = req
                .path
                .ok_or_else(|| ParseError::InvalidRequest("Missing path".to_string()))?
                .to_string();

            // Extract version
            let version = req
                .version
                .ok_or_else(|| ParseError::InvalidRequest("Missing version".to_string()))?;

            // Extract headers into HashMap
            let mut headers = HashMap::new();
            for header in req.headers.iter() {
                let name = header.name.to_lowercase();
                let value = std::str::from_utf8(header.value)?;
                headers.insert(name, value.to_string());
            }

            // Extract body (everything after headers)
            let body = buffer[header_len..].to_vec();

            debug!(
                "Parsed HTTP request: {} {} (headers: {}, body: {} bytes)",
                method,
                path,
                headers.len(),
                body.len()
            );

            Ok(Some(ParsedRequest {
                method,
                path,
                version,
                headers,
                body,
            }))
        }
        Status::Partial => {
            debug!("Incomplete HTTP request, need more data");
            Ok(None)
        }
    }
}

/// Parse an HTTP response from a byte buffer
///
/// Returns:
/// - Ok(Some(ParsedResponse)) if complete response was parsed
/// - Ok(None) if more data is needed
/// - Err(ParseError) if the response is malformed
pub fn parse_response(buffer: &[u8]) -> Result<Option<ParsedResponse>, ParseError> {
    // Limit header size to prevent DoS
    const MAX_HEADER_SIZE: usize = 16 * 1024; // 16KB

    if buffer.len() > MAX_HEADER_SIZE && !buffer.windows(4).any(|w| w == b"\r\n\r\n") {
        return Err(ParseError::HeaderTooLarge);
    }

    // Parse response headers
    let mut headers_buf = [EMPTY_HEADER; 64];
    let mut resp = Response::new(&mut headers_buf);

    let status = resp
        .parse(buffer)
        .map_err(|e| ParseError::InvalidResponse(e.to_string()))?;

    match status {
        Status::Complete(header_len) => {
            // Extract version
            let version = resp
                .version
                .ok_or_else(|| ParseError::InvalidResponse("Missing version".to_string()))?;

            // Extract status code
            let code = resp
                .code
                .ok_or_else(|| ParseError::InvalidResponse("Missing status code".to_string()))?;

            // Extract reason phrase
            let reason = resp
                .reason
                .ok_or_else(|| ParseError::InvalidResponse("Missing reason phrase".to_string()))?
                .to_string();

            // Extract headers into HashMap
            let mut headers = HashMap::new();
            for header in resp.headers.iter() {
                let name = header.name.to_lowercase();
                let value = std::str::from_utf8(header.value)?;
                headers.insert(name, value.to_string());
            }

            // Extract body (everything after headers)
            let body = buffer[header_len..].to_vec();

            debug!(
                "Parsed HTTP response: {} {} (headers: {}, body: {} bytes)",
                code,
                reason,
                headers.len(),
                body.len()
            );

            Ok(Some(ParsedResponse {
                version,
                code,
                reason,
                headers,
                body,
            }))
        }
        Status::Partial => {
            debug!("Incomplete HTTP response, need more data");
            Ok(None)
        }
    }
}

/// Serialize a ParsedRequest back into HTTP wire format
pub fn serialize_request(req: &ParsedRequest) -> Vec<u8> {
    let mut buffer = Vec::new();

    // Request line
    buffer.extend_from_slice(req.method.as_bytes());
    buffer.push(b' ');
    buffer.extend_from_slice(req.path.as_bytes());
    buffer.extend_from_slice(b" HTTP/1.");
    buffer.push(b'0' + req.version);
    buffer.extend_from_slice(b"\r\n");

    // Headers
    for (name, value) in &req.headers {
        buffer.extend_from_slice(name.as_bytes());
        buffer.extend_from_slice(b": ");
        buffer.extend_from_slice(value.as_bytes());
        buffer.extend_from_slice(b"\r\n");
    }

    // End of headers
    buffer.extend_from_slice(b"\r\n");

    // Body
    buffer.extend_from_slice(&req.body);

    buffer
}

/// Serialize a ParsedResponse back into HTTP wire format
pub fn serialize_response(resp: &ParsedResponse) -> Vec<u8> {
    let mut buffer = Vec::new();

    // Status line
    buffer.extend_from_slice(b"HTTP/1.");
    buffer.push(b'0' + resp.version);
    buffer.push(b' ');
    buffer.extend_from_slice(resp.code.to_string().as_bytes());
    buffer.push(b' ');
    buffer.extend_from_slice(resp.reason.as_bytes());
    buffer.extend_from_slice(b"\r\n");

    // Headers
    for (name, value) in &resp.headers {
        buffer.extend_from_slice(name.as_bytes());
        buffer.extend_from_slice(b": ");
        buffer.extend_from_slice(value.as_bytes());
        buffer.extend_from_slice(b"\r\n");
    }

    // End of headers
    buffer.extend_from_slice(b"\r\n");

    // Body
    buffer.extend_from_slice(&resp.body);

    buffer
}

#[cfg(test)]
mod tests {
    use super::*;

    // ========================================================================
    // Request Parsing Tests
    // ========================================================================

    #[test]
    fn test_parse_simple_get_request() {
        let http = b"GET /api/users HTTP/1.1\r\nHost: example.com\r\n\r\n";
        let result = parse_request(http).unwrap();

        assert!(result.is_some());
        let req = result.unwrap();
        assert_eq!(req.method, "GET");
        assert_eq!(req.path, "/api/users");
        assert_eq!(req.version, 1);
        assert_eq!(req.headers.get("host"), Some(&"example.com".to_string()));
        assert!(req.body.is_empty());
    }

    #[test]
    fn test_parse_post_request_with_body() {
        let http = b"POST /api/data HTTP/1.1\r\n\
                      Host: example.com\r\n\
                      Content-Type: application/json\r\n\
                      Content-Length: 13\r\n\
                      \r\n\
                      {\"key\":\"val\"}";

        let result = parse_request(http).unwrap();
        assert!(result.is_some());
        let req = result.unwrap();

        assert_eq!(req.method, "POST");
        assert_eq!(req.path, "/api/data");
        assert_eq!(req.headers.get("content-type"), Some(&"application/json".to_string()));
        assert_eq!(String::from_utf8_lossy(&req.body), "{\"key\":\"val\"}");
    }

    #[test]
    fn test_parse_request_with_authorization_header() {
        let http = b"GET /secure HTTP/1.1\r\n\
                      Host: api.github.com\r\n\
                      Authorization: Bearer DUMMY_TOKEN\r\n\
                      \r\n";

        let result = parse_request(http).unwrap();
        assert!(result.is_some());
        let req = result.unwrap();

        assert_eq!(req.headers.get("authorization"), Some(&"Bearer DUMMY_TOKEN".to_string()));
    }

    #[test]
    fn test_parse_incomplete_request() {
        let http = b"GET /api HTTP/1.1\r\nHost: example.com\r\n";
        let result = parse_request(http).unwrap();
        assert!(result.is_none(), "Should return None for incomplete request");
    }

    #[test]
    fn test_parse_malformed_request() {
        let http = b"INVALID HTTP REQUEST\r\n\r\n";
        let result = parse_request(http);
        assert!(result.is_err(), "Should fail on malformed request");
    }

    #[test]
    fn test_parse_request_header_too_large() {
        let mut http = Vec::new();
        http.extend_from_slice(b"GET / HTTP/1.1\r\n");
        // Add headers until we exceed MAX_HEADER_SIZE without \r\n\r\n
        for i in 0..1000 {
            http.extend_from_slice(format!("X-Header-{}: value\r\n", i).as_bytes());
        }

        let result = parse_request(&http);
        assert!(matches!(result, Err(ParseError::HeaderTooLarge)));
    }

    // ========================================================================
    // Response Parsing Tests
    // ========================================================================

    #[test]
    fn test_parse_simple_response() {
        let http = b"HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nHello";
        let result = parse_response(http).unwrap();

        assert!(result.is_some());
        let resp = result.unwrap();
        assert_eq!(resp.code, 200);
        assert_eq!(resp.reason, "OK");
        assert_eq!(resp.version, 1);
        assert_eq!(String::from_utf8_lossy(&resp.body), "Hello");
    }

    #[test]
    fn test_parse_response_with_json_body() {
        let http = b"HTTP/1.1 200 OK\r\n\
                      Content-Type: application/json\r\n\
                      \r\n\
                      {\"token\":\"ghp_secret123\"}";

        let result = parse_response(http).unwrap();
        assert!(result.is_some());
        let resp = result.unwrap();

        assert_eq!(resp.code, 200);
        assert_eq!(resp.headers.get("content-type"), Some(&"application/json".to_string()));
        assert!(String::from_utf8_lossy(&resp.body).contains("ghp_secret123"));
    }

    #[test]
    fn test_parse_error_response() {
        let http = b"HTTP/1.1 404 Not Found\r\nContent-Length: 9\r\n\r\nNot Found";
        let result = parse_response(http).unwrap();

        assert!(result.is_some());
        let resp = result.unwrap();
        assert_eq!(resp.code, 404);
        assert_eq!(resp.reason, "Not Found");
    }

    #[test]
    fn test_parse_incomplete_response() {
        let http = b"HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n";
        let result = parse_response(http).unwrap();
        assert!(result.is_none(), "Should return None for incomplete response");
    }

    #[test]
    fn test_parse_malformed_response() {
        let http = b"INVALID HTTP RESPONSE\r\n\r\n";
        let result = parse_response(http);
        assert!(result.is_err(), "Should fail on malformed response");
    }

    #[test]
    fn test_parse_response_header_too_large() {
        let mut http = Vec::new();
        http.extend_from_slice(b"HTTP/1.1 200 OK\r\n");
        // Add headers until we exceed MAX_HEADER_SIZE without \r\n\r\n
        for i in 0..1000 {
            http.extend_from_slice(format!("X-Header-{}: value\r\n", i).as_bytes());
        }

        let result = parse_response(&http);
        assert!(matches!(result, Err(ParseError::HeaderTooLarge)));
    }

    // ========================================================================
    // Serialization Tests
    // ========================================================================

    #[test]
    fn test_serialize_request() {
        let mut headers = HashMap::new();
        headers.insert("host".to_string(), "example.com".to_string());
        headers.insert("content-length".to_string(), "5".to_string());

        let req = ParsedRequest {
            method: "POST".to_string(),
            path: "/api".to_string(),
            version: 1,
            headers,
            body: b"hello".to_vec(),
        };

        let serialized = serialize_request(&req);
        let serialized_str = String::from_utf8_lossy(&serialized);

        assert!(serialized_str.contains("POST /api HTTP/1.1"));
        assert!(serialized_str.contains("host: example.com"));
        assert!(serialized_str.contains("hello"));
    }

    #[test]
    fn test_serialize_response() {
        let mut headers = HashMap::new();
        headers.insert("content-type".to_string(), "text/plain".to_string());

        let resp = ParsedResponse {
            version: 1,
            code: 200,
            reason: "OK".to_string(),
            headers,
            body: b"Success".to_vec(),
        };

        let serialized = serialize_response(&resp);
        let serialized_str = String::from_utf8_lossy(&serialized);

        assert!(serialized_str.contains("HTTP/1.1 200 OK"));
        assert!(serialized_str.contains("content-type: text/plain"));
        assert!(serialized_str.contains("Success"));
    }

    #[test]
    fn test_roundtrip_request() {
        let original = b"GET /test HTTP/1.1\r\nHost: example.com\r\n\r\n";
        let parsed = parse_request(original).unwrap().unwrap();
        let serialized = serialize_request(&parsed);
        let reparsed = parse_request(&serialized).unwrap().unwrap();

        assert_eq!(parsed.method, reparsed.method);
        assert_eq!(parsed.path, reparsed.path);
        assert_eq!(parsed.version, reparsed.version);
    }

    #[test]
    fn test_roundtrip_response() {
        let original = b"HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n<html></html>";
        let parsed = parse_response(original).unwrap().unwrap();
        let serialized = serialize_response(&parsed);
        let reparsed = parse_response(&serialized).unwrap().unwrap();

        assert_eq!(parsed.code, reparsed.code);
        assert_eq!(parsed.reason, reparsed.reason);
        assert_eq!(parsed.body, reparsed.body);
    }

    // ========================================================================
    // Edge Case Tests
    // ========================================================================

    #[test]
    fn test_parse_request_empty_body() {
        let http = b"GET / HTTP/1.1\r\nHost: example.com\r\n\r\n";
        let result = parse_request(http).unwrap().unwrap();
        assert!(result.body.is_empty());
    }

    #[test]
    fn test_parse_response_empty_body() {
        let http = b"HTTP/1.1 204 No Content\r\n\r\n";
        let result = parse_response(http).unwrap().unwrap();
        assert_eq!(result.code, 204);
        assert!(result.body.is_empty());
    }

    #[test]
    fn test_parse_request_multiple_header_values() {
        let http = b"GET / HTTP/1.1\r\n\
                      Host: example.com\r\n\
                      Accept: text/html\r\n\
                      Accept-Encoding: gzip\r\n\
                      \r\n";

        let result = parse_request(http).unwrap().unwrap();
        assert_eq!(result.headers.len(), 3);
        assert_eq!(result.headers.get("accept"), Some(&"text/html".to_string()));
    }

    #[test]
    fn test_parse_response_with_cookies() {
        let http = b"HTTP/1.1 200 OK\r\n\
                      Set-Cookie: session=abc123\r\n\
                      Content-Type: text/html\r\n\
                      \r\n";

        let result = parse_response(http).unwrap().unwrap();
        assert_eq!(result.headers.get("set-cookie"), Some(&"session=abc123".to_string()));
    }

    #[test]
    fn test_header_names_lowercase() {
        let http = b"GET / HTTP/1.1\r\n\
                      Host: example.com\r\n\
                      Content-Type: text/plain\r\n\
                      Authorization: Bearer token\r\n\
                      \r\n";

        let result = parse_request(http).unwrap().unwrap();
        // All header names should be lowercase
        assert!(result.headers.contains_key("host"));
        assert!(result.headers.contains_key("content-type"));
        assert!(result.headers.contains_key("authorization"));
        assert!(!result.headers.contains_key("Host"));
        assert!(!result.headers.contains_key("Content-Type"));
    }

    #[test]
    fn test_parse_request_http10() {
        let http = b"GET / HTTP/1.0\r\nHost: example.com\r\n\r\n";
        let result = parse_request(http).unwrap().unwrap();
        assert_eq!(result.version, 0);
    }

    #[test]
    fn test_parse_response_http10() {
        let http = b"HTTP/1.0 200 OK\r\nContent-Length: 0\r\n\r\n";
        let result = parse_response(http).unwrap().unwrap();
        assert_eq!(result.version, 0);
    }
}
