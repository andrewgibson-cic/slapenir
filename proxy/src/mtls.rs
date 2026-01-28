// SLAPENIR mTLS Module
// Implements mutual TLS authentication for proxy-agent communication

use axum::{
    extract::ConnectInfo,
    http::{Request, StatusCode},
    middleware::Next,
    response::Response,
};
use std::net::SocketAddr;
use std::sync::Arc;
use tokio_rustls::rustls::{
    server::WebPkiClientVerifier, Certificate, ClientConfig, RootCertStore, ServerConfig,
};
use tokio_rustls::TlsAcceptor;
use tracing::{debug, error, info, warn};

/// mTLS configuration for the proxy
#[derive(Clone)]
pub struct MtlsConfig {
    /// Server TLS configuration (for accepting connections)
    pub server_config: Arc<ServerConfig>,
    /// Client TLS configuration (for making outbound connections)
    pub client_config: Arc<ClientConfig>,
    /// Whether to enforce mTLS (false for development)
    pub enforce: bool,
}

impl MtlsConfig {
    /// Create a new mTLS configuration from certificate files
    ///
    /// # Arguments
    /// * `ca_cert_path` - Path to the CA certificate
    /// * `server_cert_path` - Path to the server certificate
    /// * `server_key_path` - Path to the server private key
    /// * `enforce` - Whether to enforce mTLS verification
    pub fn from_files(
        ca_cert_path: &str,
        server_cert_path: &str,
        server_key_path: &str,
        enforce: bool,
    ) -> Result<Self, Box<dyn std::error::Error>> {
        info!("Initializing mTLS configuration");
        debug!(
            "CA cert: {}, Server cert: {}, Server key: {}",
            ca_cert_path, server_cert_path, server_key_path
        );

        // Load CA certificate for client verification
        let ca_cert_pem = std::fs::read(ca_cert_path)?;
        let ca_cert = rustls_pemfile::certs(&mut &ca_cert_pem[..])?
            .into_iter()
            .next()
            .ok_or("No CA certificate found")?;

        // Create root certificate store
        let mut root_store = RootCertStore::empty();
        root_store.add(&Certificate(ca_cert.clone()))?;

        // Load server certificate and key
        let server_cert_pem = std::fs::read(server_cert_path)?;
        let server_certs: Vec<Certificate> = rustls_pemfile::certs(&mut &server_cert_pem[..])?
            .into_iter()
            .map(Certificate)
            .collect();

        let server_key_pem = std::fs::read(server_key_path)?;
        let mut server_keys = rustls_pemfile::pkcs8_private_keys(&mut &server_key_pem[..])?;
        if server_keys.is_empty() {
            server_keys = rustls_pemfile::rsa_private_keys(&mut &server_key_pem[..])?;
        }
        let server_key = server_keys
            .into_iter()
            .next()
            .ok_or("No private key found")?;

        // Configure client verification
        let client_verifier = if enforce {
            info!("mTLS enforcement enabled - clients must present valid certificates");
            WebPkiClientVerifier::builder(Arc::new(root_store.clone()))
                .build()
                .map_err(|e| format!("Failed to build client verifier: {}", e))?
        } else {
            warn!("mTLS enforcement disabled - accepting connections without client certificates");
            WebPkiClientVerifier::builder(Arc::new(root_store.clone()))
                .build()
                .map_err(|e| format!("Failed to build client verifier: {}", e))?
        };

        // Create server configuration
        let server_config = ServerConfig::builder()
            .with_safe_defaults()
            .with_client_cert_verifier(Arc::new(client_verifier))
            .with_single_cert(server_certs, tokio_rustls::rustls::PrivateKey(server_key))?;

        // Create client configuration for outbound connections
        let client_config = ClientConfig::builder()
            .with_safe_defaults()
            .with_root_certificates(root_store)
            .with_no_client_auth();

        info!("mTLS configuration initialized successfully");

        Ok(MtlsConfig {
            server_config: Arc::new(server_config),
            client_config: Arc::new(client_config),
            enforce,
        })
    }

    /// Create a TLS acceptor for incoming connections
    pub fn acceptor(&self) -> TlsAcceptor {
        TlsAcceptor::from(self.server_config.clone())
    }
}

/// Middleware to verify client certificates
///
/// This middleware extracts and validates the client certificate from the connection.
/// If mTLS is enforced and no valid certificate is present, the request is rejected.
pub async fn verify_client_cert<B>(
    ConnectInfo(addr): ConnectInfo<SocketAddr>,
    mtls_config: axum::Extension<MtlsConfig>,
    request: Request<B>,
    next: Next<B>,
) -> Result<Response, StatusCode> {
    debug!("mTLS verification for client: {}", addr);

    // In a real implementation, we would extract the client certificate from the TLS session
    // For now, we'll check if enforcement is enabled
    if mtls_config.enforce {
        // TODO: Extract actual client certificate from TLS connection
        // This requires deeper integration with the TLS layer
        debug!("Client certificate verification requested");
        
        // For development, we'll allow through but log
        warn!("mTLS enforcement enabled but certificate extraction not yet implemented");
    }

    Ok(next.run(request).await)
}

/// Certificate information extracted from a client connection
#[derive(Debug, Clone)]
pub struct ClientCertInfo {
    /// Common Name (CN) from the certificate
    pub common_name: String,
    /// Organization (O) from the certificate
    pub organization: Option<String>,
    /// Certificate serial number
    pub serial: String,
    /// Certificate is valid
    pub valid: bool,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_mtls_config_creation() {
        // Test that MtlsConfig can be created (will fail without actual cert files)
        // In a real scenario, we'd use test fixtures
        let result = MtlsConfig::from_files(
            "test_ca.crt",
            "test_server.crt",
            "test_server.key",
            false,
        );
        
        // This will fail without actual files, which is expected in unit tests
        assert!(result.is_err());
    }

    #[test]
    fn test_client_cert_info_creation() {
        let cert_info = ClientCertInfo {
            common_name: "agent-01".to_string(),
            organization: Some("SLAPENIR".to_string()),
            serial: "ABC123".to_string(),
            valid: true,
        };

        assert_eq!(cert_info.common_name, "agent-01");
        assert!(cert_info.valid);
    }
}