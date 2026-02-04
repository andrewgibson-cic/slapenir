// TLS Certificate Authority Implementation
// Generates and signs certificates for MITM

use crate::tls::error::TlsError;
use rcgen::{
    BasicConstraints, Certificate, CertificateParams, DistinguishedName, DnType, IsCa, SanType,
};
use std::fs;
use std::path::Path;

/// Certificate Authority for generating MITM certificates
pub struct CertificateAuthority {
    cert: Certificate,
    cert_pem: String,
    key_pem: String,
}

impl CertificateAuthority {
    /// Generate a new root CA
    pub fn generate() -> Result<Self, TlsError> {
        let mut params = CertificateParams::default();

        // Set up distinguished name
        params.distinguished_name = DistinguishedName::new();
        params
            .distinguished_name
            .push(DnType::CommonName, "SLAPENIR Proxy CA");
        params
            .distinguished_name
            .push(DnType::OrganizationName, "SLAPENIR");

        // Mark as CA
        params.is_ca = IsCa::Ca(BasicConstraints::Unconstrained);

        // Generate certificate
        let cert = Certificate::from_params(params)
            .map_err(|e| TlsError::CertGeneration(e.to_string()))?;

        let cert_pem = cert
            .serialize_pem()
            .map_err(|e| TlsError::CertGeneration(e.to_string()))?;
        let key_pem = cert.serialize_private_key_pem();

        Ok(Self {
            cert,
            cert_pem,
            key_pem,
        })
    }

    /// Sign a certificate for a specific host
    pub fn sign_for_host(&self, hostname: &str) -> Result<HostCertificate, TlsError> {
        let mut params = CertificateParams::new(vec![hostname.to_string()]);

        // Set up distinguished name
        params.distinguished_name = DistinguishedName::new();
        params.distinguished_name.push(DnType::CommonName, hostname);

        // Add Subject Alternative Name
        params.subject_alt_names = vec![SanType::DnsName(hostname.to_string())];

        // Generate unique serial number (using timestamp + counter)
        use std::sync::atomic::{AtomicU64, Ordering};
        use std::time::{SystemTime, UNIX_EPOCH};
        static SERIAL_COUNTER: AtomicU64 = AtomicU64::new(0);

        let timestamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_micros() as u64; // Use microseconds for more precision
        let counter = SERIAL_COUNTER.fetch_add(1, Ordering::SeqCst);

        // Combine timestamp and counter for unique serial
        let serial_num = timestamp.wrapping_add(counter);
        let serial_bytes = serial_num.to_be_bytes().to_vec();
        params.serial_number = Some(rcgen::SerialNumber::from_slice(&serial_bytes));

        // Generate certificate
        let cert = Certificate::from_params(params)
            .map_err(|e| TlsError::CertGeneration(e.to_string()))?;

        // Sign with CA
        let cert_pem = cert
            .serialize_pem_with_signer(&self.cert)
            .map_err(|e| TlsError::CertGeneration(e.to_string()))?;
        let key_pem = cert.serialize_private_key_pem();

        // Get serial number (convert to Vec<u8>)
        let serial = cert
            .get_params()
            .serial_number
            .as_ref()
            .map(|sn| sn.to_bytes().to_vec())
            .unwrap_or_default();

        Ok(HostCertificate {
            hostname: hostname.to_string(),
            cert_pem,
            key_pem,
            serial,
        })
    }

    /// Get the CA certificate in PEM format
    pub fn cert_pem(&self) -> &str {
        &self.cert_pem
    }

    /// Get the CA private key in PEM format
    pub fn key_pem(&self) -> &str {
        &self.key_pem
    }

    /// Save CA to files
    pub fn save(&self, cert_path: &Path, key_path: &Path) -> Result<(), TlsError> {
        fs::write(cert_path, &self.cert_pem)?;
        fs::write(key_path, &self.key_pem)?;
        Ok(())
    }

    /// Load CA from files
    pub fn load(cert_path: &Path, key_path: &Path) -> Result<Self, TlsError> {
        let cert_pem = fs::read_to_string(cert_path)?;
        let key_pem = fs::read_to_string(key_path)?;

        // For loading, we recreate the Certificate from the PEM strings
        // rcgen 0.12 doesn't have from_ca_cert_pem, so we use from_params with key_pair
        let key_pair = rcgen::KeyPair::from_pem(&key_pem)
            .map_err(|e| TlsError::CertGeneration(format!("Failed to parse key: {}", e)))?;

        let mut params = CertificateParams::default();
        params.distinguished_name = DistinguishedName::new();
        params
            .distinguished_name
            .push(DnType::CommonName, "SLAPENIR Proxy CA");
        params
            .distinguished_name
            .push(DnType::OrganizationName, "SLAPENIR");
        params.is_ca = IsCa::Ca(BasicConstraints::Unconstrained);
        params.key_pair = Some(key_pair);

        let cert = Certificate::from_params(params)
            .map_err(|e| TlsError::CertGeneration(e.to_string()))?;

        Ok(Self {
            cert,
            cert_pem,
            key_pem,
        })
    }

    /// Load CA from files, or generate if they don't exist
    pub fn load_or_generate(cert_path: &Path, key_path: &Path) -> Result<Self, TlsError> {
        if cert_path.exists() && key_path.exists() {
            Self::load(cert_path, key_path)
        } else {
            let ca = Self::generate()?;
            ca.save(cert_path, key_path)?;
            Ok(ca)
        }
    }
}

/// Certificate for a specific host
pub struct HostCertificate {
    hostname: String,
    cert_pem: String,
    key_pem: String,
    serial: Vec<u8>,
}

impl HostCertificate {
    /// Get the hostname this certificate is for
    pub fn hostname(&self) -> &str {
        &self.hostname
    }

    /// Get the certificate in PEM format
    pub fn cert_pem(&self) -> &str {
        &self.cert_pem
    }

    /// Get the private key in PEM format
    pub fn key_pem(&self) -> &str {
        &self.key_pem
    }

    /// Get the certificate serial number
    pub fn serial(&self) -> &[u8] {
        &self.serial
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_ca_generation() {
        let ca = CertificateAuthority::generate().unwrap();
        assert!(!ca.cert_pem().is_empty());
        assert!(!ca.key_pem().is_empty());
    }

    #[test]
    fn test_host_cert_generation() {
        let ca = CertificateAuthority::generate().unwrap();
        let cert = ca.sign_for_host("test.com").unwrap();

        assert_eq!(cert.hostname(), "test.com");
        assert!(!cert.cert_pem().is_empty());
        assert!(!cert.key_pem().is_empty());
        assert!(!cert.serial().is_empty());
    }
}
