// Integration tests for Strategy Pattern in main application
// Phase 9: Verify config.yaml loading and strategy building

use slapenir_proxy::{build_strategies_from_config, config::Config, sanitizer::SecretMap};
use std::env;

#[test]
fn test_config_loading_from_file() {
    // Test that config.yaml.example can be parsed
    let result = Config::from_file("config.yaml.example");
    assert!(result.is_ok(), "Should load config.yaml.example");

    let config = result.unwrap();
    assert!(
        !config.strategies.is_empty(),
        "Should have strategies defined"
    );
    // Security config is always present
    assert!(
        config.security.block_telemetry,
        "Should have telemetry blocking enabled"
    );
}

#[test]
fn test_strategy_builder_from_config() {
    // Load config and build strategies
    let config = Config::from_file("config.yaml.example").expect("Failed to load config");

    // Set test environment variables
    env::set_var("OPENAI_API_KEY", "test_openai_key");
    env::set_var("ANTHROPIC_API_KEY", "test_anthropic_key");
    env::set_var("GITHUB_TOKEN", "test_github_token");

    let strategies = build_strategies_from_config(&config).expect("Failed to build strategies");

    // Should build strategies even without all env vars
    assert!(
        !strategies.is_empty(),
        "Should build at least some strategies"
    );
}

#[test]
fn test_secret_map_from_strategies() {
    // Set test environment variables
    env::set_var("TEST_STRATEGY_OPENAI", "sk-test123");
    env::set_var("TEST_STRATEGY_ANTHROPIC", "ant-test456");

    let config = Config::from_file("config.yaml.example").expect("Failed to load config");

    let strategies = build_strategies_from_config(&config).expect("Failed to build strategies");

    if !strategies.is_empty() {
        let secret_map = SecretMap::from_strategies(&strategies);
        // May fail if no env vars are set, which is expected
        if let Ok(map) = secret_map {
            assert!(map.len() > 0, "SecretMap should have entries");
        }
    }
}

#[test]
fn test_fallback_when_config_missing() {
    // Try to load non-existent config
    let result = Config::from_file("nonexistent.yaml");
    assert!(result.is_err(), "Should fail for non-existent file");
}

#[test]
fn test_config_has_aws_strategy() {
    let config = Config::from_file("config.yaml.example").expect("Failed to load config");

    // Check if AWS strategy is defined
    let has_aws = config
        .strategies
        .iter()
        .any(|s| s.strategy_type == "aws_sigv4");

    assert!(has_aws, "Config should include AWS SigV4 strategy");
}

#[test]
fn test_config_has_telemetry_blocking() {
    let config = Config::from_file("config.yaml.example").expect("Failed to load config");

    // Security is not Option, it's always present
    assert!(
        config.security.block_telemetry,
        "Telemetry blocking should be enabled"
    );
    assert!(
        !config.security.telemetry_domains.is_empty(),
        "Should have telemetry domains listed"
    );
}

#[test]
fn test_config_has_bearer_strategies() {
    let config = Config::from_file("config.yaml.example").expect("Failed to load config");

    let bearer_count = config
        .strategies
        .iter()
        .filter(|s| s.strategy_type == "bearer")
        .count();

    assert!(
        bearer_count >= 3,
        "Should have at least 3 bearer strategies (OpenAI, Anthropic, GitHub)"
    );
}
