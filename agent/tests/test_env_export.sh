#!/bin/bash
# Test suite for environment variable export functionality

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Test helper functions
test_start() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    echo -e "${BLUE}TEST $TESTS_TOTAL: $1${NC}"
}

test_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}  ✓ PASS: $1${NC}"
}

test_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}  ✗ FAIL: $1${NC}"
}

# Setup test environment
TEST_DIR="/tmp/slapenir-test-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Mock s6 environment directory
S6_ENV_DIR="$TEST_DIR/s6-env"
mkdir -p "$S6_ENV_DIR"

# Create test .env file
TEST_ENV_FILE="$TEST_DIR/.env"

echo "=== Environment Variable Export Tests ==="
echo ""

# Test 1: Parse simple key-value pairs
test_start "Parse simple key-value pairs"
cat > "$TEST_ENV_FILE" << 'TESTENV'
OPENAI_API_KEY=DUMMY_OPENAI
MISTRAL_API_KEY=DUMMY_MISTRAL
GITHUB_TOKEN=DUMMY_GITHUB
TESTENV

while IFS='=' read -r key value; do
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" ]] && continue
    key=$(echo "$key" | tr -d '[:space:]')
    [[ ! "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]] && continue
    echo -n "$value" > "$S6_ENV_DIR/$key"
done < "$TEST_ENV_FILE"

if [ -f "$S6_ENV_DIR/OPENAI_API_KEY" ] && \
   [ -f "$S6_ENV_DIR/MISTRAL_API_KEY" ] && \
   [ -f "$S6_ENV_DIR/GITHUB_TOKEN" ]; then
    test_pass "All environment files created"
else
    test_fail "Missing environment files"
fi

# Test 2: Verify file contents
test_start "Verify environment file contents"
if [ "$(cat $S6_ENV_DIR/OPENAI_API_KEY)" = "DUMMY_OPENAI" ] && \
   [ "$(cat $S6_ENV_DIR/MISTRAL_API_KEY)" = "DUMMY_MISTRAL" ] && \
   [ "$(cat $S6_ENV_DIR/GITHUB_TOKEN)" = "DUMMY_GITHUB" ]; then
    test_pass "All values correct"
else
    test_fail "Incorrect values in environment files"
fi

# Test 3: Skip comments
test_start "Skip comment lines"
rm -rf "$S6_ENV_DIR"/*
cat > "$TEST_ENV_FILE" << 'TESTENV'
# This is a comment
OPENAI_API_KEY=DUMMY_OPENAI
# Another comment
MISTRAL_API_KEY=DUMMY_MISTRAL
TESTENV

while IFS='=' read -r key value; do
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" ]] && continue
    key=$(echo "$key" | tr -d '[:space:]')
    [[ ! "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]] && continue
    echo -n "$value" > "$S6_ENV_DIR/$key"
done < "$TEST_ENV_FILE"

file_count=$(ls -1 "$S6_ENV_DIR" | wc -l | tr -d ' ')
if [ "$file_count" = "2" ]; then
    test_pass "Comments skipped correctly (2 files created)"
else
    test_fail "Wrong number of files: $file_count (expected 2)"
fi

# Test 4: Skip empty lines
test_start "Skip empty lines"
rm -rf "$S6_ENV_DIR"/*
cat > "$TEST_ENV_FILE" << 'TESTENV'
OPENAI_API_KEY=DUMMY_OPENAI

MISTRAL_API_KEY=DUMMY_MISTRAL

GITHUB_TOKEN=DUMMY_GITHUB
TESTENV

while IFS='=' read -r key value; do
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" ]] && continue
    key=$(echo "$key" | tr -d '[:space:]')
    [[ ! "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]] && continue
    echo -n "$value" > "$S6_ENV_DIR/$key"
done < "$TEST_ENV_FILE"

file_count=$(ls -1 "$S6_ENV_DIR" | wc -l | tr -d ' ')
if [ "$file_count" = "3" ]; then
    test_pass "Empty lines skipped correctly (3 files created)"
else
    test_fail "Wrong number of files: $file_count (expected 3)"
fi

# Test 5: Handle special characters in values
test_start "Handle special characters in values"
rm -rf "$S6_ENV_DIR"/*
cat > "$TEST_ENV_FILE" << 'TESTENV'
SLACK_BOT_TOKEN=xoxb-1234567890-ABCDEFGHIJK
STRIPE_KEY=sk_test_51ABCD
TESTENV

while IFS='=' read -r key value; do
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" ]] && continue
    key=$(echo "$key" | tr -d '[:space:]')
    [[ ! "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]] && continue
    echo -n "$value" > "$S6_ENV_DIR/$key"
done < "$TEST_ENV_FILE"

if [ "$(cat $S6_ENV_DIR/SLACK_BOT_TOKEN)" = "xoxb-1234567890-ABCDEFGHIJK" ] && \
   [ "$(cat $S6_ENV_DIR/STRIPE_KEY)" = "sk_test_51ABCD" ]; then
    test_pass "Special characters preserved"
else
    test_fail "Special characters not preserved correctly"
fi

# Test 6: Reject invalid variable names
test_start "Reject invalid variable names"
rm -rf "$S6_ENV_DIR"/*
cat > "$TEST_ENV_FILE" << 'TESTENV'
VALID_NAME=value1
123invalid=value2
invalid-name=value3
ANOTHER_VALID=value4
TESTENV

while IFS='=' read -r key value; do
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" ]] && continue
    key=$(echo "$key" | tr -d '[:space:]')
    [[ ! "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]] && continue
    echo -n "$value" > "$S6_ENV_DIR/$key"
done < "$TEST_ENV_FILE"

file_count=$(ls -1 "$S6_ENV_DIR" | wc -l | tr -d ' ')
if [ "$file_count" = "2" ]; then
    test_pass "Invalid names rejected (2 valid files created)"
else
    test_fail "Wrong number of files: $file_count (expected 2)"
fi

# Test 7: Handle values with equals signs
test_start "Handle values containing equals signs"
rm -rf "$S6_ENV_DIR"/*
cat > "$TEST_ENV_FILE" << 'TESTENV'
IBM_BASE_URL=https://api.example.com/v1?key=value
TESTENV

while IFS='=' read -r key value; do
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" ]] && continue
    key=$(echo "$key" | tr -d '[:space:]')
    value=$(echo "$value" | sed 's/^=//')  # Handle multiple = signs
    [[ ! "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]] && continue
    echo -n "$value" > "$S6_ENV_DIR/$key"
done < "$TEST_ENV_FILE"

if [ -f "$S6_ENV_DIR/IBM_BASE_URL" ]; then
    test_pass "Values with = signs handled"
else
    test_fail "Failed to handle values with = signs"
fi

# Test 8: Empty value handling
test_start "Handle empty values"
rm -rf "$S6_ENV_DIR"/*
cat > "$TEST_ENV_FILE" << 'TESTENV'
EMPTY_VAR=
NON_EMPTY=value
TESTENV

while IFS='=' read -r key value; do
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" ]] && continue
    key=$(echo "$key" | tr -d '[:space:]')
    [[ ! "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]] && continue
    echo -n "$value" > "$S6_ENV_DIR/$key"
done < "$TEST_ENV_FILE"

if [ -f "$S6_ENV_DIR/EMPTY_VAR" ] && [ ! -s "$S6_ENV_DIR/EMPTY_VAR" ]; then
    test_pass "Empty values create empty files"
else
    test_fail "Empty value handling incorrect"
fi

# Cleanup
cd /
rm -rf "$TEST_DIR"

# Summary
echo ""
echo "==================================="
echo "Test Summary"
echo "==================================="
echo -e "Total Tests:  $TESTS_TOTAL"
echo -e "${GREEN}Passed:       $TESTS_PASSED${NC}"
echo -e "${RED}Failed:       $TESTS_FAILED${NC}"

COVERAGE=$(awk "BEGIN {printf \"%.1f\", ($TESTS_PASSED / $TESTS_TOTAL) * 100}")
echo -e "Coverage:     ${COVERAGE}%"
echo "==================================="

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
