// TLS MITM Module
// Provides certificate generation and TLS interception capabilities

pub mod acceptor;
pub mod ca;
pub mod cache;
pub mod error;

pub use acceptor::{extract_sni, MitmAcceptor};
pub use ca::{CertificateAuthority, HostCertificate};
pub use cache::CertificateCache;
pub use error::TlsError;
