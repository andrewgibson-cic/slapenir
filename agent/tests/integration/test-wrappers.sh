#!/bin/bash
# Integration tests for build tool wrappers
# Tests: SPEC-004 to SPEC-011

set -euo pipefail

# Test framework
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
TESTS_PASSED=0
TESTS_FAILED=0

test_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓${NC} $1"
}

test_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗${NC} $1"
}

# Source test fixtures
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../fixtures/mock-opencode-session.sh"

# ============================================================
# SPEC-004: Gradle Wrapper Tests
# ============================================================

test_gradle_blocked_with_opencode() {
    echo "TEST-007: Gradle blocked with OpenCode session"
    
    # Arrange: Setup mock OpenCode session
    setup_mock_opencode
    
    # Check if gradle wrapper exists
    if [ ! -f "$SCRIPT_DIR/../../scripts/gradle-wrapper" ]; then
        test_fail "Gradle wrapper not found (expected in RED phase)"
        cleanup_mock_opencode
        return 1
    fi
    
    # Act: Try to run gradle wrapper
    "$SCRIPT_DIR/../../scripts/gradle-wrapper" --version 2>&1 | grep -q "BUILD TOOL BLOCKED"
    RESULT=$?
    
    # Assert: Should be blocked
    cleanup_mock_opencode
    [ $RESULT -eq 0 ] || {
        test_fail "Gradle not blocked with OpenCode active"
        return 1
    }
    
    test_pass "Gradle blocked with OpenCode session"
}

test_gradle_allowed_without_opencode() {
    echo "TEST-008: Gradle allowed without OpenCode session"
    
    # Arrange: Ensure no OpenCode session
    cleanup_mock_opencode
    
    # Check if gradle wrapper exists
    if [ ! -f "$SCRIPT_DIR/../../scripts/gradle-wrapper" ]; then
        test_fail "Gradle wrapper not found (expected in RED phase)"
        return 1
    fi
    
    # Check if real gradle exists
    if [ ! -f "/usr/bin/gradle.real" ]; then
        test_pass "Gradle skipped (real binary not found - OK for development)"
        return 0
    fi
    
    # Act: Run gradle wrapper
    "$SCRIPT_DIR/../../scripts/gradle-wrapper" --version >/dev/null 2>&1
    RESULT=$?
    
    # Assert: Should succeed
    [ $RESULT -eq 0 ] || {
        test_fail "Gradle blocked when it should be allowed"
        return 1
    }
    
    test_pass "Gradle allowed without OpenCode session"
}

test_gradle_override() {
    echo "TEST-018: Gradle override mechanism"
    
    # Arrange: Setup mock OpenCode session
    setup_mock_opencode
    
    # Check if gradle wrapper exists
    if [ ! -f "$SCRIPT_DIR/../../scripts/gradle-wrapper" ]; then
        test_fail "Gradle wrapper not found (expected in RED phase)"
        cleanup_mock_opencode
        return 1
    fi
    
    # Check if real gradle exists
    if [ ! -f "/usr/bin/gradle.real" ]; then
        test_pass "Gradle override skipped (real binary not found)"
        cleanup_mock_opencode
        return 0
    fi
    
    # Act: Try to run gradle with override
    GRADLE_ALLOW_FROM_OPENCODE=1 "$SCRIPT_DIR/../../scripts/gradle-wrapper" --version >/dev/null 2>&1
    RESULT=$?
    
    # Assert: Should succeed with override
    cleanup_mock_opencode
    [ $RESULT -eq 0 ] || {
        test_fail "Gradle override not working"
        return 1
    }
    
    test_pass "Gradle override mechanism works"
}

# ============================================================
# SPEC-005: Maven Wrapper Tests
# ============================================================

test_maven_blocked_with_opencode() {
    echo "TEST-011: Maven blocked with OpenCode session"
    
    # Arrange: Setup mock OpenCode session
    setup_mock_opencode
    
    # Check if mvn wrapper exists
    if [ ! -f "$SCRIPT_DIR/../../scripts/mvn-wrapper" ]; then
        test_fail "Maven wrapper not found (expected in RED phase)"
        cleanup_mock_opencode
        return 1
    fi
    
    # Act: Try to run mvn wrapper
    "$SCRIPT_DIR/../../scripts/mvn-wrapper" --version 2>&1 | grep -q "BUILD TOOL BLOCKED"
    RESULT=$?
    
    # Assert: Should be blocked
    cleanup_mock_opencode
    [ $RESULT -eq 0 ] || {
        test_fail "Maven not blocked with OpenCode active"
        return 1
    }
    
    test_pass "Maven blocked with OpenCode session"
}

# ============================================================
# SPEC-006: npm Wrapper Tests
# ============================================================

test_npm_blocked_with_opencode() {
    echo "TEST-012: npm blocked with OpenCode session"
    
    # Arrange: Setup mock OpenCode session
    setup_mock_opencode
    
    # Check if npm wrapper exists
    if [ ! -f "$SCRIPT_DIR/../../scripts/npm-wrapper" ]; then
        test_fail "npm wrapper not found (expected in RED phase)"
        cleanup_mock_opencode
        return 1
    fi
    
    # Act: Try to run npm wrapper
    "$SCRIPT_DIR/../../scripts/npm-wrapper" --version 2>&1 | grep -q "BUILD TOOL BLOCKED"
    RESULT=$?
    
    # Assert: Should be blocked
    cleanup_mock_opencode
    [ $RESULT -eq 0 ] || {
        test_fail "npm not blocked with OpenCode active"
        return 1
    }
    
    test_pass "npm blocked with OpenCode session"
}

# ============================================================
# SPEC-007: Yarn Wrapper Tests
# ============================================================

test_yarn_blocked_with_opencode() {
    echo "TEST-013: Yarn blocked with OpenCode session"
    
    # Arrange: Setup mock OpenCode session
    setup_mock_opencode
    
    # Check if yarn wrapper exists
    if [ ! -f "$SCRIPT_DIR/../../scripts/yarn-wrapper" ]; then
        test_fail "Yarn wrapper not found (expected in RED phase)"
        cleanup_mock_opencode
        return 1
    fi
    
    # Act: Try to run yarn wrapper
    "$SCRIPT_DIR/../../scripts/yarn-wrapper" --version 2>&1 | grep -q "BUILD TOOL BLOCKED"
    RESULT=$?
    
    # Assert: Should be blocked
    cleanup_mock_opencode
    [ $RESULT -eq 0 ] || {
        test_fail "Yarn not blocked with OpenCode active"
        return 1
    }
    
    test_pass "Yarn blocked with OpenCode session"
}

# ============================================================
# SPEC-008: pnpm Wrapper Tests
# ============================================================

test_pnpm_blocked_with_opencode() {
    echo "TEST-014: pnpm blocked with OpenCode session"
    
    # Arrange: Setup mock OpenCode session
    setup_mock_opencode
    
    # Check if pnpm wrapper exists
    if [ ! -f "$SCRIPT_DIR/../../scripts/pnpm-wrapper" ]; then
        test_fail "pnpm wrapper not found (expected in RED phase)"
        cleanup_mock_opencode
        return 1
    fi
    
    # Act: Try to run pnpm wrapper
    "$SCRIPT_DIR/../../scripts/pnpm-wrapper" --version 2>&1 | grep -q "BUILD TOOL BLOCKED"
    RESULT=$?
    
    # Assert: Should be blocked
    cleanup_mock_opencode
    [ $RESULT -eq 0 ] || {
        test_fail "pnpm not blocked with OpenCode active"
        return 1
    }
    
    test_pass "pnpm blocked with OpenCode session"
}

# ============================================================
# SPEC-009: Cargo Wrapper Tests
# ============================================================

test_cargo_blocked_with_opencode() {
    echo "TEST-015: Cargo blocked with OpenCode session"
    
    # Arrange: Setup mock OpenCode session
    setup_mock_opencode
    
    # Check if cargo wrapper exists
    if [ ! -f "$SCRIPT_DIR/../../scripts/cargo-wrapper" ]; then
        test_fail "Cargo wrapper not found (expected in RED phase)"
        cleanup_mock_opencode
        return 1
    fi
    
    # Act: Try to run cargo wrapper
    "$SCRIPT_DIR/../../scripts/cargo-wrapper" --version 2>&1 | grep -q "BUILD TOOL BLOCKED"
    RESULT=$?
    
    # Assert: Should be blocked
    cleanup_mock_opencode
    [ $RESULT -eq 0 ] || {
        test_fail "Cargo not blocked with OpenCode active"
        return 1
    }
    
    test_pass "Cargo blocked with OpenCode session"
}

# ============================================================
# SPEC-010: pip Wrapper Tests
# ============================================================

test_pip_blocked_with_opencode() {
    echo "TEST-016: pip blocked with OpenCode session"
    
    # Arrange: Setup mock OpenCode session
    setup_mock_opencode
    
    # Check if pip wrapper exists
    if [ ! -f "$SCRIPT_DIR/../../scripts/pip-wrapper" ]; then
        test_fail "pip wrapper not found (expected in RED phase)"
        cleanup_mock_opencode
        return 1
    fi
    
    # Act: Try to run pip wrapper
    "$SCRIPT_DIR/../../scripts/pip-wrapper" --version 2>&1 | grep -q "BUILD TOOL BLOCKED"
    RESULT=$?
    
    # Assert: Should be blocked
    cleanup_mock_opencode
    [ $RESULT -eq 0 ] || {
        test_fail "pip not blocked with OpenCode active"
        return 1
    }
    
    test_pass "pip blocked with OpenCode session"
}

# ============================================================
# SPEC-011: pip3 Wrapper Tests
# ============================================================

test_pip3_blocked_with_opencode() {
    echo "TEST-017: pip3 blocked with OpenCode session"
    
    # Arrange: Setup mock OpenCode session
    setup_mock_opencode
    
    # Check if pip3 wrapper exists
    if [ ! -f "$SCRIPT_DIR/../../scripts/pip3-wrapper" ]; then
        test_fail "pip3 wrapper not found (expected in RED phase)"
        cleanup_mock_opencode
        return 1
    fi
    
    # Act: Try to run pip3 wrapper
    "$SCRIPT_DIR/../../scripts/pip3-wrapper" --version 2>&1 | grep -q "BUILD TOOL BLOCKED"
    RESULT=$?
    
    # Assert: Should be blocked
    cleanup_mock_opencode
    [ $RESULT -eq 0 ] || {
        test_fail "pip3 not blocked with OpenCode active"
        return 1
    }
    
    test_pass "pip3 blocked with OpenCode session"
}

# ============================================================
# Run Tests
# ============================================================

echo "======================================"
echo "Build Tool Wrapper Integration Tests"
echo "======================================"
echo

# Note: These tests will FAIL in RED phase because wrappers don't exist yet
test_gradle_blocked_with_opencode || true
test_gradle_allowed_without_opencode || true
test_gradle_override || true
test_maven_blocked_with_opencode || true
test_npm_blocked_with_opencode || true
test_yarn_blocked_with_opencode || true
test_pnpm_blocked_with_opencode || true
test_cargo_blocked_with_opencode || true
test_pip_blocked_with_opencode || true
test_pip3_blocked_with_opencode || true

echo
echo "======================================"
echo "Results: $TESTS_PASSED passed, $TESTS_FAILED failed"
echo "======================================"

# Exit with failure count (0 = all passed)
exit $TESTS_FAILED
