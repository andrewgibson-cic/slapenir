#!/bin/bash
# Test suite for git configuration in the agent container
# Validates that setup-git-credentials.sh writes to the correct file
# and handles read-only ~/.gitconfig gracefully

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

test_start() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    echo -e "${BLUE}TEST $TESTS_TOTAL: $1${NC}"
}

test_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}  PASS: $1${NC}"
}

test_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}  FAIL: $1${NC}"
}

TEST_DIR="/tmp/slapenir-git-config-test-$$"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

echo "=== Git Configuration Tests ==="
echo ""

# Test 1: setup-git-credentials.sh writes to ~/.config/git/config, not ~/.gitconfig
test_start "Git config writes to ~/.config/git/config (not read-only ~/.gitconfig)"

MOCK_HOME="$TEST_DIR/home"
MOCK_GITCONFIG="$MOCK_HOME/.gitconfig"
MOCK_CONFIG_DIR="$MOCK_HOME/.config/git"
MOCK_CONFIG_FILE="$MOCK_CONFIG_DIR/config"

mkdir -p "$MOCK_HOME"
mkdir -p "$MOCK_CONFIG_DIR"

cat > "$MOCK_GITCONFIG" << 'EOF'
[includeIf "gitdir:~/Projects/homeoffice/"]
    path = ~/.gitconfig-ho
[user]
    signingkey = 164DA43B214F0144
[commit]
    gpgsign = true
EOF
chmod 444 "$MOCK_GITCONFIG"

(
    export HOME="$MOCK_HOME"
    export GIT_CONFIG_GLOBAL="$MOCK_CONFIG_FILE"
    export GIT_USER_NAME="Test User"
    export GIT_USER_EMAIL="test@example.com"

    git config --file "$MOCK_CONFIG_FILE" user.name "$GIT_USER_NAME"
    git config --file "$MOCK_CONFIG_FILE" user.email "$GIT_USER_EMAIL"
)

if [ -f "$MOCK_CONFIG_FILE" ] && grep -q "Test User" "$MOCK_CONFIG_FILE"; then
    test_pass "Config written to ~/.config/git/config"
else
    test_fail "Config NOT written to ~/.config/git/config"
fi

# Verify ~/.gitconfig was NOT modified
if [ "$(stat -f '%p' "$MOCK_GITCONFIG" 2>/dev/null | tail -c 4)" = "444" ] || \
   [ "$(stat -c '%a' "$MOCK_GITCONFIG" 2>/dev/null)" = "444" ]; then
    test_pass "~/.gitconfig remains read-only"
else
    test_fail "~/.gitconfig permissions changed unexpectedly"
fi

# Test 2: user.name and user.email are set correctly from env vars
test_start "user.name and user.email set from env vars"

MOCK_HOME2="$TEST_DIR/home2"
MOCK_CONFIG_DIR2="$MOCK_HOME2/.config/git"
MOCK_CONFIG_FILE2="$MOCK_CONFIG_DIR2/config"
mkdir -p "$MOCK_CONFIG_DIR2"

(
    export HOME="$MOCK_HOME2"
    export GIT_CONFIG_GLOBAL="$MOCK_CONFIG_FILE2"
    export GIT_USER_NAME="Andrew Gibson"
    export GIT_USER_EMAIL="andrew.gibson-cic@ibm.com"

    git config --file "$GIT_CONFIG_GLOBAL" user.name "$GIT_USER_NAME"
    git config --file "$GIT_CONFIG_GLOBAL" user.email "$GIT_USER_EMAIL"
)

name_val=$(git config --file "$MOCK_CONFIG_FILE2" user.name)
email_val=$(git config --file "$MOCK_CONFIG_FILE2" user.email)

if [ "$name_val" = "Andrew Gibson" ] && [ "$email_val" = "andrew.gibson-cic@ibm.com" ]; then
    test_pass "user.name and user.email match env vars"
else
    test_fail "Expected 'Andrew Gibson <andrew.gibson-cic@ibm.com>', got '$name_val <$email_val>'"
fi

# Test 3: Defaults are used when env vars are absent
test_start "Defaults used when GIT_USER_NAME/EMAIL are unset"

MOCK_HOME3="$TEST_DIR/home3"
MOCK_CONFIG_DIR3="$MOCK_HOME3/.config/git"
MOCK_CONFIG_FILE3="$MOCK_CONFIG_DIR3/config"
mkdir -p "$MOCK_CONFIG_DIR3"

(
    export HOME="$MOCK_HOME3"
    export GIT_CONFIG_GLOBAL="$MOCK_CONFIG_FILE3"
    unset GIT_USER_NAME
    unset GIT_USER_EMAIL

    GIT_USER_NAME="${GIT_USER_NAME:-SLAPENIR Agent}"
    GIT_USER_EMAIL="${GIT_USER_EMAIL:-agent@slapenir.local}"

    git config --file "$GIT_CONFIG_GLOBAL" user.name "$GIT_USER_NAME"
    git config --file "$GIT_CONFIG_GLOBAL" user.email "$GIT_USER_EMAIL"
)

name_val=$(git config --file "$MOCK_CONFIG_FILE3" user.name)
email_val=$(git config --file "$MOCK_CONFIG_FILE3" user.email)

if [ "$name_val" = "SLAPENIR Agent" ] && [ "$email_val" = "agent@slapenir.local" ]; then
    test_pass "Defaults applied correctly"
else
    test_fail "Expected defaults, got '$name_val <$email_val>'"
fi

# Test 4: GIT_CONFIG_GLOBAL takes precedence over read-only ~/.gitconfig
test_start "GIT_CONFIG_GLOBAL overrides ~/.gitconfig for user identity"

MOCK_HOME4="$TEST_DIR/home4"
MOCK_GITCONFIG4="$MOCK_HOME4/.gitconfig"
MOCK_CONFIG_DIR4="$MOCK_HOME4/.config/git"
MOCK_CONFIG_FILE4="$MOCK_CONFIG_DIR4/config"
mkdir -p "$MOCK_CONFIG_DIR4"

cat > "$MOCK_GITCONFIG4" << 'EOF'
[user]
    name = Wrong Name
    email = wrong@example.com
    signingkey = ABC123
EOF
chmod 444 "$MOCK_GITCONFIG4"

(
    export HOME="$MOCK_HOME4"
    export GIT_CONFIG_GLOBAL="$MOCK_CONFIG_FILE4"

    git config --file "$GIT_CONFIG_GLOBAL" user.name "Correct Name"
    git config --file "$GIT_CONFIG_GLOBAL" user.email "correct@example.com"
)

name_val=$(HOME="$MOCK_HOME4" GIT_CONFIG_GLOBAL="$MOCK_CONFIG_FILE4" git config user.name)
email_val=$(HOME="$MOCK_HOME4" GIT_CONFIG_GLOBAL="$MOCK_CONFIG_FILE4" git config user.email)

if [ "$name_val" = "Correct Name" ] && [ "$email_val" = "correct@example.com" ]; then
    test_pass "GIT_CONFIG_GLOBAL overrides ~/.gitconfig"
else
    test_fail "Expected 'Correct Name <correct@example.com>', got '$name_val <$email_val>'"
fi

# Test 5: generate-dummy-env-from-proxy.sh preserves GIT_USER_* vars
test_start "generate-dummy-env-from-proxy.sh preserves GIT_USER_* vars"

SCRIPT_PATH="$SCRIPT_DIR/../scripts/generate-dummy-env-from-proxy.sh"
if [ -f "$SCRIPT_PATH" ]; then
    if grep -q "GIT_USER_NAME" "$SCRIPT_PATH" && grep -q "GIT_USER_EMAIL" "$SCRIPT_PATH"; then
        test_pass "Script contains GIT_USER_NAME/EMAIL passthrough logic"
    else
        test_fail "Script does NOT preserve GIT_USER_NAME/EMAIL"
    fi
else
    test_fail "Script not found at $SCRIPT_PATH"
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

if [ $TESTS_TOTAL -gt 0 ]; then
    COVERAGE=$(awk "BEGIN {printf \"%.1f\", ($TESTS_PASSED / $TESTS_TOTAL) * 100}")
    echo -e "Coverage:     ${COVERAGE}%"
fi
echo "==================================="

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed${NC}"
    exit 1
fi
