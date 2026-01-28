// SLAPENIR Proxy Library
// Exposes core modules for credential sanitization

pub mod sanitizer;
pub mod middleware;

// Re-export commonly used types
pub use sanitizer::SecretMap;
pub use middleware::{AppState, inject_secrets_middleware, sanitize_secrets_middleware};
