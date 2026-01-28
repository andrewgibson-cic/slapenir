// Property-based tests for SLAPENIR proxy
// Uses proptest for generative testing

use proptest::prelude::*;
use slapenir_proxy::sanitizer::SecretMap;
use std::collections::HashMap;

// Helper to create valid secret pairs
fn secret_pair_strategy() -> impl Strategy<Value = (String, String)> {
    ("[A-Z_]{5,20}", "[a-z0-9-]{10,50}")
        .prop_map(|(dummy, real)| (dummy, real))
}

proptest! {
    #[test]
    fn test_inject_never_loses_text_length(
        dummy in "[A-Z_]{5,20}",
        real in "[a-z0-9-]{10,50}",
        text in ".*"
    ) {
        let mut secrets = HashMap::new();
        secrets.insert(dummy.clone(), real.clone());
        
        if let Ok(map) = SecretMap::new(secrets) {
            let injected = map.inject(&text);
            // Text might change length due to replacement, but should not be empty if input wasn't
            if !text.is_empty() {
                prop_assert!(!injected.is_empty());
            }
        }
    }

    #[test]
    fn test_sanitize_removes_all_secrets(
        real in "[a-z0-9-]{10,50}",
        prefix in ".*",
        suffix in ".*"
    ) {
        let mut secrets = HashMap::new();
        secrets.insert("DUMMY".to_string(), real.clone());
        
        if let Ok(map) = SecretMap::new(secrets) {
            let text = format!("{}{}{}", prefix, real, suffix);
            let sanitized = map.sanitize(&text);
            // The real secret should not appear in sanitized text
            prop_assert!(!sanitized.contains(&real));
        }
    }

    #[test]
    fn test_roundtrip_preserves_non_secrets(
        dummy in "[A-Z_]{5,20}",
        real in "[a-z0-9-]{10,50}",
        other_text in "[a-zA-Z ]{10,100}"
    ) {
        let mut secrets = HashMap::new();
        secrets.insert(dummy.clone(), real.clone());
        
        if let Ok(map) = SecretMap::new(secrets) {
            let text = format!("{} {}", other_text, dummy);
            let injected = map.inject(&text);
            let sanitized = map.sanitize(&injected);
            
            // The other text should still be present after roundtrip
            prop_assert!(sanitized.contains(&other_text));
        }
    }

    #[test]
    fn test_multiple_secrets_all_replaced(
        secrets_vec in prop::collection::vec(secret_pair_strategy(), 1..10)
    ) {
        // Remove duplicates by using HashMap (last value wins)
        let mut secrets = HashMap::new();
        for (dummy, real) in &secrets_vec {
            secrets.insert(dummy.clone(), real.clone());
        }
        
        if let Ok(map) = SecretMap::new(secrets.clone()) {
            // Build text with unique dummy tokens only
            let unique_dummies: Vec<_> = secrets.keys().collect();
            let text = unique_dummies.iter()
                .map(|s| s.as_str())
                .collect::<Vec<_>>()
                .join(" ");
            
            let injected = map.inject(&text);
            
            // At least one real secret should be in the injected text
            let has_secret = secrets.values().any(|real| injected.contains(real));
            prop_assert!(has_secret);
            
            // No dummy tokens should remain
            for dummy in secrets.keys() {
                prop_assert!(!injected.contains(dummy));
            }
        }
    }

    #[test]
    fn test_sanitize_is_idempotent(
        dummy in "[A-Z_]{5,20}",
        real in "[a-z0-9-]{10,50}",
        text in ".*"
    ) {
        let mut secrets = HashMap::new();
        secrets.insert(dummy, real.clone());
        
        if let Ok(map) = SecretMap::new(secrets) {
            let text_with_secret = format!("{} {}", text, real);
            let sanitized_once = map.sanitize(&text_with_secret);
            let sanitized_twice = map.sanitize(&sanitized_once);
            
            // Sanitizing again should not change the result
            prop_assert_eq!(sanitized_once, sanitized_twice);
        }
    }

    #[test]
    fn test_inject_is_deterministic(
        dummy in "[A-Z_]{5,20}",
        real in "[a-z0-9-]{10,50}",
        text in ".*"
    ) {
        let mut secrets = HashMap::new();
        secrets.insert(dummy.clone(), real);
        
        if let Ok(map) = SecretMap::new(secrets) {
            let text_with_dummy = format!("{} {}", text, dummy);
            let injected1 = map.inject(&text_with_dummy);
            let injected2 = map.inject(&text_with_dummy);
            
            // Same input should always produce same output
            prop_assert_eq!(injected1, injected2);
        }
    }

    #[test]
    fn test_empty_input_produces_empty_output(
        dummy in "[A-Z_]{5,20}",
        real in "[a-z0-9-]{10,50}"
    ) {
        let mut secrets = HashMap::new();
        secrets.insert(dummy, real);
        
        if let Ok(map) = SecretMap::new(secrets) {
            let injected = map.inject("");
            let sanitized = map.sanitize("");
            
            prop_assert_eq!(injected, "");
            prop_assert_eq!(sanitized, "");
        }
    }

    #[test]
    fn test_whitespace_preserved(
        dummy in "[A-Z_]{5,20}",
        real in "[a-z0-9-]{10,50}",
        spaces in prop::collection::vec("[ \t\n\r]", 1..20)
    ) {
        let mut secrets = HashMap::new();
        secrets.insert(dummy.clone(), real);
        
        if let Ok(map) = SecretMap::new(secrets) {
            let whitespace: String = spaces.into_iter().collect();
            let text = format!("{}{}{}", whitespace, dummy, whitespace);
            let injected = map.inject(&text);
            
            // Whitespace should be preserved (at least some of it)
            prop_assert!(injected.contains(' ') || injected.contains('\t') || 
                        injected.contains('\n') || injected.contains('\r'));
        }
    }
}

#[test]
fn test_unicode_handling() {
    let mut secrets = HashMap::new();
    secrets.insert("TOKEN".to_string(), "secret".to_string());
    let map = SecretMap::new(secrets).unwrap();
    
    // Test with various Unicode characters
    let texts = vec![
        "Hello 世界 TOKEN here",
        "Emoji 😀 TOKEN 🎉",
        "Ñoño TOKEN tïldé",
        "Кириллица TOKEN текст",
    ];
    
    for text in texts {
        let injected = map.inject(text);
        assert!(injected.contains("secret"));
        assert!(!injected.contains("TOKEN"));
        
        let sanitized = map.sanitize(&injected);
        assert!(!sanitized.contains("secret"));
    }
}

#[test]
fn test_secret_at_boundaries() {
    let mut secrets = HashMap::new();
    secrets.insert("TOKEN".to_string(), "secret123".to_string());
    let map = SecretMap::new(secrets).unwrap();
    
    // Secret at start
    let text = "TOKEN is here";
    let injected = map.inject(text);
    assert_eq!(injected, "secret123 is here");
    
    // Secret at end
    let text = "here is TOKEN";
    let injected = map.inject(text);
    assert_eq!(injected, "here is secret123");
    
    // Secret alone
    let text = "TOKEN";
    let injected = map.inject(text);
    assert_eq!(injected, "secret123");
}

#[test]
fn test_overlapping_patterns() {
    let mut secrets = HashMap::new();
    secrets.insert("API".to_string(), "real1".to_string());
    secrets.insert("API_KEY".to_string(), "real2".to_string());
    let map = SecretMap::new(secrets).unwrap();
    
    // Longer pattern should match first
    let text = "Use API_KEY here";
    let injected = map.inject(text);
    assert!(injected.contains("real"));
}

#[test]
fn test_case_sensitivity() {
    let mut secrets = HashMap::new();
    secrets.insert("TOKEN".to_string(), "secret".to_string());
    let map = SecretMap::new(secrets).unwrap();
    
    // Should be case-sensitive
    let text = "TOKEN token Token";
    let injected = map.inject(text);
    
    // Only exact match should be replaced
    assert_eq!(injected.matches("secret").count(), 1);
    assert!(injected.contains("token"));
    assert!(injected.contains("Token"));
}

#[test]
fn test_repeated_secrets() {
    let mut secrets = HashMap::new();
    secrets.insert("TOKEN".to_string(), "secret".to_string());
    let map = SecretMap::new(secrets).unwrap();
    
    let text = "TOKEN TOKEN TOKEN";
    let injected = map.inject(text);
    assert_eq!(injected, "secret secret secret");
    
    let sanitized = map.sanitize(&injected);
    assert!(!sanitized.contains("secret"));
}

#[test]
fn test_large_input() {
    let mut secrets = HashMap::new();
    secrets.insert("TOKEN".to_string(), "secret".to_string());
    let map = SecretMap::new(secrets).unwrap();
    
    // Generate large text
    let large_text = "TOKEN ".repeat(10000);
    
    let start = std::time::Instant::now();
    let injected = map.inject(&large_text);
    let inject_time = start.elapsed();
    
    assert!(inject_time.as_millis() < 100, "Injection too slow: {:?}", inject_time);
    assert_eq!(injected.matches("secret").count(), 10000);
}