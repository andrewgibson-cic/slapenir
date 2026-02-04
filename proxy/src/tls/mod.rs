// TLS MITM Module
// Provides certificate generation and TLS interception capabilities

pub mod ca;
pub mod cache;
pub mod error;
pub mod acceptor;

pub use ca::{CertificateAuthority, HostCertificate};
pub use cache::CertificateCache;
pub use error::TlsError;
pub use acceptor::{MitmAcceptor, extract_sni};
