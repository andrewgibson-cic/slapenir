// SLAPENIR Proxy - Secure LLM Agent Proxy Environment
// Zero-Knowledge credential sanitization gateway

use axum::{
    response::Html,
    routing::{any, get},
    Router,
};
use std::collections::HashMap;
use std::net::SocketAddr;
use tower_http::trace::TraceLayer;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

mod middleware;
mod proxy;
mod sanitizer;

use middleware::AppState;
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
    let app = Router::new()
        // Health and info endpoints
        .route("/", get(root))
        .route("/health", get(health))
        // Proxy routes - handle all HTTP methods
        .route("/v1/*path", any(proxy::proxy_handler))
        .with_state(app_state)
        .layer(TraceLayer::new_for_http());

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