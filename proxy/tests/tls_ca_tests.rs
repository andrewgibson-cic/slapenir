// TLS Certificate Authority Tests
// Test-First: Write tests before implementation

use slapenir_proxy::tls::CertificateAuthority;
use tempfile::TempDir;

#[test]
fn test_generate_root_ca() {
    let ca = CertificateAuthority::generate().unwrap();

    // Should have certificate and key in PEM format
    assert!(ca.cert_pem().contains("BEGIN CERTIFICATE"));
    assert!(ca.key_pem().contains("BEGIN"));

    // Should not be empty
    assert!(!ca.cert_pem().is_empty());
    assert!(!ca.key_pem().is_empty());
}

#[test]
fn test_ca_signs_host_certificate() {
    let ca = CertificateAuthority::generate().unwrap();
    let host_cert = ca.sign_for_host("github.com").unwrap();

    // Should generate valid certificate
    assert!(host_cert.cert_pem().contains("BEGIN CERTIFICATE"));
    assert!(host_cert.key_pem().contains("BEGIN"));

    // Should be for correct hostname
    assert_eq!(host_cert.hostname(), "github.com");
}

#[test]
fn test_ca_persistence() {
    let temp_dir = TempDir::new().unwrap();
    let ca_path = temp_dir.path().join("ca.pem");
    let key_path = temp_dir.path().join("ca.key");

    // Generate and save
    let ca1 = CertificateAuthority::generate().unwrap();
    ca1.save(&ca_path, &key_path).unwrap();

    // Verify files exist
    assert!(ca_path.exists());
    assert!(key_path.exists());

    // Load and verify
    let ca2 = CertificateAuthority::load(&ca_path, &key_path).unwrap();
    assert_eq!(ca1.cert_pem(), ca2.cert_pem());
}

#[test]
fn test_ca_load_or_generate_creates() {
    let temp_dir = TempDir::new().unwrap();
    let ca_path = temp_dir.path().join("ca.pem");
    let key_path = temp_dir.path().join("ca.key");

    // First call should create
    let ca1 = CertificateAuthority::load_or_generate(&ca_path, &key_path).unwrap();

    // Files should now exist
    assert!(ca_path.exists());
    assert!(key_path.exists());

    // Second call should load existing
    let ca2 = CertificateAuthority::load_or_generate(&ca_path, &key_path).unwrap();

    // Should be the same CA
    assert_eq!(ca1.cert_pem(), ca2.cert_pem());
}

#[test]
fn test_ca_signs_multiple_hosts() {
    let ca = CertificateAuthority::generate().unwrap();

    let cert1 = ca.sign_for_host("github.com").unwrap();
    let cert2 = ca.sign_for_host("gitlab.com").unwrap();
    let cert3 = ca.sign_for_host("api.github.com").unwrap();

    // Each should be unique
    assert_ne!(cert1.serial(), cert2.serial());
    assert_ne!(cert1.serial(), cert3.serial());
    assert_ne!(cert2.serial(), cert3.serial());

    // Each should be for correct host
    assert_eq!(cert1.hostname(), "github.com");
    assert_eq!(cert2.hostname(), "gitlab.com");
    assert_eq!(cert3.hostname(), "api.github.com");
}

#[test]
fn test_wildcard_certificate() {
    let ca = CertificateAuthority::generate().unwrap();
    let cert = ca.sign_for_host("*.github.com").unwrap();

    assert_eq!(cert.hostname(), "*.github.com");
    assert!(cert.cert_pem().contains("BEGIN CERTIFICATE"));
}

#[test]
fn test_ca_certificate_not_empty() {
    let ca = CertificateAuthority::generate().unwrap();

    assert!(ca.cert_pem().len() > 100);
    assert!(ca.key_pem().len() > 100);
}

#[test]
fn test_host_certificate_not_empty() {
    let ca = CertificateAuthority::generate().unwrap();
    let cert = ca.sign_for_host("example.com").unwrap();

    assert!(cert.cert_pem().len() > 100);
    assert!(cert.key_pem().len() > 100);
}

#[test]
fn test_ca_load_nonexistent_fails() {
    let temp_dir = TempDir::new().unwrap();
    let ca_path = temp_dir.path().join("nonexistent.pem");
    let key_path = temp_dir.path().join("nonexistent.key");

    let result = CertificateAuthority::load(&ca_path, &key_path);
    assert!(result.is_err());
}

#[test]
fn test_serial_numbers_unique() {
    let ca = CertificateAuthority::generate().unwrap();

    let cert1 = ca.sign_for_host("test1.com").unwrap();
    let cert2 = ca.sign_for_host("test2.com").unwrap();
    let cert3 = ca.sign_for_host("test3.com").unwrap();

    // All serials should be different
    assert_ne!(cert1.serial(), cert2.serial());
    assert_ne!(cert1.serial(), cert3.serial());
    assert_ne!(cert2.serial(), cert3.serial());
}

#[test]
fn test_multiple_ca_instances_different() {
    let ca1 = CertificateAuthority::generate().unwrap();
    let ca2 = CertificateAuthority::generate().unwrap();

    // Different CAs should have different certificates
    assert_ne!(ca1.cert_pem(), ca2.cert_pem());
}

#[test]
fn test_ca_with_long_hostname() {
    let ca = CertificateAuthority::generate().unwrap();
    let long_hostname = "very.long.subdomain.example.com";

    let cert = ca.sign_for_host(long_hostname).unwrap();
    assert_eq!(cert.hostname(), long_hostname);
}

#[test]
fn test_ca_with_numeric_hostname() {
    let ca = CertificateAuthority::generate().unwrap();
    let cert = ca.sign_for_host("123.example.com").unwrap();

    assert_eq!(cert.hostname(), "123.example.com");
}

#[test]
fn test_host_cert_has_serial() {
    let ca = CertificateAuthority::generate().unwrap();
    let cert = ca.sign_for_host("test.com").unwrap();

    // Serial should not be empty
    assert!(!cert.serial().is_empty());
}
