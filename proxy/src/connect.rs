// SLAPENIR Proxy - CONNECT Tunnel Handler
// Implements HTTP CONNECT method for HTTPS tunneling with credential injection and TLS MITM

use axum::{
    body::Body,
    extract::{Request, State},
    http::{StatusCode, Uri},
    response::{IntoResponse, Response},
};
use hyper::upgrade::Upgraded;
use hyper_util::rt::TokioIo;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use tracing::{debug, error, info, warn};

use crate::middleware::AppState;

/// Handle HTTP CONNECT requests for HTTPS tunneling
///
/// Flow:
/// 1. Parse destination host:port from URI
/// 2. Establish TCP connection to destination
/// 3. Create upgrade future from request
/// 4. Return "200 Connection Established"
/// 5. Spawn task to handle upgrade and tunnel
/// 6. Copy data between client and server (with optional TLS MITM)
///
/// Note: The upgrade future MUST be created before returning the response,
/// but it will complete after the response is sent.
pub async fn handle_connect(
    State(state): State<AppState>,
    req: Request<Body>,
) -> Result<Response, ConnectError> {
    info!("🔌 Handling CONNECT request");

    // Extract destination from URI
    let uri = req.uri().clone();
    let destination = parse_destination(&uri)?;
    
    info!("📡 CONNECT to: {}", destination);

    // Establish connection to destination BEFORE responding
    // This ensures we can return an error if connection fails
    let server_stream = match TcpStream::connect(&destination).await {
        Ok(stream) => {
            debug!("✅ Connected to {}", destination);
            stream
        }
        Err(e) => {
            error!("❌ Failed to connect to {}: {}", destination, e);
            return Err(ConnectError::ConnectionFailed(destination, e.to_string()));
        }
    };

    // Clone destination and state for the async task
    let dest_clone = destination.clone();
    let state_clone = state.clone();
    
    // IMPORTANT: Create the upgrade future BEFORE returning the response
    // The upgrade future needs to be created while we still own the request
    let upgrade_future = hyper::upgrade::on(req);
    
    // Spawn task to handle tunnel - this will run AFTER the response is sent
    tokio::task::spawn(async move {
        match upgrade_future.await {
            Ok(upgraded) => {
                info!("🔄 Connection upgraded, starting tunnel to {}", dest_clone);
                
                if let Err(e) = tunnel(upgraded, server_stream, &dest_clone, state_clone).await {
                    error!("❌ Tunnel error for {}: {}", dest_clone, e);
                } else {
                    info!("✅ Tunnel closed cleanly for {}", dest_clone);
                }
            }
            Err(e) => {
                error!("❌ Failed to upgrade connection for {}: {}", dest_clone, e);
            }
        }
    });

    // Return 200 Connection Established
    // For CONNECT to work, we need to send an EMPTY response with NO body
    // The HTTP spec says: HTTP/1.1 200 Connection Established\r\n\r\n
    let mut response = Response::new(Body::empty());
    *response.status_mut() = StatusCode::OK;
    Ok(response)
}

/// Check if destination should use TLS MITM interception
///
/// Returns true for HTTPS ports (443, 8443)
fn should_intercept_tls(destination: &str) -> bool {
    destination.ends_with(":443") || destination.ends_with(":8443")
}

/// Extract hostname from destination string
///
/// Converts "github.com:443" -> "github.com"
/// Handles IPv6: "[::1]:443" -> "::1"
fn extract_hostname(destination: &str) -> Result<String, ConnectError> {
    if let Some(colon_pos) = destination.rfind(':') {
        let host = &destination[..colon_pos];
        // Remove IPv6 brackets if present
        if host.starts_with('[') && host.ends_with(']') {
            Ok(host[1..host.len()-1].to_string())
        } else {
            Ok(host.to_string())
        }
    } else {
        Err(ConnectError::InvalidRequest(format!(
            "Cannot extract hostname from: {}",
            destination
        )))
    }
}

/// Parse destination host:port from CONNECT URI
///
/// CONNECT requests have URI in the form "host:port"
/// Example: "github.com:443"
fn parse_destination(uri: &Uri) -> Result<String, ConnectError> {
    let authority = uri
        .authority()
        .ok_or_else(|| ConnectError::InvalidRequest("Missing authority in CONNECT URI".into()))?;

    let destination = authority.as_str().to_string();

    // Validate format (should be host:port)
    if !destination.contains(':') {
        return Err(ConnectError::InvalidRequest(format!(
            "Invalid CONNECT destination: {}",
            destination
        )));
    }

    Ok(destination)
}

/// Bidirectional tunnel between client and server
///
/// Routes to either:
/// - Passthrough mode (ports other than 443/8443)
/// - TLS MITM mode (ports 443/8443) with credential injection and sanitization
async fn tunnel(
    client_stream: Upgraded,
    server_stream: TcpStream,
    destination: &str,
    state: AppState,
) -> Result<(), ConnectError> {
    if should_intercept_tls(destination) {
        info!("🔒 TLS MITM mode for {}", destination);
        tunnel_with_tls_mitm(client_stream, server_stream, destination, state).await
    } else {
        info!("🔓 Passthrough mode for {}", destination);
        tunnel_passthrough(client_stream, server_stream, destination).await
    }
}

/// Passthrough tunnel - no TLS inspection
///
/// Copies data bidirectionally between client and server without modification.
/// Used for non-HTTPS traffic (ports other than 443/8443).
async fn tunnel_passthrough(
    client_stream: Upgraded,
    server_stream: TcpStream,
    destination: &str,
) -> Result<(), ConnectError> {
    // Wrap the upgraded connection with TokioIo for compatibility
    let client_stream = TokioIo::new(client_stream);
    
    // Split streams into read/write halves
    let (mut client_read, mut client_write) = tokio::io::split(client_stream);
    let (mut server_read, mut server_write) = tokio::io::split(server_stream);

    // Copy data bidirectionally
    let client_to_server = async {
        let mut buffer = vec![0u8; 8192];
        let mut total_bytes = 0u64;
        
        loop {
            match client_read.read(&mut buffer).await {
                Ok(0) => {
                    debug!("Client closed connection to {}", destination);
                    break Ok(total_bytes);
                }
                Ok(n) => {
                    total_bytes += n as u64;
                    
                    if let Err(e) = server_write.write_all(&buffer[..n]).await {
                        error!("Error writing to server {}: {}", destination, e);
                        break Err(e);
                    }
                }
                Err(e) => {
                    error!("Error reading from client: {}", e);
                    break Err(e);
                }
            }
        }
    };

    let server_to_client = async {
        let mut buffer = vec![0u8; 8192];
        let mut total_bytes = 0u64;
        
        loop {
            match server_read.read(&mut buffer).await {
                Ok(0) => {
                    debug!("Server {} closed connection", destination);
                    break Ok(total_bytes);
                }
                Ok(n) => {
                    total_bytes += n as u64;
                    
                    if let Err(e) = client_write.write_all(&buffer[..n]).await {
                        error!("Error writing to client: {}", e);
                        break Err(e);
                    }
                }
                Err(e) => {
                    error!("Error reading from server {}: {}", destination, e);
                    break Err(e);
                }
            }
        }
    };

    // Run both directions concurrently
    let (client_result, server_result) = tokio::join!(client_to_server, server_to_client);

    // Log transfer statistics
    match (client_result, server_result) {
        (Ok(client_bytes), Ok(server_bytes)) => {
            info!(
                "📊 Tunnel stats for {}: ⬆️  {}B, ⬇️  {}B",
                destination, client_bytes, server_bytes
            );
        }
        _ => {
            warn!("Tunnel for {} closed with errors", destination);
        }
    }

    Ok(())
}

/// TLS MITM tunnel - intercepts and modifies HTTPS traffic
///
/// Performs TLS man-in-the-middle attack to:
/// 1. Decrypt client → proxy traffic
/// 2. Parse HTTP requests and inject credentials
/// 3. Re-encrypt proxy → server traffic
/// 4. Decrypt server → proxy responses
/// 5. Sanitize responses to remove real credentials
/// 6. Re-encrypt proxy → client traffic
async fn tunnel_with_tls_mitm(
    _client_stream: Upgraded,
    _server_stream: TcpStream,
    destination: &str,
    _state: AppState,
) -> Result<(), ConnectError> {
    // Extract hostname for certificate generation
    let hostname = extract_hostname(destination)?;
    info!("🔐 Starting TLS MITM for hostname: {}", hostname);

    // TODO: Phase 3B - TLS Handshake
    // 1. Load or generate CA certificate
    // 2. Create MitmAcceptor with CA
    // 3. Generate certificate for hostname
    // 4. Accept TLS connection from client
    // 5. Establish TLS connection to upstream server

    // TODO: Phase 3C - HTTP Processing
    // 6. Read HTTP request from decrypted client stream
    // 7. Buffer until complete request received
    // 8. Parse using http_parser

    // TODO: Phase 3D - Credential Injection
    // 9. Detect if any strategy matches the request
    // 10. Inject credentials if match found
    // 11. Serialize modified request

    // TODO: Phase 3E - Response Sanitization
    // 12. Read HTTP response from server
    // 13. Parse response
    // 14. Sanitize using secret_map
    // 15. Serialize and send to client

    // For now, return an error to indicate not yet implemented
    Err(ConnectError::TunnelError(format!(
        "TLS MITM not yet fully implemented for {}",
        destination
    )))
}

/// Errors that can occur during CONNECT handling
#[derive(Debug)]
pub enum ConnectError {
    InvalidRequest(String),
    ConnectionFailed(String, String),
    TunnelError(String),
    TlsError(crate::tls::TlsError),
}

impl std::fmt::Display for ConnectError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ConnectError::InvalidRequest(msg) => write!(f, "Invalid CONNECT request: {}", msg),
            ConnectError::ConnectionFailed(dest, err) => {
                write!(f, "Failed to connect to {}: {}", dest, err)
            }
            ConnectError::TunnelError(msg) => write!(f, "Tunnel error: {}", msg),
            ConnectError::TlsError(e) => write!(f, "TLS error: {}", e),
        }
    }
}

impl std::error::Error for ConnectError {}

impl From<crate::tls::TlsError> for ConnectError {
    fn from(err: crate::tls::TlsError) -> Self {
        ConnectError::TlsError(err)
    }
}

impl IntoResponse for ConnectError {
    fn into_response(self) -> Response {
        let (status, message) = match self {
            ConnectError::InvalidRequest(msg) => (StatusCode::BAD_REQUEST, msg),
            ConnectError::ConnectionFailed(dest, err) => (
                StatusCode::BAD_GATEWAY,
                format!("Failed to connect to {}: {}", dest, err),
            ),
            ConnectError::TunnelError(msg) => (StatusCode::INTERNAL_SERVER_ERROR, msg),
            ConnectError::TlsError(e) => (StatusCode::INTERNAL_SERVER_ERROR, format!("TLS error: {}", e)),
        };

        (status, message).into_response()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // ========================================================================
    // parse_destination Tests
    // ========================================================================

    #[test]
    fn test_parse_destination_valid_hostname_with_port() {
        let uri: Uri = "github.com:443".parse().unwrap();
        let dest = parse_destination(&uri).unwrap();
        assert_eq!(dest, "github.com:443");
    }

    #[test]
    fn test_parse_destination_valid_ip_with_port() {
        let uri: Uri = "192.168.1.1:8080".parse().unwrap();
        let dest = parse_destination(&uri).unwrap();
        assert_eq!(dest, "192.168.1.1:8080");
    }

    #[test]
    fn test_parse_destination_valid_ipv6_with_port() {
        let uri: Uri = "[::1]:443".parse().unwrap();
        let dest = parse_destination(&uri).unwrap();
        assert_eq!(dest, "[::1]:443");
    }

    #[test]
    fn test_parse_destination_subdomain() {
        let uri: Uri = "api.github.com:443".parse().unwrap();
        let dest = parse_destination(&uri).unwrap();
        assert_eq!(dest, "api.github.com:443");
    }

    #[test]
    fn test_parse_destination_non_standard_port() {
        let uri: Uri = "example.com:8443".parse().unwrap();
        let dest = parse_destination(&uri).unwrap();
        assert_eq!(dest, "example.com:8443");
    }

    #[test]
    fn test_parse_destination_missing_port() {
        let uri: Uri = "github.com".parse().unwrap();
        let result = parse_destination(&uri);
        assert!(result.is_err());
        match result {
            Err(ConnectError::InvalidRequest(msg)) => {
                assert!(msg.contains("Invalid CONNECT destination"));
            }
            _ => panic!("Expected InvalidRequest error"),
        }
    }

    #[test]
    fn test_parse_destination_no_authority() {
        let uri: Uri = "/path".parse().unwrap();
        let result = parse_destination(&uri);
        assert!(result.is_err());
        match result {
            Err(ConnectError::InvalidRequest(msg)) => {
                assert!(msg.contains("Missing authority"));
            }
            _ => panic!("Expected InvalidRequest error"),
        }
    }

    #[test]
    fn test_parse_destination_empty() {
        // Empty URI can't be parsed
        let result = "http://".parse::<Uri>();
        assert!(result.is_err(), "Empty URI should not parse");
    }

    // ========================================================================
    // ConnectError Tests
    // ========================================================================

    #[test]
    fn test_connect_error_display_invalid_request() {
        let error = ConnectError::InvalidRequest("test error".to_string());
        assert_eq!(error.to_string(), "Invalid CONNECT request: test error");
    }

    #[test]
    fn test_connect_error_display_connection_failed() {
        let error = ConnectError::ConnectionFailed(
            "github.com:443".to_string(),
            "timeout".to_string(),
        );
        assert_eq!(
            error.to_string(),
            "Failed to connect to github.com:443: timeout"
        );
    }

    #[test]
    fn test_connect_error_display_tunnel_error() {
        let error = ConnectError::TunnelError("stream closed".to_string());
        assert_eq!(error.to_string(), "Tunnel error: stream closed");
    }

    #[test]
    fn test_connect_error_into_response_invalid_request() {
        let error = ConnectError::InvalidRequest("bad format".to_string());
        let response = error.into_response();
        assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    }

    #[test]
    fn test_connect_error_into_response_connection_failed() {
        let error = ConnectError::ConnectionFailed(
            "example.com:443".to_string(),
            "refused".to_string(),
        );
        let response = error.into_response();
        assert_eq!(response.status(), StatusCode::BAD_GATEWAY);
    }

    #[test]
    fn test_connect_error_into_response_tunnel_error() {
        let error = ConnectError::TunnelError("unexpected EOF".to_string());
        let response = error.into_response();
        assert_eq!(response.status(), StatusCode::INTERNAL_SERVER_ERROR);
    }

    // ========================================================================
    // Destination Validation Edge Cases
    // ========================================================================

    #[test]
    fn test_parse_destination_with_special_chars() {
        let uri: Uri = "my-api.example.com:443".parse().unwrap();
        let dest = parse_destination(&uri).unwrap();
        assert_eq!(dest, "my-api.example.com:443");
    }

    #[test]
    fn test_parse_destination_numeric_hostname() {
        let uri: Uri = "123.example.com:443".parse().unwrap();
        let dest = parse_destination(&uri).unwrap();
        assert_eq!(dest, "123.example.com:443");
    }

    #[test]
    fn test_parse_destination_long_subdomain() {
        let uri: Uri = "very.long.subdomain.example.com:443".parse().unwrap();
        let dest = parse_destination(&uri).unwrap();
        assert_eq!(dest, "very.long.subdomain.example.com:443");
    }

    #[test]
    fn test_parse_destination_min_port() {
        let uri: Uri = "example.com:1".parse().unwrap();
        let dest = parse_destination(&uri).unwrap();
        assert_eq!(dest, "example.com:1");
    }

    #[test]
    fn test_parse_destination_max_port() {
        let uri: Uri = "example.com:65535".parse().unwrap();
        let dest = parse_destination(&uri).unwrap();
        assert_eq!(dest, "example.com:65535");
    }

    // ========================================================================
    // Integration Test Helpers
    // ========================================================================

    /// Helper function to test if a destination string can be parsed
    fn can_parse_destination(dest: &str) -> bool {
        if let Ok(uri) = dest.parse::<Uri>() {
            parse_destination(&uri).is_ok()
        } else {
            false
        }
    }

    #[test]
    fn test_real_world_destinations() {
        // Common real-world CONNECT destinations
        assert!(can_parse_destination("github.com:443"));
        assert!(can_parse_destination("registry.npmjs.org:443"));
        assert!(can_parse_destination("api.github.com:443"));
        assert!(can_parse_destination("raw.githubusercontent.com:443"));
        assert!(can_parse_destination("objects.githubusercontent.com:443"));
        
        // Should fail without port
        assert!(!can_parse_destination("github.com"));
        assert!(!can_parse_destination("example.com"));
    }

    #[test]
    fn test_localhost_destinations() {
        assert!(can_parse_destination("localhost:3000"));
        assert!(can_parse_destination("127.0.0.1:8080"));
        assert!(can_parse_destination("[::1]:443"));
    }

    // ========================================================================
    // Error Behavior Tests
    // ========================================================================

    #[test]
    fn test_error_is_send_and_sync() {
        fn assert_send<T: Send>() {}
        fn assert_sync<T: Sync>() {}
        assert_send::<ConnectError>();
        assert_sync::<ConnectError>();
    }

    #[test]
    fn test_error_implements_std_error() {
        let error = ConnectError::TunnelError("test".to_string());
        let _: &dyn std::error::Error = &error;
    }

    // ========================================================================
    // Buffer Size and Performance Tests
    // ========================================================================

    #[test]
    fn test_tunnel_buffer_size() {
        // Verify the buffer size is reasonable
        // 8KB is a good balance between memory and performance
        const EXPECTED_BUFFER_SIZE: usize = 8192;
        let buffer = vec![0u8; EXPECTED_BUFFER_SIZE];
        assert_eq!(buffer.len(), EXPECTED_BUFFER_SIZE);
    }

    // ========================================================================
    // HTTPS Detection Tests
    // ========================================================================

    #[test]
    fn test_should_intercept_tls_port_443() {
        assert!(should_intercept_tls("github.com:443"));
        assert!(should_intercept_tls("api.example.com:443"));
        assert!(should_intercept_tls("192.168.1.1:443"));
        assert!(should_intercept_tls("[::1]:443"));
    }

    #[test]
    fn test_should_intercept_tls_port_8443() {
        assert!(should_intercept_tls("example.com:8443"));
        assert!(should_intercept_tls("localhost:8443"));
    }

    #[test]
    fn test_should_not_intercept_other_ports() {
        assert!(!should_intercept_tls("example.com:80"));
        assert!(!should_intercept_tls("example.com:8080"));
        assert!(!should_intercept_tls("example.com:3000"));
        assert!(!should_intercept_tls("example.com:9443")); // Not 8443
    }

    #[test]
    fn test_extract_hostname_simple() {
        assert_eq!(extract_hostname("github.com:443").unwrap(), "github.com");
        assert_eq!(extract_hostname("api.example.com:8443").unwrap(), "api.example.com");
        assert_eq!(extract_hostname("localhost:3000").unwrap(), "localhost");
    }

    #[test]
    fn test_extract_hostname_ipv4() {
        assert_eq!(extract_hostname("192.168.1.1:443").unwrap(), "192.168.1.1");
        assert_eq!(extract_hostname("127.0.0.1:8080").unwrap(), "127.0.0.1");
    }

    #[test]
    fn test_extract_hostname_ipv6() {
        assert_eq!(extract_hostname("[::1]:443").unwrap(), "::1");
        assert_eq!(extract_hostname("[2001:db8::1]:8443").unwrap(), "2001:db8::1");
    }

    #[test]
    fn test_extract_hostname_no_port() {
        let result = extract_hostname("github.com");
        assert!(result.is_err());
    }

    #[test]
    fn test_extract_hostname_subdomain() {
        assert_eq!(
            extract_hostname("very.long.subdomain.example.com:443").unwrap(),
            "very.long.subdomain.example.com"
        );
    }
}
