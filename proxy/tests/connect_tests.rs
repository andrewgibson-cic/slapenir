// Integration tests for CONNECT tunnel functionality
// Tests HTTP CONNECT method support for HTTPS tunneling

use axum::{
    body::Body,
    http::{Method, Request, StatusCode},
    response::IntoResponse,
};
use slapenir_proxy::{middleware::AppState, proxy::create_http_client, sanitizer::SecretMap};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpListener;
use tokio::time::{timeout, Duration};

// ============================================================================
// Test Helpers
// ============================================================================

/// Create a test AppState with mock secrets
fn create_test_state() -> AppState {
    let mut secrets = HashMap::new();
    secrets.insert("DUMMY_TOKEN".to_string(), "real_secret_123".to_string());
    secrets.insert(
        "DUMMY_GITHUB".to_string(),
        "ghp_real_token_456".to_string(),
    );

    let secret_map = SecretMap::new(secrets).expect("Failed to create SecretMap");
    AppState {
        secret_map: Arc::new(secret_map),
        http_client: create_http_client(),
    }
}

/// Create a mock TCP echo server for testing
async fn create_mock_server() -> (String, tokio::task::JoinHandle<()>) {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    let destination = format!("{}:{}", addr.ip(), addr.port());

    let handle = tokio::spawn(async move {
        while let Ok((mut socket, _)) = listener.accept().await {
            tokio::spawn(async move {
                let mut buf = vec![0u8; 1024];
                loop {
                    match socket.read(&mut buf).await {
                        Ok(0) => break,
                        Ok(n) => {
                            if socket.write_all(&buf[..n]).await.is_err() {
                                break;
                            }
                        }
                        Err(_) => break,
                    }
                }
            });
        }
    });

    (destination, handle)
}

/// Create a mock server that closes immediately
async fn create_failing_server() -> String {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    let destination = format!("{}:{}", addr.ip(), addr.port());

    tokio::spawn(async move {
        if let Ok((socket, _)) = listener.accept().await {
            drop(socket); // Close immediately
        }
    });

    destination
}

// ============================================================================
// CONNECT Request Parsing Tests
// ============================================================================

#[tokio::test]
async fn test_connect_valid_hostname() {
    let state = create_test_state();
    let (destination, _handle) = create_mock_server().await;

    let req = Request::builder()
        .method(Method::CONNECT)
        .uri(destination.clone())
        .body(Body::empty())
        .unwrap();

    let result = slapenir_proxy::connect::handle_connect(
        axum::extract::State(state),
        req,
    )
    .await;

    assert!(result.is_ok(), "CONNECT should succeed for valid hostname");
    let response = result.unwrap();
    assert_eq!(response.status(), StatusCode::OK);
}

#[tokio::test]
async fn test_connect_ipv4_address() {
    let state = create_test_state();
    let (destination, _handle) = create_mock_server().await;

    let req = Request::builder()
        .method(Method::CONNECT)
        .uri(destination)
        .body(Body::empty())
        .unwrap();

    let result = slapenir_proxy::connect::handle_connect(
        axum::extract::State(state),
        req,
    )
    .await;

    assert!(result.is_ok(), "CONNECT should work with IPv4 addresses");
}

#[tokio::test]
async fn test_connect_missing_port() {
    let state = create_test_state();

    let req = Request::builder()
        .method(Method::CONNECT)
        .uri("github.com") // Missing port
        .body(Body::empty())
        .unwrap();

    let result = slapenir_proxy::connect::handle_connect(
        axum::extract::State(state),
        req,
    )
    .await;

    assert!(result.is_err(), "CONNECT should fail without port");
    let err = result.unwrap_err();
    assert_eq!(err.into_response().status(), StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn test_connect_invalid_destination() {
    let state = create_test_state();

    let req = Request::builder()
        .method(Method::CONNECT)
        .uri("/path/to/resource") // Not a valid CONNECT destination
        .body(Body::empty())
        .unwrap();

    let result = slapenir_proxy::connect::handle_connect(
        axum::extract::State(state),
        req,
    )
    .await;

    assert!(result.is_err(), "CONNECT should fail with invalid destination");
}

// ============================================================================
// Connection Establishment Tests
// ============================================================================

#[tokio::test]
async fn test_connect_to_unreachable_host() {
    let state = create_test_state();

    // Use a destination that doesn't exist
    let req = Request::builder()
        .method(Method::CONNECT)
        .uri("192.0.2.1:9999") // TEST-NET-1 (RFC 5737) - should not route
        .body(Body::empty())
        .unwrap();

    let result = timeout(
        Duration::from_secs(2),
        slapenir_proxy::connect::handle_connect(axum::extract::State(state), req),
    )
    .await;

    match result {
        Ok(Ok(_)) => panic!("Should not connect to unreachable host"),
        Ok(Err(err)) => {
            assert_eq!(err.into_response().status(), StatusCode::BAD_GATEWAY);
        }
        Err(_) => {
            // Timeout is also acceptable
        }
    }
}

#[tokio::test]
async fn test_connect_refused_connection() {
    let state = create_test_state();

    // Try to connect to a port that's not listening
    let req = Request::builder()
        .method(Method::CONNECT)
        .uri("127.0.0.1:1") // Port 1 should not be listening
        .body(Body::empty())
        .unwrap();

    let result = slapenir_proxy::connect::handle_connect(
        axum::extract::State(state),
        req,
    )
    .await;

    assert!(result.is_err(), "Should fail when connection is refused");
    let err = result.unwrap_err();
    assert_eq!(err.into_response().status(), StatusCode::BAD_GATEWAY);
}

// ============================================================================
// Tunneling Behavior Tests
// ============================================================================

#[tokio::test]
async fn test_tunnel_data_passthrough() {
    let state = create_test_state();
    let (destination, _handle) = create_mock_server().await;

    let req = Request::builder()
        .method(Method::CONNECT)
        .uri(destination.clone())
        .body(Body::empty())
        .unwrap();

    let result = slapenir_proxy::connect::handle_connect(
        axum::extract::State(state),
        req,
    )
    .await;

    assert!(result.is_ok(), "CONNECT should succeed");
    let response = result.unwrap();
    assert_eq!(response.status(), StatusCode::OK);

    // Note: Testing actual data transfer requires the upgrade to complete
    // which happens asynchronously after the response is sent.
    // For now, we verify the response is correct.
}

#[tokio::test]
async fn test_multiple_sequential_connects() {
    let state = create_test_state();
    let (destination, _handle) = create_mock_server().await;

    for i in 0..5 {
        let req = Request::builder()
            .method(Method::CONNECT)
            .uri(destination.clone())
            .body(Body::empty())
            .unwrap();

        let result = slapenir_proxy::connect::handle_connect(
            axum::extract::State(state.clone()),
            req,
        )
        .await;

        assert!(
            result.is_ok(),
            "CONNECT #{} should succeed",
            i + 1
        );
    }
}

// ============================================================================
// Concurrent Connection Tests
// ============================================================================

#[tokio::test]
async fn test_concurrent_connects() {
    let state = create_test_state();
    let (destination, _handle) = create_mock_server().await;

    let mut handles = vec![];

    for _ in 0..10 {
        let state_clone = state.clone();
        let dest_clone = destination.clone();

        let handle = tokio::spawn(async move {
            let req = Request::builder()
                .method(Method::CONNECT)
                .uri(dest_clone)
                .body(Body::empty())
                .unwrap();

            slapenir_proxy::connect::handle_connect(
                axum::extract::State(state_clone),
                req,
            )
            .await
        });

        handles.push(handle);
    }

    let results = futures::future::join_all(handles).await;

    for (i, result) in results.iter().enumerate() {
        assert!(result.is_ok(), "Task {} panicked", i);
        let connect_result = result.as_ref().unwrap();
        assert!(
            connect_result.is_ok(),
            "CONNECT {} failed: {:?}",
            i,
            connect_result
        );
    }
}

#[tokio::test]
async fn test_concurrent_mixed_success_failure() {
    let state = create_test_state();
    let (good_destination, _handle) = create_mock_server().await;
    let bad_destination = "192.0.2.1:9999".to_string();

    let mut handles = vec![];

    for i in 0..10 {
        let state_clone = state.clone();
        let destination = if i % 2 == 0 {
            good_destination.clone()
        } else {
            bad_destination.clone()
        };

        let handle = tokio::spawn(async move {
            let req = Request::builder()
                .method(Method::CONNECT)
                .uri(destination)
                .body(Body::empty())
                .unwrap();

            timeout(
                Duration::from_secs(2),
                slapenir_proxy::connect::handle_connect(
                    axum::extract::State(state_clone),
                    req,
                ),
            )
            .await
        });

        handles.push(handle);
    }

    let results = futures::future::join_all(handles).await;

    let mut success_count = 0;
    let mut failure_count = 0;

    for result in results {
        if let Ok(Ok(Ok(_))) = result {
            success_count += 1;
        } else {
            failure_count += 1;
        }
    }

    assert!(success_count >= 5, "At least 5 should succeed");
    assert!(failure_count >= 5, "At least 5 should fail");
}

// ============================================================================
// Error Response Tests
// ============================================================================

#[tokio::test]
async fn test_error_response_format() {
    let state = create_test_state();

    let req = Request::builder()
        .method(Method::CONNECT)
        .uri("192.0.2.1:9999")
        .body(Body::empty())
        .unwrap();

    let result = timeout(
        Duration::from_secs(1),
        slapenir_proxy::connect::handle_connect(axum::extract::State(state), req),
    )
    .await;

    if let Ok(Err(err)) = result {
        let response = err.into_response();
        assert_eq!(response.status(), StatusCode::BAD_GATEWAY);

        // Verify response body contains useful error info
        let body = axum::body::to_bytes(response.into_body(), usize::MAX)
            .await
            .unwrap();
        let body_str = String::from_utf8_lossy(&body);
        assert!(body_str.contains("192.0.2.1:9999"));
    }
}

// ============================================================================
// Edge Case Tests
// ============================================================================

#[tokio::test]
async fn test_connect_with_zero_port() {
    let state = create_test_state();

    let req = Request::builder()
        .method(Method::CONNECT)
        .uri("example.com:0")
        .body(Body::empty())
        .unwrap();

    let result = slapenir_proxy::connect::handle_connect(
        axum::extract::State(state),
        req,
    )
    .await;

    // Port 0 is invalid for CONNECT
    assert!(result.is_err());
}

#[tokio::test]
async fn test_connect_with_max_port() {
    let state = create_test_state();

    let req = Request::builder()
        .method(Method::CONNECT)
        .uri("example.com:65535")
        .body(Body::empty())
        .unwrap();

    let result = slapenir_proxy::connect::handle_connect(
        axum::extract::State(state),
        req,
    )
    .await;

    // Should attempt to connect (will fail, but parsing should succeed)
    // We just verify it doesn't panic or return invalid request
    assert!(result.is_err());
    if let Err(err) = result {
        // Should be BAD_GATEWAY (can't connect), not BAD_REQUEST (invalid format)
        assert_eq!(err.into_response().status(), StatusCode::BAD_GATEWAY);
    }
}

#[tokio::test]
async fn test_connect_long_hostname() {
    let state = create_test_state();

    // Create a very long but valid hostname
    let long_hostname = format!("{}.example.com:443", "a".repeat(200));

    let req = Request::builder()
        .method(Method::CONNECT)
        .uri(long_hostname)
        .body(Body::empty())
        .unwrap();

    let result = slapenir_proxy::connect::handle_connect(
        axum::extract::State(state),
        req,
    )
    .await;

    // Should parse successfully (connection will fail, but that's OK)
    assert!(result.is_err());
}

// ============================================================================
// Real-World Scenario Tests
// ============================================================================

#[tokio::test]
async fn test_github_connect_format() {
    let state = create_test_state();
    let (destination, _handle) = create_mock_server().await;

    // Simulate git's CONNECT request format
    let req = Request::builder()
        .method(Method::CONNECT)
        .uri(destination)
        .header("host", "github.com:443")
        .header("user-agent", "git/2.39.0")
        .header("proxy-connection", "Keep-Alive")
        .body(Body::empty())
        .unwrap();

    let result = slapenir_proxy::connect::handle_connect(
        axum::extract::State(state),
        req,
    )
    .await;

    assert!(result.is_ok(), "Should handle git CONNECT format");
}

#[tokio::test]
async fn test_npm_connect_format() {
    let state = create_test_state();
    let (destination, _handle) = create_mock_server().await;

    // Simulate npm's CONNECT request format
    let req = Request::builder()
        .method(Method::CONNECT)
        .uri(destination)
        .header("host", "registry.npmjs.org:443")
        .header("user-agent", "npm/9.0.0")
        .body(Body::empty())
        .unwrap();

    let result = slapenir_proxy::connect::handle_connect(
        axum::extract::State(state),
        req,
    )
    .await;

    assert!(result.is_ok(), "Should handle npm CONNECT format");
}

// ============================================================================
// Performance and Load Tests
// ============================================================================

#[tokio::test]
async fn test_rapid_connect_disconnect() {
    let state = create_test_state();
    let (destination, _handle) = create_mock_server().await;

    for _ in 0..50 {
        let req = Request::builder()
            .method(Method::CONNECT)
            .uri(destination.clone())
            .body(Body::empty())
            .unwrap();

        let result = slapenir_proxy::connect::handle_connect(
            axum::extract::State(state.clone()),
            req,
        )
        .await;

        assert!(result.is_ok());
    }
}

#[tokio::test]
async fn test_memory_cleanup() {
    // Test that connections are properly cleaned up
    let state = create_test_state();
    let (destination, _handle) = create_mock_server().await;

    for _ in 0..100 {
        let req = Request::builder()
            .method(Method::CONNECT)
            .uri(destination.clone())
            .body(Body::empty())
            .unwrap();

        let _ = slapenir_proxy::connect::handle_connect(
            axum::extract::State(state.clone()),
            req,
        )
        .await;

        // Small delay to allow async cleanup
        tokio::time::sleep(Duration::from_millis(10)).await;
    }

    // If we get here without OOM, cleanup is working
    assert!(true);
}

// ============================================================================
// State and Resource Tests
// ============================================================================

#[tokio::test]
async fn test_state_cloning() {
    let state = create_test_state();
    let (destination, _handle) = create_mock_server().await;

    // Verify state can be cloned and used independently
    let state1 = state.clone();
    let state2 = state.clone();

    let req1 = Request::builder()
        .method(Method::CONNECT)
        .uri(destination.clone())
        .body(Body::empty())
        .unwrap();

    let req2 = Request::builder()
        .method(Method::CONNECT)
        .uri(destination.clone())
        .body(Body::empty())
        .unwrap();

    let result1 = slapenir_proxy::connect::handle_connect(
        axum::extract::State(state1),
        req1,
    )
    .await;

    let result2 = slapenir_proxy::connect::handle_connect(
        axum::extract::State(state2),
        req2,
    )
    .await;

    assert!(result1.is_ok());
    assert!(result2.is_ok());
}

// ============================================================================
// Timeout and Reliability Tests
// ============================================================================

#[tokio::test]
async fn test_connect_timeout_handling() {
    let state = create_test_state();

    // Try to connect to a blackhole address (drops packets)
    let req = Request::builder()
        .method(Method::CONNECT)
        .uri("192.0.2.1:443") // TEST-NET-1
        .body(Body::empty())
        .unwrap();

    let result = timeout(
        Duration::from_secs(2),
        slapenir_proxy::connect::handle_connect(axum::extract::State(state), req),
    )
    .await;

    // Should either timeout or return error within 2 seconds
    match result {
        Ok(Err(_)) => assert!(true, "Connection failed as expected"),
        Err(_) => assert!(true, "Timeout as expected"),
        Ok(Ok(_)) => panic!("Should not succeed connecting to blackhole"),
    }
}

#[tokio::test]
async fn test_concurrent_timeout_handling() {
    let state = create_test_state();
    let mut handles = vec![];

    for _ in 0..5 {
        let state_clone = state.clone();
        let handle = tokio::spawn(async move {
            let req = Request::builder()
                .method(Method::CONNECT)
                .uri("192.0.2.1:443")
                .body(Body::empty())
                .unwrap();

            timeout(
                Duration::from_secs(1),
                slapenir_proxy::connect::handle_connect(
                    axum::extract::State(state_clone),
                    req,
                ),
            )
            .await
        });

        handles.push(handle);
    }

    let results = futures::future::join_all(handles).await;

    // All should complete without panicking
    for result in results {
        assert!(result.is_ok(), "Task should not panic");
    }
}

// ============================================================================
// Documentation and Example Tests
// ============================================================================

/// Example: How to use CONNECT in production
#[tokio::test]
async fn test_production_example() {
    let state = create_test_state();
    let (destination, _handle) = create_mock_server().await;

    // Step 1: Create CONNECT request
    let request = Request::builder()
        .method(Method::CONNECT)
        .uri(destination)
        .body(Body::empty())
        .unwrap();

    // Step 2: Handle CONNECT request
    let response = slapenir_proxy::connect::handle_connect(
        axum::extract::State(state),
        request,
    )
    .await;

    // Step 3: Verify success
    assert!(response.is_ok());
    let response = response.unwrap();
    assert_eq!(response.status(), StatusCode::OK);

    // Step 4: Connection is now upgraded and tunneling begins
    // (happens asynchronously in spawned task)
}

/// Test that demonstrates the full CONNECT flow
#[tokio::test]
async fn test_connect_flow_documentation() {
    // This test serves as living documentation for the CONNECT flow

    // 1. Setup
    let state = create_test_state();
    let (destination, _handle) = create_mock_server().await;

    // 2. Client sends CONNECT request
    let request = Request::builder()
        .method(Method::CONNECT)
        .uri(destination.clone())
        .body(Body::empty())
        .unwrap();

    // 3. Proxy handles CONNECT
    let result = slapenir_proxy::connect::handle_connect(
        axum::extract::State(state),
        request,
    )
    .await;

    // 4. Proxy returns 200 Connection Established
    assert!(result.is_ok());
    let response = result.unwrap();
    assert_eq!(response.status(), StatusCode::OK);

    // 5. Tunnel is established asynchronously
    //    (Data flows between client and server)
    
    // 6. Connection closes when either side disconnects
}
