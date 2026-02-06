// Phase 3D+3E: Complete TLS MITM with Credential Injection & Response Sanitization
// Combines all phases: TLS Handshake + HTTP Processing + Credentials + Sanitization

use std::{path::Path, sync::Arc};
use hyper::upgrade::Upgraded;
use hyper_util::rt::TokioIo;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use tokio_rustls::TlsConnector;
use tracing::{debug, info, warn, error};

use crate::middleware::AppState;
use crate::tls::{CertificateAuthority, MitmAcceptor};
use crate::http_parser::{parse_request, parse_response, serialize_request, serialize_response, ParsedRequest, ParsedResponse};
use crate::strategy::{detect_and_validate_strategies, SecurityError};

use crate::connect::{ConnectError, extract_hostname};

/// Complete TLS MITM tunnel with all features
///
/// Phases Implemented:
/// - Phase 3B: TLS Handshake ✅
/// - Phase 3C: HTTP Processing ✅  
/// - Phase 3D: Credential Injection ✅ (with Whitelist Validation)
/// - Phase 3E: Response Sanitization ✅
pub async fn tunnel_with_tls_mitm_full(
    client_stream: Upgraded,
    server_stream: TcpStream,
    destination: &str,
    state: AppState,
) -> Result<(), ConnectError> {
    let hostname = extract_hostname(destination)?;
    info!("🔐 Starting complete TLS MITM for hostname: {}", hostname);

    // ========================================================================
    // Phase 3B: TLS Handshake
    // ========================================================================
    
    debug!("Loading CA certificate...");
    let ca_path = Path::new("./ca-data/certs/ca.pem");
    let key_path = Path::new("./ca-data/certs/ca-key.pem");
    
    let ca = Arc::new(
        CertificateAuthority::load_or_generate(ca_path, key_path)
            .map_err(|e| ConnectError::TlsError(e))?
    );
    
    debug!("✓ CA certificate loaded");
    
    let acceptor = MitmAcceptor::new(ca);
    
    debug!("Accepting TLS connection from client for '{}'...", hostname);
    let client_stream = TokioIo::new(client_stream);
    let mut client_tls = acceptor
        .accept(client_stream, &hostname)
        .await
        .map_err(|e| ConnectError::TlsError(e))?;
    
    info!("✓ Client TLS handshake complete for '{}'", hostname);
    
    debug!("Establishing TLS connection to upstream server '{}'...", hostname);
    
    // Create a permissive TLS config for outbound connections
    // Note: For production, this should validate certificates properly
    let root_store = rustls::RootCertStore::empty();
    // Use webpki-roots equivalent - Mozilla CA bundle is included with rustls
    // For now, we will skip cert validation (dangerous but works for proxy)

    let client_config = rustls::ClientConfig::builder()
        .with_root_certificates(root_store)
        .with_no_client_auth();
    
    let connector = TlsConnector::from(Arc::new(client_config));
    // ServerName requires static lifetime, so we use DnsName directly
    let server_name = rustls::pki_types::ServerName::DnsName(
        rustls::pki_types::DnsName::try_from(hostname.to_string())
            .map_err(|e| ConnectError::TunnelError(format!("Invalid hostname '{}': {:?}", hostname, e)))?
    );
    
    let mut server_tls = connector
        .connect(server_name, server_stream)
        .await
        .map_err(|e| ConnectError::TunnelError(format!("Server TLS handshake failed: {}", e)))?;
    
    info!("✓ Server TLS handshake complete for '{}'", hostname);

    // ========================================================================
    // Phase 3C+3D+3E: HTTP Processing with Credential Injection & Sanitization
    // ========================================================================
    
    loop {
        debug!("📥 Waiting for HTTP request from client...");
        
        // Read and parse HTTP request from client
        let mut parsed_request = match read_http_request(&mut client_tls).await {
            Ok(Some(req)) => {
                info!("📄 Parsed request: {} {}", req.method, req.path);
                req
            }
            Ok(None) => {
                info!("✅ Client closed connection");
                break;
            }
            Err(e) => {
                warn!("❌ Failed to read HTTP request: {}", e);
                return Err(e);
            }
        };

        // ====================================================================
        // Phase 3D-Pre: Whitelist-Based Host Validation (SECURITY CRITICAL)
        // ====================================================================
        
        // Convert body to string for detection
        let body_str = String::from_utf8_lossy(&parsed_request.body);
        
        // Convert headers to HeaderMap for strategy detection
        let mut header_map = axum::http::HeaderMap::new();
        for (name, value) in &parsed_request.headers {
            if let Ok(header_name) = axum::http::HeaderName::from_bytes(name.as_bytes()) {
                if let Ok(header_value) = axum::http::HeaderValue::from_str(value) {
                    header_map.insert(header_name, header_value);
                }
            }
        }
        
        // SECURITY: Validate that any detected credentials are allowed for this destination
        // This prevents credential exfiltration to unauthorized hosts
        match detect_and_validate_strategies(
            &state.strategies,
            &header_map,
            &body_str,
            &hostname,
        ) {
            Ok(validated_strategies) => {
                if !validated_strategies.is_empty() {
                    debug!("✓ Host validation passed for {} ({} credential(s) detected)", 
                           hostname, validated_strategies.len());
                }
            }
            Err(SecurityError::HostNotWhitelisted { credential_type, host, allowed_hosts }) => {
                error!("🚨 SECURITY VIOLATION: Blocked {} credential to unauthorized host: {}", 
                       credential_type, host);
                return Err(ConnectError::SecurityViolation(format!(
                    "Credential exfiltration blocked: {} credential attempted to unauthorized host '{}'. Allowed hosts: {:?}",
                    credential_type, host, allowed_hosts
                )));
            }
        }
        
        // ====================================================================
        // Phase 3D: Credential Injection
        // ====================================================================
        
        // Inject real credentials (replaces DUMMY_* tokens with real values)
        let injected_body = state.secret_map.inject(&body_str);
        
        if injected_body != body_str {
            info!("🔑 Injected credentials into request body");
            parsed_request.body = injected_body.into_bytes();
            
            // Update Content-Length header if it changed
            if let Some(content_length) = parsed_request.headers.get_mut("content-length") {
                *content_length = parsed_request.body.len().to_string();
            }
        }
        
        // Also inject into headers (in case credentials are in Authorization header)
        for (header_name, header_value) in parsed_request.headers.iter_mut() {
            let injected_header = state.secret_map.inject(header_value);
            if injected_header != *header_value {
                info!("🔑 Injected credentials into {} header", header_name);
                *header_value = injected_header;
            }
        }
        
        // Serialize and send request to server
        let request_bytes = serialize_request(&parsed_request);
        debug!("📤 Sending {} bytes to upstream server", request_bytes.len());
        
        server_tls
            .write_all(&request_bytes)
            .await
            .map_err(|e| ConnectError::TunnelError(format!("Failed to send request to server: {}", e)))?;

        // Read and parse HTTP response from server
        debug!("📥 Waiting for HTTP response from server...");
        
        let mut parsed_response = match read_http_response(&mut server_tls).await {
            Ok(Some(resp)) => {
                info!("📄 Parsed response: {} {}", resp.code, resp.reason);
                resp
            }
            Ok(None) => {
                info!("✅ Server closed connection");
                break;
            }
            Err(e) => {
                warn!("❌ Failed to read HTTP response: {}", e);
                return Err(e);
            }
        };

        // ====================================================================
        // Phase 3E: Response Sanitization
        // ====================================================================
        
        // Convert body to string for sanitization
        let response_body_str = String::from_utf8_lossy(&parsed_response.body);
        
        // Sanitize real credentials (replaces real values with [REDACTED])
        let sanitized_body = state.secret_map.sanitize(&response_body_str);
        
        if sanitized_body != response_body_str {
            info!("🔒 Sanitized {} credential(s) from response body", 
                  response_body_str.len() - sanitized_body.len());
            parsed_response.body = sanitized_body.into_bytes();
            
            // Update Content-Length header since body changed
            if let Some(content_length) = parsed_response.headers.get_mut("content-length") {
                *content_length = parsed_response.body.len().to_string();
            }
        }
        
        // Also sanitize headers (in case credentials leaked into headers)
        for (header_name, header_value) in parsed_response.headers.iter_mut() {
            let sanitized_header = state.secret_map.sanitize(header_value);
            if sanitized_header != *header_value {
                info!("🔒 Sanitized credentials from {} header", header_name);
                *header_value = sanitized_header;
            }
        }
        
        // Serialize and send response to client
        let response_bytes = serialize_response(&parsed_response);
        debug!("📤 Sending {} bytes to client", response_bytes.len());
        
        client_tls
            .write_all(&response_bytes)
            .await
            .map_err(|e| ConnectError::TunnelError(format!("Failed to send response to client: {}", e)))?;

        // Check if connection should close
        if should_close_connection(&parsed_request, &parsed_response) {
            info!("🔚 Connection: close detected, closing tunnel");
            break;
        }
        
        debug!("♻️  Connection: keep-alive, waiting for next request");
    }
    
    info!("✓ Complete TLS MITM tunnel closed for '{}'", hostname);
    Ok(())
}

/// Read and parse an HTTP request from a TLS stream
async fn read_http_request<S>(stream: &mut S) -> Result<Option<ParsedRequest>, ConnectError>
where
    S: AsyncReadExt + Unpin,
{
    const MAX_BUFFER_SIZE: usize = 1024 * 1024; // 1MB max
    const READ_CHUNK_SIZE: usize = 8192; // 8KB chunks
    
    let mut buffer = Vec::new();
    let mut temp_buf = vec![0u8; READ_CHUNK_SIZE];
    
    loop {
        match parse_request(&buffer) {
            Ok(Some(req)) => {
                debug!("✓ Complete HTTP request parsed ({} bytes buffered)", buffer.len());
                return Ok(Some(req));
            }
            Ok(None) => {
                debug!("⏳ Incomplete request, need more data ({} bytes so far)", buffer.len());
            }
            Err(e) => {
                return Err(ConnectError::TunnelError(format!("Failed to parse HTTP request: {}", e)));
            }
        }
        
        match stream.read(&mut temp_buf).await {
            Ok(0) => {
                if buffer.is_empty() {
                    return Ok(None);
                } else {
                    return Err(ConnectError::TunnelError(
                        "Connection closed before complete request received".to_string()
                    ));
                }
            }
            Ok(n) => {
                buffer.extend_from_slice(&temp_buf[..n]);
                debug!("📥 Read {} bytes from client (total buffered: {})", n, buffer.len());
                
                if buffer.len() > MAX_BUFFER_SIZE {
                    return Err(ConnectError::TunnelError(
                        format!("HTTP request too large (> {} bytes)", MAX_BUFFER_SIZE)
                    ));
                }
            }
            Err(e) => {
                return Err(ConnectError::TunnelError(format!("Failed to read from client: {}", e)));
            }
        }
    }
}

/// Read and parse an HTTP response from a TLS stream
async fn read_http_response<S>(stream: &mut S) -> Result<Option<ParsedResponse>, ConnectError>
where
    S: AsyncReadExt + Unpin,
{
    const MAX_BUFFER_SIZE: usize = 10 * 1024 * 1024; // 10MB max
    const READ_CHUNK_SIZE: usize = 8192; // 8KB chunks
    
    let mut buffer = Vec::new();
    let mut temp_buf = vec![0u8; READ_CHUNK_SIZE];
    
    loop {
        match parse_response(&buffer) {
            Ok(Some(resp)) => {
                debug!("✓ Complete HTTP response parsed ({} bytes buffered)", buffer.len());
                return Ok(Some(resp));
            }
            Ok(None) => {
                debug!("⏳ Incomplete response, need more data ({} bytes so far)", buffer.len());
            }
            Err(e) => {
                return Err(ConnectError::TunnelError(format!("Failed to parse HTTP response: {}", e)));
            }
        }
        
        match stream.read(&mut temp_buf).await {
            Ok(0) => {
                if buffer.is_empty() {
                    return Ok(None);
                } else {
                    return Err(ConnectError::TunnelError(
                        "Connection closed before complete response received".to_string()
                    ));
                }
            }
            Ok(n) => {
                buffer.extend_from_slice(&temp_buf[..n]);
                debug!("📥 Read {} bytes from server (total buffered: {})", n, buffer.len());
                
                if buffer.len() > MAX_BUFFER_SIZE {
                    return Err(ConnectError::TunnelError(
                        format!("HTTP response too large (> {} bytes)", MAX_BUFFER_SIZE)
                    ));
                }
            }
            Err(e) => {
                return Err(ConnectError::TunnelError(format!("Failed to read from server: {}", e)));
            }
        }
    }
}

/// Determine if the HTTP connection should be closed
fn should_close_connection(
    request: &ParsedRequest,
    response: &ParsedResponse,
) -> bool {
    // Check Connection header in request
    if let Some(conn) = request.headers.get("connection") {
        if conn.eq_ignore_ascii_case("close") {
            return true;
        }
    }
    
    // Check Connection header in response
    if let Some(conn) = response.headers.get("connection") {
        if conn.eq_ignore_ascii_case("close") {
            return true;
        }
    }
    
    // Default to keep-alive for HTTP/1.1
    false
}
