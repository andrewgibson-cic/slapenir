// TLS Error Types

use std::fmt;

#[derive(Debug)]
pub enum TlsError {
    CertGeneration(String),
    Io(std::io::Error),
    InvalidCertificate(String),
    TlsHandshake(String),
}

impl fmt::Display for TlsError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            TlsError::CertGeneration(msg) => write!(f, "Certificate generation error: {}", msg),
            TlsError::Io(e) => write!(f, "IO error: {}", e),
            TlsError::InvalidCertificate(msg) => write!(f, "Invalid certificate: {}", msg),
            TlsError::TlsHandshake(msg) => write!(f, "TLS handshake error: {}", msg),
        }
    }
}

impl std::error::Error for TlsError {}

impl From<std::io::Error> for TlsError {
    fn from(e: std::io::Error) -> Self {
        TlsError::Io(e)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_error_display() {
        let err = TlsError::CertGeneration("test error".to_string());
        assert_eq!(err.to_string(), "Certificate generation error: test error");
    }

    #[test]
    fn test_io_error_conversion() {
        let io_err = std::io::Error::new(std::io::ErrorKind::NotFound, "file not found");
        let tls_err: TlsError = io_err.into();
        assert!(matches!(tls_err, TlsError::Io(_)));
    }

    #[test]
    fn test_error_is_send_sync() {
        fn assert_send<T: Send>() {}
        fn assert_sync<T: Sync>() {}
        assert_send::<TlsError>();
        assert_sync::<TlsError>();
    }
}
