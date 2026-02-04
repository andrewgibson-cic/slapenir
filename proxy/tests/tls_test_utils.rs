// TLS MITM Test Utilities
// Provides mock servers and helper functions for testing TLS MITM functionality

use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream};
use std::net::SocketAddr;

/// Create a mock TCP server that echoes data back
pub async fn create_echo_server() -> (SocketAddr, tokio::task::JoinHandle<()>) {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    
    let handle = tokio::spawn(async move {
        while let Ok((mut stream, _)) = listener.accept().await {
            tokio::spawn(async move {
                let mut buf = vec![0u8; 4096];
                loop {
                    match stream.read(&mut buf).await {
                        Ok(0) => break,
                        Ok(n) => {
                            if stream.write_all(&buf[..n]).await.is_err() {
                                break;
                            }
                        }
                        Err(_) => break,
                    }
                }
            });
        }
    });
    
    (addr, handle)
}

/// Create a mock HTTP server that responds with 200 OK
pub async fn create_http_server() -> (SocketAddr, tokio::task::JoinHandle<()>) {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    
    let handle = tokio::spawn(async move {
        while let Ok((mut stream, _)) = listener.accept().await {
            tokio::spawn(async move {
                let mut buf = vec![0u8; 4096];
                if let Ok(n) = stream.read(&mut buf).await {
                    let request = String::from_utf8_lossy(&buf[..n]);
                    
                    // Echo back the request in response body
                    let response = format!(
                        "HTTP/1.1 200 OK\r\n\
                         Content-Type: text/plain\r\n\
                         Content-Length: {}\r\n\
                         \r\n\
                         {}",
                        request.len(),
                        request
                    );
                    
                    let _ = stream.write_all(response.as_bytes()).await;
                }
            });
        }
    });
    
    (addr, handle)
}

/// Helper to verify credential injection
pub fn assert_contains_token(data: &[u8], expected: &str) {
    let text = String::from_utf8_lossy(data);
    assert!(
        text.contains(expected),
        "Expected token '{}' not found in data",
        expected
    );
}

/// Helper to verify credential sanitization
pub fn assert_not_contains_token(data: &[u8], secret: &str) {
    let text = String::from_utf8_lossy(data);
    assert!(
        !text.contains(secret),
        "Secret '{}' leaked in response data",
        secret
    );
}

/// Helper to extract authorization header from HTTP request
pub fn extract_authorization(data: &[u8]) -> Option<String> {
    let text = String::from_utf8_lossy(data);
    for line in text.lines() {
        if line.to_lowercase().starts_with("authorization:") {
            return Some(line.split(':').nth(1)?.trim().to_string());
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_echo_server_works() {
        let (addr, _handle) = create_echo_server().await;
        
        let mut stream = TcpStream::connect(addr).await.unwrap();
        stream.write_all(b"hello").await.unwrap();
        
        let mut buf = vec![0u8; 1024];
        let n = stream.read(&mut buf).await.unwrap();
        
        assert_eq!(&buf[..n], b"hello");
    }

    #[tokio::test]
    async fn test_http_server_responds() {
        let (addr, _handle) = create_http_server().await;
        
        let mut stream = TcpStream::connect(addr).await.unwrap();
        stream.write_all(b"GET / HTTP/1.1\r\nHost: localhost\r\n\r\n").await.unwrap();
        
        let mut buf = vec![0u8; 4096];
        let n = stream.read(&mut buf).await.unwrap();
        let response = String::from_utf8_lossy(&buf[..n]);
        
        assert!(response.contains("200 OK"));
    }

    #[test]
    fn test_assert_contains_token() {
        let data = b"Authorization: Bearer my-secret-token";
        assert_contains_token(data, "my-secret-token");
    }

    #[test]
    #[should_panic(expected = "not found")]
    fn test_assert_contains_token_fails() {
        let data = b"Authorization: Bearer other-token";
        assert_contains_token(data, "my-secret-token");
    }

    #[test]
    fn test_assert_not_contains_token() {
        let data = b"Authorization: Bearer DUMMY_TOKEN";
        assert_not_contains_token(data, "real-secret");
    }

    #[test]
    #[should_panic(expected = "leaked")]
    fn test_assert_not_contains_token_fails() {
        let data = b"Authorization: Bearer real-secret";
        assert_not_contains_token(data, "real-secret");
    }

    #[test]
    fn test_extract_authorization() {
        let data = b"GET / HTTP/1.1\r\nAuthorization: Bearer token123\r\n\r\n";
        let auth = extract_authorization(data).unwrap();
        assert_eq!(auth, "Bearer token123");
    }

    #[test]
    fn test_extract_authorization_none() {
        let data = b"GET / HTTP/1.1\r\nHost: localhost\r\n\r\n";
        assert!(extract_authorization(data).is_none());
    }
}