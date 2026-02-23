// SLAPENIR Proxy Library
// Exposes core modules for credential sanitization

pub mod auto_detect;
pub mod builder;
pub mod config;
pub mod connect;
pub mod http_parser;
pub mod metrics;
pub mod middleware;
pub mod mtls;
pub mod proxy;
pub mod sanitizer;
pub mod strategies;
pub mod strategy;
pub mod tls;

// Re-export commonly used types
pub use auto_detect::{AutoDetectConfig, AutoDetector, merge_strategies};
pub use builder::{build_strategies_from_config, is_telemetry_domain};
pub use config::{Config, SecurityConfig, StrategyConfig};
pub use middleware::{inject_secrets_middleware, sanitize_secrets_middleware, AppState};
pub use mtls::{verify_client_cert, ClientCertInfo, MtlsConfig};
pub use proxy::{
    build_response_headers, create_http_client, proxy_handler, HttpClient, ProxyConfig,
    DEFAULT_MAX_REQUEST_SIZE, DEFAULT_MAX_RESPONSE_SIZE,
};
pub use sanitizer::SecretMap;
pub use strategy::{AuthStrategy, BearerStrategy, StrategyError};
