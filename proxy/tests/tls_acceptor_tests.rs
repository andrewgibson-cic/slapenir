// TLS Acceptor Integration Tests
// Tests TLS handshake interception and certificate generation

use slapenir_proxy::tls::{CertificateAuthority, MitmAcceptor};
use std::sync::Arc;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream};
use tokio_rustls::TlsConnector;
use rustls::pki_types::ServerName;
use std::sync::Arc as StdArc;

/// Helper to create a TLS connector that accepts self-signed certificates
fn create_test_connector() -> TlsConnector {
    use rustls::client::danger::{HandshakeSignatureValid, ServerCertVerified, ServerCertVerifier};
    use rustls::SignatureScheme;
    use rustls::pki_types::CertificateDer;
    
    #[derive(Debug)]
    struct NoVerifier;
    
    impl ServerCertVerifier for NoVerifier {
        fn verify_server_cert(
            &self,
            _end_entity: &CertificateDer<'_>,
            _intermediates: &[CertificateDer<'_>],
            _server_name: &ServerName<'_>,
            _ocsp_response: &[u8],
            _now: rustls::pki_types::UnixTime,
        ) -> Result<ServerCertVerified, rustls::Error> {
            Ok(ServerCertVerified::assertion())
        }

        fn verify_tls12_signature(
            &self,
            _message: &[u8],
            _cert: &CertificateDer<'_>,
            _dss: &rustls::DigitallySignedStruct,
        ) -> Result<HandshakeSignatureValid, rustls::Error> {
            Ok(HandshakeSignatureValid::assertion())
        }

        fn verify_tls13_signature(
            &self,
            _message: &[u8],
            _cert: &CertificateDer<'_>,
            _dss: &rustls::DigitallySignedStruct,
        ) -> Result<HandshakeSignatureValid, rustls::Error> {
            Ok(HandshakeSignatureValid::assertion())
        }

        fn supported_verify_schemes(&self) -> Vec<SignatureScheme> {
            vec![
                SignatureScheme::RSA_PKCS1_SHA256,
                SignatureScheme::ECDSA_NISTP256_SHA256,
                SignatureScheme::ED25519,
            ]
        }
    }
    
    let mut config = rustls::ClientConfig::builder()
        .dangerous()
        .with_custom_certificate_verifier(StdArc::new(NoVerifier))
        .with_no_client_auth();
    
    config.alpn_protocols = vec![b"http/1.1".to_vec()];
    
    TlsConnector::from(StdArc::new(config))
}

#[tokio::test]
async fn test_mitm_acceptor_basic_handshake() {
    // Create CA and acceptor
    let ca = Arc::new(CertificateAuthority::generate().unwrap());
    let acceptor = Arc::new(MitmAcceptor::new(ca));
    
    // Start server
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    
    let acceptor_clone = acceptor.clone();
    let server_handle = tokio::spawn(async move {
        let (stream, _) = listener.accept().await.unwrap();
        let mut tls_stream = acceptor_clone
            .accept(stream, "test.com")
            .await
            .unwrap();
        
        // Echo server
        let mut buf = vec![0u8; 1024];
        let n = tls_stream.read(&mut buf).await.unwrap();
        tls_stream.write_all(&buf[..n]).await.unwrap();
    });
    
    // Give server time to start
    tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;
    
    // Connect client
    let stream = TcpStream::connect(addr).await.unwrap();
    let connector = create_test_connector();
    let server_name = ServerName::try_from("test.com").unwrap();
    let mut tls_stream = connector.connect(server_name, stream).await.unwrap();
    
    // Send data
    tls_stream.write_all(b"Hello, TLS!").await.unwrap();
    
    // Receive echo
    let mut buf = vec![0u8; 1024];
    let n = tls_stream.read(&mut buf).await.unwrap();
    
    assert_eq!(&buf[..n], b"Hello, TLS!");
    
    server_handle.await.unwrap();
}

#[tokio::test]
async fn test_mitm_acceptor_multiple_connections() {
    let ca = Arc::new(CertificateAuthority::generate().unwrap());
    let acceptor = Arc::new(MitmAcceptor::new(ca));
    
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    
    let acceptor_clone = acceptor.clone();
    let server_handle = tokio::spawn(async move {
        for _ in 0..3 {
            let (stream, _) = listener.accept().await.unwrap();
            let acceptor = acceptor_clone.clone();
            tokio::spawn(async move {
                let mut tls_stream = acceptor.accept(stream, "test.com").await.unwrap();
                let mut buf = vec![0u8; 1024];
                let n = tls_stream.read(&mut buf).await.unwrap();
                tls_stream.write_all(&buf[..n]).await.unwrap();
            });
        }
    });
    
    tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;
    
    // Connect 3 clients
    let mut handles = vec![];
    for i in 0..3 {
        let connector = create_test_connector();
        handles.push(tokio::spawn(async move {
            let stream = TcpStream::connect(addr).await.unwrap();
            let server_name = ServerName::try_from("test.com").unwrap();
            let mut tls_stream = connector.connect(server_name, stream).await.unwrap();
            
            let message = format!("Client {}", i);
            tls_stream.write_all(message.as_bytes()).await.unwrap();
            
            let mut buf = vec![0u8; 1024];
            let n = tls_stream.read(&mut buf).await.unwrap();
            assert_eq!(&buf[..n], message.as_bytes());
        }));
    }
    
    for handle in handles {
        handle.await.unwrap();
    }
    
    server_handle.await.unwrap();
}

#[tokio::test]
async fn test_mitm_acceptor_different_hostnames() {
    let ca = Arc::new(CertificateAuthority::generate().unwrap());
    let acceptor = Arc::new(MitmAcceptor::new(ca));
    
    // Pre-generate certificates for different hostnames
    let cert1 = acceptor.get_certificate("host1.com").await.unwrap();
    let cert2 = acceptor.get_certificate("host2.com").await.unwrap();
    
    // Should have different certificates
    assert_ne!(cert1.serial(), cert2.serial());
    assert_eq!(cert1.hostname(), "host1.com");
    assert_eq!(cert2.hostname(), "host2.com");
}

#[tokio::test]
async fn test_mitm_acceptor_certificate_reuse() {
    let ca = Arc::new(CertificateAuthority::generate().unwrap());
    let acceptor = Arc::new(MitmAcceptor::new(ca));
    
    // Get certificate twice for same hostname
    let cert1 = acceptor.get_certificate("reuse.com").await.unwrap();
    let cert2 = acceptor.get_certificate("reuse.com").await.unwrap();
    
    // Should be cached (same serial)
    assert_eq!(cert1.serial(), cert2.serial());
}

#[tokio::test]
async fn test_mitm_acceptor_concurrent_certificate_generation() {
    let ca = Arc::new(CertificateAuthority::generate().unwrap());
    let acceptor = Arc::new(MitmAcceptor::new(ca));
    
    // Generate certificates concurrently
    let mut handles = vec![];
    for i in 0..10 {
        let acceptor = acceptor.clone();
        handles.push(tokio::spawn(async move {
            acceptor
                .get_certificate(&format!("host{}.com", i))
                .await
                .unwrap()
        }));
    }
    
    let certs: Vec<_> = futures::future::join_all(handles)
        .await
        .into_iter()
        .map(|r| r.unwrap())
        .collect();
    
    // All certificates should be unique
    for i in 0..certs.len() {
        for j in (i + 1)..certs.len() {
            assert_ne!(certs[i].serial(), certs[j].serial());
        }
    }
}

#[tokio::test]
async fn test_mitm_acceptor_custom_cache_capacity() {
    let ca = Arc::new(CertificateAuthority::generate().unwrap());
    let acceptor = MitmAcceptor::with_cache_capacity(ca, 5);
    
    // Generate more certificates than cache capacity
    for i in 0..10 {
        acceptor
            .get_certificate(&format!("host{}.com", i))
            .await
            .unwrap();
    }
    
    // Should work without errors (cache eviction handled internally)
}

#[test]
fn test_mitm_acceptor_sync_send() {
    fn assert_send<T: Send>() {}
    fn assert_sync<T: Sync>() {}
    assert_send::<MitmAcceptor>();
    assert_sync::<MitmAcceptor>();
}