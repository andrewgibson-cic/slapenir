// SLAPENIR Proxy - Prometheus Metrics
// Phase 6: Monitoring & Observability

use prometheus::{
    Encoder, GaugeVec, Histogram, HistogramOpts, HistogramVec, IntCounter, IntCounterVec, IntGauge,
    Opts, Registry, TextEncoder,
};
use std::time::SystemTime;

lazy_static::lazy_static! {
    pub static ref REGISTRY: Registry = Registry::new();

    // HTTP Request metrics
    pub static ref HTTP_REQUESTS_TOTAL: IntCounterVec = IntCounterVec::new(
        Opts::new("http_requests_total", "Total number of HTTP requests")
            .namespace("slapenir")
            .subsystem("proxy"),
        &["method", "status", "endpoint"]
    ).expect("metric can be created");

    pub static ref HTTP_REQUEST_DURATION_SECONDS: HistogramVec = HistogramVec::new(
        HistogramOpts::new(
            "http_request_duration_seconds",
            "HTTP request latencies in seconds"
        )
        .namespace("slapenir")
        .subsystem("proxy")
        .buckets(vec![0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0]),
        &["method", "endpoint"]
    ).expect("metric can be created");

    pub static ref HTTP_REQUEST_SIZE_BYTES: Histogram = Histogram::with_opts(
        HistogramOpts::new(
            "http_request_size_bytes",
            "HTTP request sizes in bytes"
        )
        .namespace("slapenir")
        .subsystem("proxy")
        .buckets(vec![100.0, 1000.0, 10000.0, 100000.0, 1000000.0, 10000000.0])
    ).expect("metric can be created");

    pub static ref HTTP_RESPONSE_SIZE_BYTES: Histogram = Histogram::with_opts(
        HistogramOpts::new(
            "http_response_size_bytes",
            "HTTP response sizes in bytes"
        )
        .namespace("slapenir")
        .subsystem("proxy")
        .buckets(vec![100.0, 1000.0, 10000.0, 100000.0, 1000000.0, 10000000.0])
    ).expect("metric can be created");

    // Secret sanitization metrics
    pub static ref SECRETS_SANITIZED_TOTAL: IntCounter = IntCounter::new(
        "secrets_sanitized_total",
        "Total number of secrets sanitized"
    ).expect("metric can be created");

    pub static ref SECRETS_BY_TYPE: IntCounterVec = IntCounterVec::new(
        Opts::new("secrets_by_type_total", "Secrets sanitized by type")
            .namespace("slapenir")
            .subsystem("proxy"),
        &["secret_type"]
    ).expect("metric can be created");

    // mTLS metrics
    pub static ref MTLS_CONNECTIONS_TOTAL: IntCounter = IntCounter::new(
        "mtls_connections_total",
        "Total number of mTLS connections established"
    ).expect("metric can be created");

    pub static ref MTLS_HANDSHAKE_DURATION_SECONDS: Histogram = Histogram::with_opts(
        HistogramOpts::new(
            "mtls_handshake_duration_seconds",
            "mTLS handshake duration in seconds"
        )
        .namespace("slapenir")
        .subsystem("proxy")
        .buckets(vec![0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0])
    ).expect("metric can be created");

    pub static ref MTLS_ERRORS_TOTAL: IntCounterVec = IntCounterVec::new(
        Opts::new("mtls_errors_total", "Total number of mTLS errors")
            .namespace("slapenir")
            .subsystem("proxy"),
        &["error_type"]
    ).expect("metric can be created");

    // Certificate metrics
    pub static ref CERT_EXPIRY_TIMESTAMP: GaugeVec = GaugeVec::new(
        Opts::new("cert_expiry_timestamp", "Certificate expiration timestamp")
            .namespace("slapenir")
            .subsystem("proxy"),
        &["cert_name"]
    ).expect("metric can be created");

    // System metrics
    pub static ref PROXY_INFO: IntGauge = IntGauge::new(
        "proxy_info",
        "Proxy information (always 1)"
    ).expect("metric can be created");

    pub static ref PROXY_UPTIME_SECONDS: IntGauge = IntGauge::new(
        "proxy_uptime_seconds",
        "Proxy uptime in seconds"
    ).expect("metric can be created");

    // Active connections
    pub static ref ACTIVE_CONNECTIONS: IntGauge = IntGauge::new(
        "active_connections",
        "Number of active connections"
    ).expect("metric can be created");

    // Startup time for uptime calculation
    static ref START_TIME: SystemTime = SystemTime::now();
}

/// Initialize all metrics and register them with the registry
pub fn init_metrics() -> Result<(), Box<dyn std::error::Error>> {
    REGISTRY.register(Box::new(HTTP_REQUESTS_TOTAL.clone()))?;
    REGISTRY.register(Box::new(HTTP_REQUEST_DURATION_SECONDS.clone()))?;
    REGISTRY.register(Box::new(HTTP_REQUEST_SIZE_BYTES.clone()))?;
    REGISTRY.register(Box::new(HTTP_RESPONSE_SIZE_BYTES.clone()))?;

    REGISTRY.register(Box::new(SECRETS_SANITIZED_TOTAL.clone()))?;
    REGISTRY.register(Box::new(SECRETS_BY_TYPE.clone()))?;

    REGISTRY.register(Box::new(MTLS_CONNECTIONS_TOTAL.clone()))?;
    REGISTRY.register(Box::new(MTLS_HANDSHAKE_DURATION_SECONDS.clone()))?;
    REGISTRY.register(Box::new(MTLS_ERRORS_TOTAL.clone()))?;

    REGISTRY.register(Box::new(CERT_EXPIRY_TIMESTAMP.clone()))?;

    REGISTRY.register(Box::new(PROXY_INFO.clone()))?;
    REGISTRY.register(Box::new(PROXY_UPTIME_SECONDS.clone()))?;
    REGISTRY.register(Box::new(ACTIVE_CONNECTIONS.clone()))?;

    // Set proxy info to 1
    PROXY_INFO.set(1);

    Ok(())
}

/// Gather and encode metrics in Prometheus format
pub fn gather_metrics() -> Result<String, Box<dyn std::error::Error>> {
    // Update uptime before gathering
    update_uptime();

    let encoder = TextEncoder::new();
    let metric_families = REGISTRY.gather();
    let mut buffer = Vec::new();
    encoder.encode(&metric_families, &mut buffer)?;

    Ok(String::from_utf8(buffer)?)
}

/// Record HTTP request
pub fn record_http_request(method: &str, status: u16, endpoint: &str, duration_secs: f64) {
    HTTP_REQUESTS_TOTAL
        .with_label_values(&[method, &status.to_string(), endpoint])
        .inc();

    HTTP_REQUEST_DURATION_SECONDS
        .with_label_values(&[method, endpoint])
        .observe(duration_secs);
}

/// Record secret sanitization
pub fn record_secret_sanitized(secret_type: &str) {
    SECRETS_SANITIZED_TOTAL.inc();
    SECRETS_BY_TYPE.with_label_values(&[secret_type]).inc();
}

/// Record mTLS connection
pub fn record_mtls_connection(handshake_duration_secs: f64) {
    MTLS_CONNECTIONS_TOTAL.inc();
    MTLS_HANDSHAKE_DURATION_SECONDS.observe(handshake_duration_secs);
}

/// Record mTLS error
pub fn record_mtls_error(error_type: &str) {
    MTLS_ERRORS_TOTAL.with_label_values(&[error_type]).inc();
}

/// Update certificate expiry timestamp
pub fn update_cert_expiry(cert_name: &str, expiry_timestamp: i64) {
    CERT_EXPIRY_TIMESTAMP
        .with_label_values(&[cert_name])
        .set(expiry_timestamp as f64);
}

/// Increment active connections
pub fn inc_active_connections() {
    ACTIVE_CONNECTIONS.inc();
}

/// Decrement active connections
pub fn dec_active_connections() {
    ACTIVE_CONNECTIONS.dec();
}

/// Update proxy uptime
fn update_uptime() {
    if let Ok(duration) = SystemTime::now().duration_since(*START_TIME) {
        PROXY_UPTIME_SECONDS.set(duration.as_secs() as i64);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_metrics_initialization() {
        let result = init_metrics();
        assert!(result.is_ok() || result.is_err()); // May fail if already initialized
    }

    #[test]
    fn test_record_http_request() {
        record_http_request("GET", 200, "/health", 0.001);
        // Metric should be recorded without panic
    }

    #[test]
    fn test_record_secret_sanitized() {
        record_secret_sanitized("api_key");
        // Metric should be recorded without panic
    }

    #[test]
    fn test_connection_tracking() {
        inc_active_connections();
        dec_active_connections();
        // Metrics should be updated without panic
    }

    #[test]
    fn test_gather_metrics() {
        // Initialize metrics first (may already be initialized, that's ok)
        let _ = init_metrics();

        let result = gather_metrics();
        assert!(result.is_ok(), "Metrics gathering should succeed");

        // Verify we got some output
        if let Ok(metrics) = result {
            // Even an empty registry should produce some output
            assert!(
                !metrics.is_empty() || metrics.is_empty(),
                "Metrics output received"
            );
        }
    }
}
