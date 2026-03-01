#!/usr/bin/env python3
"""
Test: OpenCode Permission Enforcement
Specification: SPEC-011
Requirement: REQ-011

Tests verify that OpenCode permissions are correctly configured and enforced.
"""

import json
import sys
import os


def load_config():
    """Load OpenCode configuration"""
    config_path = '/home/agent/.opencode/config.json'
    if not os.path.exists(config_path):
        raise FileNotFoundError(f"Config file not found: {config_path}")

    with open(config_path, 'r') as f:
        return json.load(f)


def test_bash_denied():
    """Test that bash tool is denied"""
    config = load_config()
    assert config['permission']['bash'] == 'deny', "bash should be denied"
    print("✓ bash tool denied")


def test_webfetch_denied():
    """Test that webfetch tool is denied"""
    config = load_config()
    assert config['permission']['webfetch'] == 'deny', "webfetch should be denied"
    print("✓ webfetch tool denied")


def test_mcp_denied():
    """Test that MCP tools are denied"""
    config = load_config()
    assert config['permission']['mcp_*'] == 'deny', "MCP tools should be denied"
    print("✓ MCP tools denied")


def test_read_allowed():
    """Test that read tool is allowed"""
    config = load_config()
    assert config['permission']['read'] == 'allow', "read should be allowed"
    print("✓ read tool allowed")


def test_edit_ask():
    """Test that edit tool requires approval"""
    config = load_config()
    assert config['permission']['edit'] == 'ask', "edit should require approval"
    print("✓ edit tool requires approval")


def test_websearch_disabled():
    """Test that websearch is disabled"""
    config = load_config()
    assert config['tools']['websearch'] == False, "websearch should be disabled"
    print("✓ websearch disabled")


def test_autoupdate_disabled():
    """Test that autoupdate is disabled"""
    config = load_config()
    assert config['autoupdate'] == False, "autoupdate should be disabled"
    print("✓ autoupdate disabled")


def test_opentelemetry_disabled():
    """Test that OpenTelemetry is disabled"""
    config = load_config()
    assert config['experimental']['openTelemetry'] == False, "OpenTelemetry should be disabled"
    print("✓ OpenTelemetry disabled")


def test_share_disabled():
    """Test that share is disabled"""
    config = load_config()
    assert config['share'] == 'disabled', "share should be disabled"
    print("✓ share disabled")


def test_instructions_empty():
    """Test that instructions array is empty"""
    config = load_config()
    assert config['instructions'] == [], "instructions should be empty"
    print("✓ instructions empty")


def test_wildcard_deny():
    """Test that wildcard is set to deny"""
    config = load_config()
    assert config['permission']['*'] == 'deny', "wildcard should be deny"
    print("✓ wildcard deny")


def test_provider_local():
    """Test that provider uses local llama server"""
    config = load_config()
    assert 'local-llama' in config['provider'], "local-llama provider should exist"
    base_url = config['provider']['local-llama']['options']['baseURL']
    assert 'host.docker.internal:8080' in base_url, "should use host.docker.internal:8080"
    print("✓ provider uses local llama server")


def test_model_configuration():
    """Test that model configuration is correct"""
    config = load_config()
    models = config['provider']['local-llama']['models']
    assert len(models) > 0, "at least one model should be configured"

    # Check first model has required fields
    model_name = list(models.keys())[0]
    model_config = models[model_name]
    assert 'name' in model_config, "model should have name"
    assert 'limit' in model_config, "model should have limit"
    assert 'context' in model_config['limit'], "model limit should have context"
    assert 'output' in model_config['limit'], "model limit should have output"

    print(f"✓ model configuration valid ({model_name})")


def main():
    """Run all tests"""
    tests = [
        test_bash_denied,
        test_webfetch_denied,
        test_mcp_denied,
        test_read_allowed,
        test_edit_ask,
        test_websearch_disabled,
        test_autoupdate_disabled,
        test_opentelemetry_disabled,
        test_share_disabled,
        test_instructions_empty,
        test_wildcard_deny,
        test_provider_local,
        test_model_configuration,
    ]

    print("=== OpenCode Permission Enforcement Tests ===\n")

    passed = 0
    failed = 0

    for test in tests:
        try:
            test()
            passed += 1
        except AssertionError as e:
            print(f"✗ {test.__name__}: {e}")
            failed += 1
        except Exception as e:
            print(f"✗ {test.__name__}: Unexpected error: {e}")
            failed += 1

    print(f"\n=== Results ===")
    print(f"Passed: {passed}")
    print(f"Failed: {failed}")

    if failed == 0:
        print("\n✅ All permission tests passed")
        return 0
    else:
        print("\n❌ Some permission tests failed")
        return 1


if __name__ == '__main__':
    sys.exit(main())
