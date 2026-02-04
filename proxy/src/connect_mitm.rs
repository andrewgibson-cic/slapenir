// TLS MITM tunnel implementation
// This is Phase 3B implementation that will be integrated into connect.rs

use std::{path::Path, sync::Arc};
use hyper::upgrade::Upgraded;
use hyper_util::rt::TokioIo;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use tokio_rustls::TlsConnector;
use rustls::pki_types::ServerName;
use tracing::{debug, info};

use crate::middleware::AppState;
use crate::tls::{CertificateAuthority, MitmAcceptor};

use super::{ConnectError, extract_hostname};

/// TLS MITM tunnel - intercepts and modifies HTTPS traffic
///
/// Phase 3B Implementation: TLS Handshake Complete
/// - Loads/generates CA certificate
/// - Accepts TLS from client (MITM)
/// - Connects TLS to upstream server
/// - Bidirectional forwarding
pub async fn tunnel_with_tls_mitm(
    client_stream: Upgraded,
    server_stream: TcpStream,
    destination: &str,
    _state: AppState,
) -> Result<(), ConnectError> {
    // Extract hostname for certificate generation
    let hostname = extract_hostname(destination)?;
    info!("🔐 Starting TLS MITM for hostname: {}", hostname);

    // Phase 3B: TLS Handshake
    
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
    debug!("Creating MITM acceptor for client connection...");
    let acceptor = MitmAcceptor::new(ca);
    
    // Step 3: Accept TLS connection from client (decrypt client's traffic)
    debug!("Accepting TLS connection from client for '{}'...", hostname);
    let client_stream = TokioIo::new(client_stream);
    let mut client_tls = acceptor
        .accept(client_stream, &hostname)
        .await
        .map_err(|e| ConnectError::TlsError(e))?;
    
    info!("✓ Client TLS handshake complete for '{}'", hostname);
    
    // Step 4: Establish TLS connection to upstream server (encrypt to real server)
    debug!("Establishing TLS connection to upstream server '{}'...", hostname);
    
    // Create TLS client config with system root certificates
    let mut root_store = rustls::RootCertStore::empty();
    for cert in webpki_roots::TLS_SERVER_ROOTS.iter() {
        root_store.roots.push(cert.clone());
    }
    
    let client_config = rustls::ClientConfig::builder()
        .with_root_certificates(root_store)
        .with_no_client_auth();
    
    let connector = TlsConnector::from(Arc::new(client_config));
    
    // Parse hostname for SNI
    let server_name = ServerName::try_from(hostname.as_str())
        .map_err(|e| ConnectError::TunnelError(format!("Invalid hostname '{}': {}", hostname, e)))?;
    
    let mut server_tls = connector
        .connect(server_name, server_stream)
        .await
        .map_err(|e| ConnectError::TunnelError(format!("Server TLS handshake failed: {}", e)))?;
    
    info!("✓ Server TLS handshake complete for '{}'", hostname);
    
    // Phase 3B: Simple bidirectional forwarding (will be replaced with HTTP parsing in Phase 3C)
    debug!("Starting bidirectional TLS tunnel for '{}'", hostname);
    
    let (mut client_read, mut client_write) = tokio::io::split(client_tls);
    let (mut server_read, mut server_write) = tokio::io::split(server_tls);
    
    let client_to_server = async {
        tokio::io::copy(&mut client_read, &mut server_write).await
    };
    
    let server_to_client = async {
        tokio::io::copy(&mut server_read, &mut client_write).await
    };
    
    // Run both directions concurrently
    tokio::try_join!(client_to_server, server_to_client)
        .map_err(|e| ConnectError::TunnelError(format!("IO error: {}", e)))?;
    
    info!("✓ TLS MITM tunnel closed for '{}'", hostname);
    
    Ok(())
}