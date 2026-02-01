// SLAPENIR Proxy Library
// Exposes core modules for credential sanitization

pub mod builder;
pub mod config;
pub mod metrics;
pub mod middleware;
pub mod mtls;
pub mod proxy;
pub mod sanitizer;
pub mod strategies;
pub mod strategy;

// Re-export commonly used types
pub use builder::{build_strategies_from_config, is_telemetry_domain};
pub use config::{Config, SecurityConfig, StrategyConfig};
pub use middleware::{inject_secrets_middleware, sanitize_secrets_middleware, AppState};
pub use mtls::{verify_client_cert, ClientCertInfo, MtlsConfig};
pub use proxy::{create_http_client, proxy_handler, HttpClient};
pub use sanitizer::SecretMap;
pub use strategies::AWSSigV4Strategy;
pub use strategy::{AuthStrategy, BearerStrategy, StrategyError};
