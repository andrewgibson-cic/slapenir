// Phase 3C: HTTP Processing for TLS MITM
// Adds HTTP request/response parsing to Phase 3B TLS handshake

use std::{path::Path, sync::Arc};
use hyper::upgrade::Upgraded;
use hyper_util::rt::TokioIo;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use tokio_rustls::{TlsConnector, TlsStream};
use rustls::pki_types::ServerName;
use tracing::{debug, info, warn};

use crate::middleware::AppState;
use crate::tls::{CertificateAuthority, MitmAcceptor};
use crate::http_parser::{parse_request, parse_response, serialize_request, serialize_response};

use super::{ConnectError, extract_hostname};

/// TLS MITM tunnel with HTTP processing
///
/// Phase 3C Implementation: HTTP Request/Response Parsing
/// - Phase 3B: TLS handshake (client + server) ✅
/// - Phase 3C: HTTP message parsing and forwarding ✅
/// - TODO Phase 3D: Credential injection
/// - TODO Phase 3E: Response sanitization
pub async fn tunnel_with_tls_mitm_http(
    client_stream: Upgraded,
    server_stream: TcpStream,
    destination: &str,
    _state: AppState,
) -> Result<(), ConnectError> {
    // Extract hostname for certificate generation
    let hostname = extract_hostname(destination)?;
    info!("🔐 Starting TLS MITM with HTTP processing for hostname: {}", hostname);

    // ========================================================================
    // Phase 3B: TLS Handshake (COMPLETE)
    // ========================================================================
    
    // Step 1: Load or generate CA certificate
    debug!("Loading CA certificate...");
    let ca_path = Path::new("./ca-data/certs/ca.pem");
    let key_path = Path::new("./ca-data/certs/ca-key.pem");
    
    let ca = Arc::new(
        CertificateAuthority::load_or_generate(ca_path, key_path)
            .map_err(|e| ConnectError::TlsError(e))?
    );
    
    debug!("✓ CA certificate loaded");
    
    // Step 2: Create MITM acceptor for client-side TLS
    let acceptor = MitmAcceptor::new(ca);
    
    // Step 3: Accept TLS connection from client (decrypt client's traffic)
    debug!("Accepting TLS connection from client for '{}'...", hostname);
    let client_stream = TokioIo::new(client_stream);
    let mut client_tls = acceptor
        .accept(client_stream, &hostname)
        .await
        .map_err(|e| ConnectError::TlsError(e))?;
    
    info!("✓ Client TLS handshake complete for '{}'", hostname);
    
    // Step 4: Establish TLS connection to upstream server
    debug!("Establishing TLS connection to upstream server '{}'...", hostname);
    
    let mut root_store = rustls::RootCertStore::empty();
    for cert in webpki_roots::TLS_SERVER_ROOTS.iter() {
        root_store.roots.push(cert.clone());
    }
    
    let client_config = rustls::ClientConfig::builder()
        .with_root_certificates(root_store)
        .with_no_client_auth();
    
    let connector = TlsConnector::from(Arc::new(client_config));
    let server_name = ServerName::try_from(hostname.as_str())
        .map_err(|e| ConnectError::TunnelError(format!("Invalid hostname '{}': {}", hostname, e)))?;
    
    let mut server_tls = connector
        .connect(server_name, server_stream)
        .await
        .map_err(|e| ConnectError::TunnelError(format!("Server TLS handshake failed: {}", e)))?;
    
    info!("✓ Server TLS handshake complete for '{}'", hostname);

    // ========================================================================
    // Phase 3C: HTTP Processing (NEW)
    // ========================================================================
    
    // Process HTTP requests and responses in a loop
    // Each iteration handles one request/response pair
    loop {
        debug!("📥 Waiting for HTTP request from client...");
        
        // Read and parse HTTP request from client
        let parsed_request = match read_http_request(&mut client_tls).await {
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

        // TODO Phase 3D: Inject credentials here
        // For now, forward request as-is
        
        // Serialize and send request to server
        let request_bytes = serialize_request(&parsed_request);
        debug!("📤 Sending {} bytes to upstream server", request_bytes.len());
        
        server_tls
            .write_all(&request_bytes)
            .await
            .map_err(|e| ConnectError::TunnelError(format!("Failed to send request to server: {}", e)))?;

        // Read and parse HTTP response from server
        debug!("📥 Waiting for HTTP response from server...");
        
        let parsed_response = match read_http_response(&mut server_tls).await {
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

        // TODO Phase 3E: Sanitize response here
        // For now, forward response as-is
        
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
    
    info!("✓ TLS MITM tunnel with HTTP processing closed for '{}'", hostname);
    Ok(())
}

/// Read and parse an HTTP request from a TLS stream
///
/// Returns:
/// - Ok(Some(ParsedRequest)) if a complete request was read
/// - Ok(None) if the stream was closed (EOF)
/// - Err if there was an error reading or parsing
async fn read_http_request<S>(stream: &mut S) -> Result<Option<crate::http_parser::ParsedRequest>, ConnectError>
where
    S: AsyncReadExt + Unpin,
{
    const MAX_BUFFER_SIZE: usize = 1024 * 1024; // 1MB max for request
    const READ_CHUNK_SIZE: usize = 8192; // 8KB chunks
    
    let mut buffer = Vec::new();
    let mut temp_buf = vec![0u8; READ_CHUNK_SIZE];
    
    loop {
        // Try to parse what we have so far
        match parse_request(&buffer) {
            Ok(Some(req)) => {
                debug!("✓ Complete HTTP request parsed ({} bytes buffered)", buffer.len());
                return Ok(Some(req));
            }
            Ok(None) => {
                // Need more data, continue reading
                debug!("⏳ Incomplete request, need more data ({} bytes so far)", buffer.len());
            }
            Err(e) => {
                return Err(ConnectError::TunnelError(format!("Failed to parse HTTP request: {}", e)));
            }
        }
        
        // Read more data
        match stream.read(&mut temp_buf).await {
            Ok(0) => {
                // EOF
                if buffer.is_empty() {
                    debug!("EOF on empty buffer");
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
                
                // Prevent buffer from growing too large
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
///
/// Returns:
/// - Ok(Some(ParsedResponse)) if a complete response was read
/// - Ok(None) if the stream was closed (EOF)
/// - Err if there was an error reading or parsing
async fn read_http_response<S>(stream: &mut S) -> Result<Option<crate::http_parser::ParsedResponse>, ConnectError>
where
    S: AsyncReadExt + Unpin,
{
    const MAX_BUFFER_SIZE: usize = 10 * 1024 * 1024; // 10MB max for response
    const READ_CHUNK_SIZE: usize = 8192; // 8KB chunks
    
    let mut buffer = Vec::new();
    let mut temp_buf = vec![0u8; READ_CHUNK_SIZE];
    
    loop {
        // Try to parse what we have so far
        match parse_response(&buffer) {
            Ok(Some(resp)) => {
                debug!("✓ Complete HTTP response parsed ({} bytes buffered)", buffer.len());
                return Ok(Some(resp));
            }
            Ok(None) => {
                // Need more data, continue reading
                debug!("⏳ Incomplete response, need more data ({} bytes so far)", buffer.len());
            }
            Err(e) => {
                return Err(ConnectError::TunnelError(format!("Failed to parse HTTP response: {}", e)));
            }
        }
        
        // Read more data
        match stream.read(&mut temp_buf).await {
            Ok(0) => {
                // EOF
                if buffer.is_empty() {
                    debug!("EOF on empty buffer");
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
                
                // Prevent buffer from growing too large
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
///
/// Checks for:
/// - Connection: close header in request or response
/// - HTTP/1.0 without Connection: keep-alive
fn should_close_connection(
    request: &crate::http_parser::ParsedRequest,
    response: &crate::http_parser::ParsedResponse,
) -> bool {
    // Check request headers
    if let Some(conn) = request.headers.get("connection") {
        if conn.to_lowercase() == "close" {
            return true;
        }
    }
    
    // Check response headers
    if let Some(conn) = response.headers.get("connection") {
        if conn.to_lowercase() == "close" {
            return true;
        }
    }
    
    // HTTP/1.0 defaults to close unless keep-alive is specified
    if request.version == 0 {
        if let Some(conn) = request.headers.get("connection") {
            return conn.to_lowercase() != "keep-alive";
        }
        return true;
    }
    
    if response.version == 0 {
        if let Some(conn) = response.headers.get("connection") {
            return conn.to_lowercase() != "keep-alive";
        }
        return true;
    }
    
    // HTTP/1.1 defaults to keep-alive
    false
}