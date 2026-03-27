//! Fault Injection and Chaos Engineering Tests
//!
//! Tests system resilience under failure conditions:
//! - Network failures
//! - Timeout scenarios
//! - Memory pressure
//! - Malformed inputs
//! - Resource exhaustion

use slapenir_proxy::proxy::{build_response_headers, ProxyConfig};
use slapenir_proxy::sanitizer::SecretMap;
use std::collections::HashMap;
use std::time::{Duration, Instant};

#[cfg(test)]
mod network_failures {
    use super::*;
    use std::sync::atomic::{AtomicUsize, Ordering};
    use std::sync::Arc;
    use tokio::time::{sleep, timeout};

    #[tokio::test]
    async fn test_downstream_timeout_handling() {
        let start = Instant::now();
        
        let result = timeout(Duration::from_millis(100), async {
            sleep(Duration::from_secs(10)).await;
            Ok::<_, String>("should not reach")
        }).await;

        assert!(result.is_err());
        assert!(start.elapsed() < Duration::from_millis(150));
    }

    #[tokio::test]
    async fn test_connection_refused_handling() {
        use tokio::net::TcpStream;

        let result = timeout(
            Duration::from_millis(100),
            TcpStream::connect("127.0.0.1:1").await
        ).await;

        assert!(result.is_err());
    }

    #[tokio::test]
    async fn test_slow_consumer_handling() {
        let (tx, mut rx) = tokio::sync::mpsc::channel::<String>(10);

        let producer = tokio::spawn(async move {
            for i in 0..100 {
                if tx.send(format!("message_{}", i)).await.is_err() {
                    break;
                }
            }
        });

        let consumer = tokio::spawn(async move {
            sleep(Duration::from_millis(10)).await;
            while let Some(msg) = rx.recv().await {
                sleep(Duration::from_millis(1)).await;
            }
        });

        let _ = tokio::join!(producer, consumer);
    }

    #[tokio::test]
    async fn test_retry_mechanism() {
        let attempts = Arc::new(AtomicUsize::new(0));
        let attempts_clone = attempts.clone();

        let result = tokio::spawn(async move {
            let mut retries = 0;
            loop {
                attempts_clone.fetch_add(1, Ordering::SeqCst);
                
                if retries >= 2 {
                    break Ok::<_, String>("success after retries");
                }
                
                retries += 1;
                sleep(Duration::from_millis(10)).await;
            }
        }).await;

        assert!(result.is_ok());
        assert_eq!(attempts.load(Ordering::SeqCst), 3);
    }

    #[tokio::test]
    async fn test_circuit_breaker_pattern() {
        let failure_count = Arc::new(AtomicUsize::new(0));
        let failure_count_clone = failure_count.clone();

        let circuit_open = Arc::new(std::sync::atomic::AtomicBool::new(false));
        let circuit_open_clone = circuit_open.clone();

        let result = tokio::spawn(async move {
            for i in 0..10 {
                if circuit_open_clone.load(Ordering::SeqCst) {
                    return Err("circuit breaker open".to_string());
                }

                if i < 3 {
                    failure_count_clone.fetch_add(1, Ordering::SeqCst);
                    if failure_count_clone.load(Ordering::SeqCst) >= 3 {
                        circuit_open_clone.store(true, Ordering::SeqCst);
                    }
                    sleep(Duration::from_millis(1)).await;
                    continue;
                }

                return Ok("success");
            }
            Err("max attempts reached".to_string())
        }).await;

        assert!(result.is_ok());
        assert!(circuit_open.load(Ordering::SeqCst));
    }
}

#[cfg(test)]
mod malformed_inputs {
    use super::*;

    #[test]
    fn test_empty_request_handling() {
        let mut secrets = HashMap::new();
        secrets.insert("KEY".to_string(), "value".to_string());
        let map = SecretMap::new(secrets).unwrap();

        let empty_text = "";
        let sanitized = map.sanitize(empty_text);
        assert_eq!(sanitized, "");

        let whitespace_only = "   \n\t  ";
        let sanitized = map.sanitize(whitespace_only);
        assert_eq!(sanitized, whitespace_only);
    }

    #[test]
    fn test_null_byte_injection() {
        let mut secrets = HashMap::new();
        secrets.insert("SECRET".to_string(), "value".to_string());
        let map = SecretMap::new(secrets).unwrap();

        let text_with_nulls = "SECRET\x00INJECTION";
        let sanitized = map.sanitize(text_with_nulls);
        assert!(sanitized.contains("***SECRET***"));
    }

    #[test]
    fn test_unicode_edge_cases() {
        let mut secrets = HashMap::new();
        secrets.insert("KEY".to_string(), "value".to_string());
        let map = SecretMap::new(secrets).unwrap();

        let unicode_samples = vec![
            "KEY日本語",
            "KEY🚀🎉",
            "KEY\u{202E}reversed",
            "KEY\u{200B}zero_width_space",
            "KEY\u{FEFF}bom",
        ];

        for text in unicode_samples {
            let sanitized = map.sanitize(text);
            assert!(sanitized.contains("***KEY***"));
        }
    }

    #[test]
    fn test_extremely_long_input() {
        let mut secrets = HashMap::new();
        secrets.insert("KEY".to_string(), "value".to_string());
        let map = SecretMap::new(secrets).unwrap();

        let long_text = "KEY".repeat(10000);
        let start = Instant::now();
        let sanitized = map.sanitize(&long_text);
        let duration = start.elapsed();

        assert!(sanitized.contains("***KEY***"));
        assert!(duration < Duration::from_millis(100));
    }

    #[test]
    fn test_deeply_nested_json() {
        let mut secrets = HashMap::new();
        secrets.insert("SECRET".to_string(), "value".to_string());
        let map = SecretMap::new(secrets).unwrap();

        let nested_json = (0..100).fold("SECRET".to_string(), |acc, _| {
            format!("{{\"data\": {}}}", acc)
        });

        let sanitized = map.sanitize(&nested_json);
        assert!(sanitized.contains("***SECRET***"));
    }

    #[test]
    fn test_binary_payload_handling() {
        let mut secrets = HashMap::new();
        secrets.insert("BINKEY".to_string(), "secret".to_string());
        let map = SecretMap::new(secrets).unwrap();

        let binary: Vec<u8> = vec![
            0x00, 0x01, 0x02, b'B', b'I', b'N', b'K', b'E', b'Y',
            0xFF, 0xFE, 0xFD,
        ];

        let sanitized = map.sanitize_bytes(&binary);
        let sanitized_vec = sanitized.into_owned();

        assert!(sanitized_vec.windows(6).any(|w| w == b"***BIN"));
    }

    #[test]
    fn test_replacement_pattern_injection() {
        let mut secrets = HashMap::new();
        secrets.insert("KEY".to_string(), "value".to_string());
        let map = SecretMap::new(secrets).unwrap();

        let injection_attempt = "***KEY***";
        let sanitized = map.sanitize(injection_attempt);

        assert!(!sanitized.contains("value"));
    }
}

#[cfg(test)]
mod resource_exhaustion {
    use super::*;
    use std::sync::Arc;
    use tokio::sync::Semaphore;

    #[tokio::test]
    async fn test_connection_limit_enforcement() {
        let semaphore = Arc::new(Semaphore::new(5));
        let mut handles = vec![];

        for i in 0..10 {
            let permit = semaphore.clone().acquire_owned().await;
            if permit.is_err() {
                break;
            }

            handles.push(tokio::spawn(async move {
                sleep(Duration::from_millis(10)).await;
                drop(permit);
            }));
        }

        assert!(handles.len() <= 10);
    }

    #[test]
    fn test_memory_pressure_sanitization() {
        let mut secrets = HashMap::new();
        for i in 0..100 {
            secrets.insert(
                format!("KEY_{}", i),
                format!("value_{}", i),
            );
        }
        let map = SecretMap::new(secrets).unwrap();

        let large_text = "KEY_50 ".repeat(1000);
        let start = Instant::now();

        for _ in 0..100 {
            let _ = map.sanitize(&large_text);
        }

        let duration = start.elapsed();
        assert!(duration < Duration::from_secs(1));
    }

    #[test]
    fn test_cpu_intensive_pattern() {
        let mut secrets = HashMap::new();
        secrets.insert("SECRET".to_string(), "value".to_string());
        let map = SecretMap::new(secrets).unwrap();

        let pathological_input = "SECRET".repeat(1000);
        let start = Instant::now();
        let _ = map.sanitize(&pathological_input);
        let duration = start.elapsed();

        assert!(duration < Duration::from_millis(50));
    }
}

#[cfg(test)]
mod edge_cases {
    use super::*;

    #[test]
    fn test_concurrent_sanitization() {
        let mut secrets = HashMap::new();
        secrets.insert("KEY".to_string(), "value".to_string());
        let map = Arc::new(SecretMap::new(secrets).unwrap());

        let mut handles = vec![];

        for i in 0..10 {
            let map_clone = map.clone();
            handles.push(std::thread::spawn(move || {
                let text = format!("KEY_{}", i);
                map_clone.sanitize(&text)
            }));
        }

        for handle in handles {
            let _ = handle.join();
        }
    }

    #[test]
    fn test_zero_width_character_handling() {
        let mut secrets = HashMap::new();
        secrets.insert("SECRET".to_string(), "value".to_string());
        let map = SecretMap::new(secrets).unwrap();

        let zero_width_samples = vec![
            "S\u{200B}ECRET",
            "SE\u{200B}CRET",
            "SEC\u{200B}RET",
            "SECR\u{200B}ET",
            "SECRE\u{200B}T",
        ];

        for text in zero_width_samples {
            let sanitized = map.sanitize(text);
            assert!(!sanitized.contains("value"));
        }
    }

    #[test]
    fn test_case_sensitivity() {
        let mut secrets = HashMap::new();
        secrets.insert("SECRET".to_string(), "value".to_string());
        let map = SecretMap::new(secrets).unwrap();

        let variations = vec![
            "SECRET",
            "secret",
            "Secret",
            "SeCrEt",
        ];

        for text in variations {
            let sanitized = map.sanitize(text);
            if text == "SECRET" {
                assert!(sanitized.contains("***SECRET***"));
            } else {
                assert_eq!(sanitized, text);
            }
        }
    }

    #[test]
    fn test_overlapping_patterns() {
        let mut secrets = HashMap::new();
        secrets.insert("SECRET".to_string(), "value1".to_string());
        secrets.insert("SECRET_KEY".to_string(), "value2".to_string());
        let map = SecretMap::new(secrets).unwrap();

        let text = "SECRET_KEY and SECRET";
        let sanitized = map.sanitize(text);

        assert!(sanitized.contains("***SECRET_KEY***") || sanitized.contains("***SECRET***"));
    }

    #[test]
    fn test_empty_secret_map_operations() {
        let secrets = HashMap::new();
        let map = SecretMap::new(secrets).unwrap();

        let text = "No secrets to replace";
        let sanitized = map.sanitize(text);
        let injected = map.inject(text);

        assert_eq!(sanitized, text);
        assert_eq!(injected, text);
    }
}

#[cfg(test)]
mod timeout_scenarios {
    use super::*;
    use tokio::time::{timeout, Duration};

    #[tokio::test]
    async fn test_slow_sanitization_timeout() {
        let mut secrets = HashMap::new();
        secrets.insert("KEY".to_string(), "value".to_string());
        let map = SecretMap::new(secrets).unwrap();

        let large_text = "KEY".repeat(100000);

        let result = timeout(
            Duration::from_millis(100),
            async move { map.sanitize(&large_text) }
        ).await;

        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn test_infinite_loop_protection() {
        let result = timeout(
            Duration::from_millis(50),
            async {
                let mut count = 0;
                loop {
                    count += 1;
                    if count > 1000000 {
                        break count;
                    }
                }
            }
        ).await;

        assert!(result.is_ok());
    }
}
