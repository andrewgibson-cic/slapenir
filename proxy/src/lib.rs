// SLAPENIR Proxy Library
// Exposes core modules for credential sanitization

pub mod sanitizer;
pub mod middleware;
pub mod proxy;
pub mod mtls;
pub mod metrics;
pub mod config;
pub mod strategy;
pub mod strategies;
pub mod builder;

// Re-export commonly used types
pub use sanitizer::SecretMap;
pub use middleware::{AppState, inject_secrets_middleware, sanitize_secrets_middleware};
pub use proxy::{proxy_handler, create_http_client, HttpClient};
pub use mtls::{MtlsConfig, ClientCertInfo, verify_client_cert};
pub use config::{Config, StrategyConfig, SecurityConfig};
pub use strategy::{AuthStrategy, BearerStrategy, StrategyError};
pub use strategies::AWSSigV4Strategy;
pub use builder::{build_strategies_from_config, is_telemetry_domain};
