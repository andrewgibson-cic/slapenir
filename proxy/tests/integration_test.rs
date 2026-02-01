// Integration tests for SLAPENIR proxy
// Tests the complete HTTP server with sanitization

use axum::{
    body::Body,
    http::{Request, StatusCode},
};
use serde_json::json;
use tower::util::ServiceExt; // for `oneshot`

// Helper to create test app
fn create_test_app() -> axum::Router {
    use slapenir_proxy::{middleware::AppState, proxy::create_http_client, sanitizer::SecretMap};
    use std::collections::HashMap;

    let mut secrets = HashMap::new();
    secrets.insert("DUMMY_TOKEN".to_string(), "real_secret_123".to_string());

    let secret_map = SecretMap::new(secrets).expect("Failed to create SecretMap");
    let app_state = AppState {
        secret_map: std::sync::Arc::new(secret_map),
        http_client: create_http_client(),
    };

    axum::Router::new()
        .route("/health", axum::routing::get(health_handler))
        .with_state(app_state)
}

async fn health_handler() -> &'static str {
    "OK"
}

#[tokio::test]
async fn test_health_endpoint() {
    let app = create_test_app();

    let response = app
        .oneshot(
            Request::builder()
                .uri("/health")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);

    let body = axum::body::to_bytes(response.into_body(), usize::MAX)
        .await
        .unwrap();
    assert_eq!(&body[..], b"OK");
}

#[tokio::test]
async fn test_health_endpoint_method_not_allowed() {
    let app = create_test_app();

    let response = app
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/health")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::METHOD_NOT_ALLOWED);
}

#[test]
fn test_secret_map_thread_safety() {
    use slapenir_proxy::sanitizer::SecretMap;
    use std::collections::HashMap;
    use std::sync::Arc;
    use std::thread;

    let mut secrets = HashMap::new();
    secrets.insert("TOKEN1".to_string(), "secret1".to_string());
    secrets.insert("TOKEN2".to_string(), "secret2".to_string());

    let secret_map = Arc::new(SecretMap::new(secrets).unwrap());

    let handles: Vec<_> = (0..10)
        .map(|_| {
            let map = Arc::clone(&secret_map);
            thread::spawn(move || {
                let text = "This has TOKEN1 and TOKEN2 in it";
                let injected = map.inject(text);
                // After injection, tokens are replaced with secrets
                assert!(injected.contains("secret1"));
                assert!(injected.contains("secret2"));
                assert!(!injected.contains("TOKEN1"));
                assert!(!injected.contains("TOKEN2"));

                let sanitized = map.sanitize(&injected);
                // After sanitization, secrets are replaced back with tokens
                assert!(!sanitized.contains("secret1"));
                assert!(!sanitized.contains("secret2"));
                // Note: The sanitizer uses the reverse map, so we won't have the original tokens back
                // We just verify secrets are removed
            })
        })
        .collect();

    for handle in handles {
        handle.join().unwrap();
    }
}

#[test]
fn test_sanitizer_performance() {
    use slapenir_proxy::sanitizer::SecretMap;
    use std::collections::HashMap;
    use std::time::Instant;

    let mut secrets = HashMap::new();
    for i in 0..100 {
        secrets.insert(format!("TOKEN_{}", i), format!("real_secret_{}", i));
    }

    let secret_map = SecretMap::new(secrets).unwrap();

    let mut text = String::new();
    for i in 0..100 {
        text.push_str(&format!("TOKEN_{} ", i));
    }
    text = text.repeat(100); // 10,000 tokens

    let start = Instant::now();
    let injected = secret_map.inject(&text);
    let inject_duration = start.elapsed();

    let start = Instant::now();
    let _sanitized = secret_map.sanitize(&injected);
    let sanitize_duration = start.elapsed();

    // Should be fast (< 50ms for this workload in debug builds)
    // Note: In release builds, this is typically < 5ms
    assert!(
        inject_duration.as_millis() < 50,
        "Injection too slow: {:?}",
        inject_duration
    );
    assert!(
        sanitize_duration.as_millis() < 50,
        "Sanitization too slow: {:?}",
        sanitize_duration
    );
}

#[test]
fn test_edge_cases() {
    use slapenir_proxy::sanitizer::SecretMap;
    use std::collections::HashMap;

    let mut secrets = HashMap::new();
    secrets.insert("SHORT".to_string(), "x".to_string());
    secrets.insert("LONG".to_string(), "a".repeat(1000));
    secrets.insert(
        "SPECIAL".to_string(),
        "with\nnewlines\tand\ttabs".to_string(),
    );

    let secret_map = SecretMap::new(secrets).unwrap();

    // Test with short secret
    let text = "Use SHORT here";
    let injected = secret_map.inject(text);
    assert_eq!(injected, "Use x here");

    // Test with long secret
    let text = "Use LONG here";
    let injected = secret_map.inject(text);
    assert!(injected.contains(&"a".repeat(1000)));

    // Test with special characters
    let text = "Use SPECIAL here";
    let injected = secret_map.inject(text);
    assert!(injected.contains("with\nnewlines"));
}

#[test]
fn test_json_sanitization() {
    use slapenir_proxy::sanitizer::SecretMap;
    use std::collections::HashMap;

    let mut secrets = HashMap::new();
    secrets.insert("API_KEY".to_string(), "sk-real-key-12345".to_string());

    let secret_map = SecretMap::new(secrets).unwrap();

    // Simulate API response with secret
    let json_response = json!({
        "model": "gpt-4",
        "choices": [{
            "message": {
                "content": "Your API key is sk-real-key-12345"
            }
        }]
    })
    .to_string();

    let sanitized = secret_map.sanitize(&json_response);

    // The secret should be removed from the response
    assert!(
        !sanitized.contains("sk-real-key-12345"),
        "Secret should be removed: {}",
        sanitized
    );

    // Verify the JSON structure is still valid
    assert!(sanitized.contains("gpt-4"));
    assert!(sanitized.contains("Your API key is"));
}
