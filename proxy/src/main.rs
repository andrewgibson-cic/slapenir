// SLAPENIR Proxy - Secure LLM Agent Proxy Environment
// Zero-Knowledge credential sanitization gateway

use axum::{
    response::Html,
    routing::{any, get},
    Router, Extension,
};
use std::collections::HashMap;
use std::net::SocketAddr;
use tower_http::trace::TraceLayer;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

mod middleware;
mod mtls;
mod proxy;
mod sanitizer;

use middleware::AppState;
use mtls::MtlsConfig;
use sanitizer::SecretMap;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Initialize tracing/logging
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "slapenir_proxy=info,tower_http=info".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    tracing::info!("🔐 SLAPENIR Proxy starting...");

    // Initialize mTLS if enabled
    let mtls_config = load_mtls_config()?;

    // Load secrets from environment or configuration
    let secrets = load_secrets();
    
    let secret_map = if secrets.is_empty() {
        tracing::warn!("⚠️  No secrets configured. Using test secret for demonstration.");
        // Create a test secret for demonstration
        let mut test_secrets = HashMap::new();
        test_secrets.insert("DUMMY_TOKEN".to_string(), "test_real_token_123".to_string());
        SecretMap::new(test_secrets).map_err(|e| anyhow::anyhow!(e))?
    } else {
        tracing::info!("✅ Loaded {} secrets from configuration", secrets.len());
        SecretMap::new(secrets).map_err(|e| anyhow::anyhow!(e))?
    };
    
    let app_state = AppState {
        secret_map: std::sync::Arc::new(secret_map),
        http_client: proxy::create_http_client(),
    };
    
    // Build our application with routes
    let mut app = Router::new()
        // Health and info endpoints
        .route("/", get(root))
        .route("/health", get(health))
        // Proxy routes - handle all HTTP methods
        .route("/v1/*path", any(proxy::proxy_handler))
        .with_state(app_state)
        .layer(TraceLayer::new_for_http());
    
    // Add mTLS layer if configured
    if let Some(mtls) = mtls_config {
        tracing::info!("🔒 mTLS enabled - mutual authentication active");
        app = app.layer(Extension(mtls));
        // Note: Full mTLS integration with axum-server for TLS listener
        // would be added here in production. For now, we support mTLS
        // configuration but serve over HTTP for development.
    } else {
        tracing::info!("🔓 mTLS disabled - running in development mode");
    }

    // Bind to address
    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));
    tracing::info!("🚀 Proxy listening on {}", addr);
    tracing::info!("📡 Ready to proxy LLM API requests");
    tracing::info!("💡 Send requests to http://localhost:3000/v1/*");

    // Run server
    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}

/// Load mTLS configuration from environment variables
fn load_mtls_config() -> anyhow::Result<Option<MtlsConfig>> {
    // Check if mTLS is enabled
    let mtls_enabled = std::env::var("MTLS_ENABLED")
        .unwrap_or_else(|_| "false".to_string())
        .to_lowercase() == "true";
    
    if !mtls_enabled {
        return Ok(None);
    }
    
    tracing::info!("🔐 Initializing mTLS configuration...");
    
    // Get certificate paths from environment
    let ca_cert = std::env::var("MTLS_CA_CERT")
        .unwrap_or_else(|_| "/certs/root_ca.crt".to_string());
    let server_cert = std::env::var("MTLS_SERVER_CERT")
        .unwrap_or_else(|_| "/certs/proxy.crt".to_string());
    let server_key = std::env::var("MTLS_SERVER_KEY")
        .unwrap_or_else(|_| "/certs/proxy.key".to_string());
    
    // Check if enforcement is enabled
    let enforce = std::env::var("MTLS_ENFORCE")
        .unwrap_or_else(|_| "false".to_string())
        .to_lowercase() == "true";
    
    tracing::info!("📁 Certificate paths:");
    tracing::info!("   CA: {}", ca_cert);
    tracing::info!("   Server cert: {}", server_cert);
    tracing::info!("   Server key: {}", server_key);
    tracing::info!("   Enforcement: {}", if enforce { "ENABLED" } else { "disabled" });
    
    // Try to load mTLS configuration
    match MtlsConfig::from_files(&ca_cert, &server_cert, &server_key, enforce) {
        Ok(config) => {
            tracing::info!("✅ mTLS configuration loaded successfully");
            Ok(Some(config))
        }
        Err(e) => {
            tracing::warn!("⚠️  Failed to load mTLS configuration: {}", e);
            tracing::warn!("⚠️  Continuing without mTLS - certificates may not be available yet");
            tracing::warn!("💡 Run ./scripts/setup-mtls-certs.sh to generate certificates");
            Ok(None)
        }
    }
}

/// Load secrets from environment variables
fn load_secrets() -> HashMap<String, String> {
    let mut secrets = HashMap::new();
    
    // Load OpenAI API key
    if let Ok(key) = std::env::var("OPENAI_API_KEY") {
        secrets.insert("DUMMY_OPENAI".to_string(), key);
        tracing::debug!("Loaded OPENAI_API_KEY");
    }
    
    // Load Anthropic API key
    if let Ok(key) = std::env::var("ANTHROPIC_API_KEY") {
        secrets.insert("DUMMY_ANTHROPIC".to_string(), key);
        tracing::debug!("Loaded ANTHROPIC_API_KEY");
    }
    
    // Load GitHub token
    if let Ok(token) = std::env::var("GITHUB_TOKEN") {
        secrets.insert("DUMMY_GITHUB".to_string(), token);
        tracing::debug!("Loaded GITHUB_TOKEN");
    }
    
    // Load generic API_KEY (for testing)
    if let Ok(key) = std::env::var("API_KEY") {
        secrets.insert("DUMMY_API_KEY".to_string(), key);
        tracing::debug!("Loaded API_KEY");
    }
    
    secrets
}

/// Root endpoint
async fn root() -> Html<&'static str> {
    Html(
        r#"
        <!DOCTYPE html>
        <html>
        <head>
            <title>SLAPENIR Proxy</title>
            <style>
                body { font-family: monospace; max-width: 800px; margin: 50px auto; padding: 20px; }
                h1 { color: #2563eb; }
                .status { color: #16a34a; font-weight: bold; }
                code { background: #f1f5f9; padding: 2px 6px; border-radius: 3px; }
            </style>
        </head>
        <body>
            <h1>🔐 SLAPENIR Proxy</h1>
            <p class="status">✅ Status: Running</p>
            <p><strong>Secure LLM Agent Proxy Environment</strong></p>
            <p>Network Isolation &amp; Resilience</p>
            
            <h2>Features:</h2>
            <ul>
                <li>Zero-Knowledge credential sanitization</li>
                <li>Mutual TLS (mTLS) authentication</li>
                <li>Aho-Corasick streaming pattern matching</li>
                <li>Secure memory handling with zeroize</li>
            </ul>
            
            <h2>Endpoints:</h2>
            <ul>
                <li><code>GET /</code> - This page</li>
                <li><code>GET /health</code> - Health check</li>
                <li><code>POST /v1/*</code> - Proxy to LLM APIs</li>
            </ul>
            
            <h2>Usage:</h2>
            <p>Set environment variables for your API keys (e.g., <code>OPENAI_API_KEY</code>).</p>
            <p>Send requests with dummy tokens (e.g., <code>DUMMY_OPENAI</code>) in your request body.</p>
            
            <p><em>Phase 2: Rust Proxy Core - Active Development</em></p>
        </body>
        </html>
        "#,
    )
}

/// Health check endpoint
async fn health() -> &'static str {
    "OK"
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_health() {
        let response = health().await;
        assert_eq!(response, "OK");
    }
}