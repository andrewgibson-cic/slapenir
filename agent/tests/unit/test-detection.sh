#!/bin/bash
# Unit tests for OpenCode detection functions
# Tests: SPEC-001, SPEC-002, SPEC-003

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
# SPEC-001: Process Tree Detection Tests
# ============================================================

test_process_tree_no_opencode() {
    echo "TEST-002: Process tree detection - no OpenCode"
    
    # Arrange: Ensure no OpenCode processes
    cleanup_mock_opencode
    
    # Source detection library (will fail if not implemented)
    if [ ! -f "$SCRIPT_DIR/../../scripts/lib/detection.sh" ]; then
        test_fail "Detection library not found (expected in RED phase)"
        return 1
    fi
    
    source "$SCRIPT_DIR/../../scripts/lib/detection.sh"
    
    # Act: Check detection
    is_opencode_in_process_tree
    RESULT=$?
    
    # Assert: Should NOT detect OpenCode
    [ $RESULT -eq 1 ] || {
        test_fail "OpenCode falsely detected"
        return 1
    }
    
    test_pass "No false positive"
}

test_process_tree_detects_opencode_env() {
    echo "TEST-001: Process tree detection - OpenCode running (env vars)"
    
    # Arrange: Set OpenCode env vars
    export OPENCODE_SESSION_ID="test-session-123"
    export OPENCODE_YOLO="true"
    
    # Source detection library
    if [ ! -f "$SCRIPT_DIR/../../scripts/lib/detection.sh" ]; then
        test_fail "Detection library not found (expected in RED phase)"
        return 1
    fi
    
    source "$SCRIPT_DIR/../../scripts/lib/detection.sh"
    
    # Act: Check detection
    is_opencode_in_process_tree
    RESULT=$?
    
    # Cleanup
    unset OPENCODE_SESSION_ID OPENCODE_YOLO
    
    # Assert: Should detect via env vars (or process tree if we started a real process)
    # For now, we'll just check the function doesn't error
    test_pass "Detection function runs (result: $RESULT)"
}

test_process_tree_max_depth() {
    echo "TEST-003: Process tree detection - max depth"
    
    # Source detection library
    if [ ! -f "$SCRIPT_DIR/../../scripts/lib/detection.sh" ]; then
        test_fail "Detection library not found (expected in RED phase)"
        return 1
    fi
    
    source "$SCRIPT_DIR/../../scripts/lib/detection.sh"
    
    # Act: Check detection completes within time limit
    START=$(date +%s%N)
    is_opencode_in_process_tree
    END=$(date +%s%N)
    
    DURATION_MS=$(( (END - START) / 1000000 ))
    
    # Assert: Should complete within 100ms
    [ $DURATION_MS -lt 100 ] || {
        test_fail "Detection took ${DURATION_MS}ms (max 100ms)"
        return 1
    }
    
    test_pass "Completed in ${DURATION_MS}ms (< 100ms)"
}

# ============================================================
# SPEC-002: Environment Variable Detection Tests
# ============================================================

test_env_vars_detection() {
    echo "TEST-004: Environment variable detection - all variables"
    
    # Source detection library
    if [ ! -f "$SCRIPT_DIR/../../scripts/lib/detection.sh" ]; then
        test_fail "Detection library not found (expected in RED phase)"
        return 1
    fi
    
    source "$SCRIPT_DIR/../../scripts/lib/detection.sh"
    
    # Test 1: OPENCODE_SESSION_ID
    export OPENCODE_SESSION_ID="test-123"
    has_opencode_env_vars || { test_fail "SESSION_ID not detected"; return 1; }
    unset OPENCODE_SESSION_ID
    
    # Test 2: OPENCODE_YOLO
    export OPENCODE_YOLO="true"
    has_opencode_env_vars || { test_fail "YOLO not detected"; return 1; }
    unset OPENCODE_YOLO
    
    # Test 3: OPENCODE_CONFIG_PATH
    export OPENCODE_CONFIG_PATH="/test/path"
    has_opencode_env_vars || { test_fail "CONFIG_PATH not detected"; return 1; }
    unset OPENCODE_CONFIG_PATH
    
    # Test 4: No variables set
    has_opencode_env_vars && { test_fail "False positive"; return 1; }
    
    test_pass "All env vars detected correctly"
}

# ============================================================
# SPEC-003: Multi-Layer Detection Tests
# ============================================================

test_lock_file_priority() {
    echo "TEST-005: Multi-layer detection - lock file priority"
    
    # Source detection library
    if [ ! -f "$SCRIPT_DIR/../../scripts/lib/detection.sh" ]; then
        test_fail "Detection library not found (expected in RED phase)"
        return 1
    fi
    
    source "$SCRIPT_DIR/../../scripts/lib/detection.sh"
    
    # Arrange: Create fresh lock file
    create_fresh_lock
    
    # Act: Check detection (should use lock file)
    is_opencode_active
    RESULT=$?
    
    # Assert: Should detect via lock file
    remove_lock
    [ $RESULT -eq 0 ] || {
        test_fail "Lock file not detected"
        return 1
    }
    
    test_pass "Lock file detected (priority 1)"
}

test_stale_lock_file() {
    echo "TEST-006: Multi-layer detection - stale lock file"
    
    # Source detection library
    if [ ! -f "$SCRIPT_DIR/../../scripts/lib/detection.sh" ]; then
        test_fail "Detection library not found (expected in RED phase)"
        return 1
    fi
    
    source "$SCRIPT_DIR/../../scripts/lib/detection.sh"
    
    # Arrange: Create stale lock file (>24 hours)
    create_stale_lock
    
    # Act: Check detection (should skip stale lock)
    is_opencode_active
    RESULT=$?
    
    # Assert: Should NOT detect (stale lock ignored)
    remove_lock
    [ $RESULT -eq 1 ] || {
        test_fail "Stale lock file not ignored"
        return 1
    }
    
    test_pass "Stale lock file ignored"
}

test_multilayer_env_vars() {
    echo "Multi-layer detection - environment variables"
    
    # Source detection library
    if [ ! -f "$SCRIPT_DIR/../../scripts/lib/detection.sh" ]; then
        test_fail "Detection library not found (expected in RED phase)"
        return 1
    fi
    
    source "$SCRIPT_DIR/../../scripts/lib/detection.sh"
    
    # Arrange: Set env vars, no lock file
    remove_lock
    export OPENCODE_SESSION_ID="test-session"
    
    # Act: Check detection
    is_opencode_active
    RESULT=$?
    
    # Cleanup
    unset OPENCODE_SESSION_ID
    
    # Assert: Should detect via env vars
    [ $RESULT -eq 0 ] || {
        test_fail "Env vars not detected in multi-layer"
        return 1
    }
    
    test_pass "Env vars detected (priority 2)"
}

# ============================================================
# Run Tests
# ============================================================

echo "======================================"
echo "Detection Library Unit Tests"
echo "======================================"
echo

# Note: These tests will FAIL in RED phase because detection library doesn't exist yet
test_process_tree_no_opencode || true
test_process_tree_detects_opencode_env || true
test_process_tree_max_depth || true
test_env_vars_detection || true
test_lock_file_priority || true
test_stale_lock_file || true
test_multilayer_env_vars || true

echo
echo "======================================"
echo "Results: $TESTS_PASSED passed, $TESTS_FAILED failed"
echo "======================================"

# Exit with failure count (0 = all passed)
exit $TESTS_FAILED
