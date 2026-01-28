// SLAPENIR Proxy - Secure LLM Agent Proxy Environment
// Zero-Knowledge credential sanitization gateway

use axum::{
    response::Html,
    routing::get,
    Router,
};
use std::net::SocketAddr;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Initialize tracing/logging
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "slapenir_proxy=debug,tower_http=debug".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    tracing::info!("🔐 SLAPENIR Proxy starting...");

    // Build our application with routes
    let app = Router::new()
        .route("/", get(root))
        .route("/health", get(health));

    // Bind to address
    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));
    tracing::info!("🚀 Proxy listening on {}", addr);

    // Run server
    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
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
            <p>Network Isolation & Resilience</p>
            
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
            </ul>
            
            <p><em>Phase 2: Rust Proxy Core - In Development</em></p>
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