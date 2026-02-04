// TLS Acceptor for MITM
// Terminates client TLS connections and establishes upstream connections

use crate::tls::{CertificateAuthority, CertificateCache, HostCertificate, TlsError};
use rustls::ServerConfig;
use std::sync::Arc;
use tokio::io::{AsyncRead, AsyncWrite};
use tokio_rustls::TlsAcceptor;

/// TLS MITM Acceptor
/// Dynamically generates certificates for requested hostnames
pub struct MitmAcceptor {
    ca: Arc<CertificateAuthority>,
    cache: Arc<CertificateCache>,
}

impl MitmAcceptor {
    /// Create a new MITM acceptor with a Certificate Authority
    pub fn new(ca: Arc<CertificateAuthority>) -> Self {
        Self {
            ca,
            cache: Arc::new(CertificateCache::new()),
        }
    }

    /// Create a new MITM acceptor with custom cache capacity
    pub fn with_cache_capacity(ca: Arc<CertificateAuthority>, capacity: usize) -> Self {
        Self {
            ca,
            cache: Arc::new(CertificateCache::with_capacity(capacity)),
        }
    }

    /// Get or generate a certificate for a hostname
    pub async fn get_certificate(&self, hostname: &str) -> Result<Arc<HostCertificate>, TlsError> {
        self.cache.get_or_create(hostname, &self.ca).await
    }

    /// Create a TLS acceptor for a specific hostname
    pub async fn create_acceptor(&self, hostname: &str) -> Result<TlsAcceptor, TlsError> {
        let cert = self.get_certificate(hostname).await?;
        let config = build_server_config(&cert)?;
        Ok(TlsAcceptor::from(Arc::new(config)))
    }

    /// Accept a TLS connection for a specific hostname
    pub async fn accept<IO>(
        &self,
        stream: IO,
        hostname: &str,
    ) -> Result<tokio_rustls::server::TlsStream<IO>, TlsError>
    where
        IO: AsyncRead + AsyncWrite + Unpin,
    {
        let acceptor = self.create_acceptor(hostname).await?;
        acceptor
            .accept(stream)
            .await
            .map_err(|e| TlsError::TlsHandshake(e.to_string()))
    }
}

/// Build a rustls ServerConfig from a host certificate
fn build_server_config(cert: &HostCertificate) -> Result<ServerConfig, TlsError> {
    // Parse certificate PEM
    let cert_pem = cert.cert_pem().as_bytes();
    let certs = rustls_pemfile::certs(&mut &cert_pem[..])
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| TlsError::CertGeneration(format!("Failed to parse certificate: {}", e)))?;

    if certs.is_empty() {
        return Err(TlsError::CertGeneration(
            "No certificates found in PEM".to_string(),
        ));
    }

    // Parse private key PEM
    let key_pem = cert.key_pem().as_bytes();
    let mut key_reader = key_pem;

    let private_key = rustls_pemfile::private_key(&mut key_reader)
        .map_err(|e| TlsError::CertGeneration(format!("Failed to parse private key: {}", e)))?
        .ok_or_else(|| TlsError::CertGeneration("No private key found in PEM".to_string()))?;

    // Build ServerConfig
    let config = ServerConfig::builder()
        .with_no_client_auth()
        .with_single_cert(certs, private_key)
        .map_err(|e| TlsError::CertGeneration(format!("Failed to build TLS config: {}", e)))?;

    Ok(config)
}

/// Extract SNI (Server Name Indication) from TLS ClientHello
/// This is used to determine which certificate to present
pub fn extract_sni(client_hello: &[u8]) -> Option<String> {
    // TLS ClientHello parsing is complex, so we use a simplified approach
    // In production, consider using a proper TLS parser library

    // Basic validation
    if client_hello.len() < 43 {
        return None;
    }

    // Check if it's a TLS handshake (0x16)
    if client_hello[0] != 0x16 {
        return None;
    }

    // Check if it's ClientHello (0x01)
    if client_hello[5] != 0x01 {
        return None;
    }

    // Skip to extensions (this is a simplified parser)
    // Real implementation would properly parse the full ClientHello structure
    let mut offset = 43; // Skip fixed ClientHello header

    // Skip session ID
    if offset >= client_hello.len() {
        return None;
    }
    let session_id_len = client_hello[offset] as usize;
    offset += 1 + session_id_len;

    // Skip cipher suites
    if offset + 2 > client_hello.len() {
        return None;
    }
    let cipher_suites_len =
        u16::from_be_bytes([client_hello[offset], client_hello[offset + 1]]) as usize;
    offset += 2 + cipher_suites_len;

    // Skip compression methods
    if offset >= client_hello.len() {
        return None;
    }
    let compression_len = client_hello[offset] as usize;
    offset += 1 + compression_len;

    // Parse extensions
    if offset + 2 > client_hello.len() {
        return None;
    }
    let extensions_len =
        u16::from_be_bytes([client_hello[offset], client_hello[offset + 1]]) as usize;
    offset += 2;

    let extensions_end = offset + extensions_len;
    while offset + 4 <= extensions_end && offset + 4 <= client_hello.len() {
        let ext_type = u16::from_be_bytes([client_hello[offset], client_hello[offset + 1]]);
        let ext_len =
            u16::from_be_bytes([client_hello[offset + 2], client_hello[offset + 3]]) as usize;
        offset += 4;

        // SNI extension type is 0x0000
        if ext_type == 0x0000 && offset + ext_len <= client_hello.len() {
            // Parse SNI list
            if ext_len < 5 {
                return None;
            }
            let list_len =
                u16::from_be_bytes([client_hello[offset], client_hello[offset + 1]]) as usize;
            if list_len + 2 > ext_len {
                return None;
            }

            // Get first SNI entry (type 0x00 = hostname)
            if client_hello[offset + 2] == 0x00 {
                let name_len =
                    u16::from_be_bytes([client_hello[offset + 3], client_hello[offset + 4]])
                        as usize;

                if offset + 5 + name_len <= client_hello.len() {
                    let hostname = &client_hello[offset + 5..offset + 5 + name_len];
                    return String::from_utf8(hostname.to_vec()).ok();
                }
            }
            return None;
        }

        offset += ext_len;
    }

    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_mitm_acceptor_creation() {
        let ca = Arc::new(CertificateAuthority::generate().unwrap());
        let acceptor = MitmAcceptor::new(ca);

        let cert = acceptor.get_certificate("test.com").await.unwrap();
        assert_eq!(cert.hostname(), "test.com");
    }

    #[tokio::test]
    async fn test_mitm_acceptor_caching() {
        let ca = Arc::new(CertificateAuthority::generate().unwrap());
        let acceptor = MitmAcceptor::new(ca);

        let cert1 = acceptor.get_certificate("test.com").await.unwrap();
        let cert2 = acceptor.get_certificate("test.com").await.unwrap();

        // Should return cached certificate (same serial)
        assert_eq!(cert1.serial(), cert2.serial());
    }

    #[test]
    fn test_build_server_config() {
        let ca = CertificateAuthority::generate().unwrap();
        let cert = ca.sign_for_host("test.com").unwrap();

        let config = build_server_config(&cert);
        assert!(config.is_ok());
    }

    #[tokio::test]
    async fn test_create_acceptor() {
        let ca = Arc::new(CertificateAuthority::generate().unwrap());
        let acceptor = MitmAcceptor::new(ca);

        let tls_acceptor = acceptor.create_acceptor("test.com").await;
        assert!(tls_acceptor.is_ok());
    }

    #[test]
    fn test_extract_sni_none_for_short_data() {
        let data = vec![0u8; 10];
        assert!(extract_sni(&data).is_none());
    }

    #[test]
    fn test_extract_sni_none_for_non_tls() {
        let mut data = vec![0u8; 100];
        data[0] = 0x15; // Not handshake
        assert!(extract_sni(&data).is_none());
    }
}
