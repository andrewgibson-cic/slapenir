// SLAPENIR Proxy Library
// Exposes core modules for credential sanitization

pub mod sanitizer;
pub mod middleware;
pub mod proxy;

// Re-export commonly used types
pub use sanitizer::SecretMap;
pub use middleware::{AppState, inject_secrets_middleware, sanitize_secrets_middleware};
pub use proxy::{proxy_handler, create_http_client, HttpClient};