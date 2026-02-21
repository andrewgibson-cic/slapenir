#!/bin/bash
# ============================================================================
# SLAPENIR Agent Startup Validation
# ============================================================================
# Automatically validates security, environment, and connectivity on startup
# Runs after dummy credentials are generated
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNED=0

# ============================================================================
# Helper Functions
# ============================================================================

test_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓${NC} $1"
}

test_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗${NC} $1"
}

test_warn() {
    TESTS_WARNED=$((TESTS_WARNED + 1))
    echo -e "${YELLOW}⚠${NC} $1"
}

print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ============================================================================
# Test 1: Security - Verify No Real Credentials
# ============================================================================

test_security() {
    print_header "🔒 Security Validation"
    
    # Check for common real credential patterns
    local has_real_creds=0
    
    # Check environment for real credential patterns
    if env | grep -E "^[A-Z_]*KEY.*=sk-proj-" > /dev/null 2>&1; then
        test_fail "Real OpenAI credential detected in environment"
        has_real_creds=1
    fi
    
    if env | grep -E "^[A-Z_]*KEY.*=sk-ant-" > /dev/null 2>&1; then
        test_fail "Real Anthropic credential detected in environment"
        has_real_creds=1
    fi
    
    if env | grep -E "^[A-Z_]*KEY.*=AIza" > /dev/null 2>&1; then
        test_fail "Real Gemini credential detected in environment"
        has_real_creds=1
    fi
    
    if env | grep -E "^[A-Z_]*TOKEN.*=ghp_" > /dev/null 2>&1; then
        test_fail "Real GitHub credential detected in environment"
        has_real_creds=1
    fi
    
    if env | grep -E "^[A-Z_]*TOKEN.*=github_pat_" > /dev/null 2>&1; then
        test_fail "Real GitHub PAT detected in environment"
        has_real_creds=1
    fi
    
    if [ $has_real_creds -eq 0 ]; then
        test_pass "No real credentials detected in environment"
    fi
    
    # Check for DUMMY credentials
    local has_dummy=0
    if env | grep -E "DUMMY_" > /dev/null 2>&1; then
        test_pass "Dummy credentials present (expected)"
        has_dummy=1
    else
        test_warn "No DUMMY credentials found (may be intended)"
    fi
    
    # Verify .env file exists and has proper permissions
    if [ -f "/home/agent/.env" ]; then
        test_pass "Agent .env file exists"
        
        local perms=$(stat -c %a /home/agent/.env 2>/dev/null || stat -f %A /home/agent/.env 2>/dev/null)
        if [ "$perms" = "600" ]; then
            test_pass "Agent .env has secure permissions (600)"
        else
            test_warn "Agent .env permissions: $perms (should be 600)"
        fi
    else
        test_fail "Agent .env file not found"
    fi
}

# ============================================================================
# Test 2: Environment - Verify Proxy Configuration
# ============================================================================

test_environment() {
    print_header "🌐 Environment Validation"
    
    # Check HTTP_PROXY
    if [ "$HTTP_PROXY" = "http://proxy:3000" ]; then
        test_pass "HTTP_PROXY configured correctly"
    elif [ -z "$HTTP_PROXY" ]; then
        test_warn "HTTP_PROXY not set (direct connections will be used)"
    else
        test_fail "HTTP_PROXY misconfigured: $HTTP_PROXY"
    fi
    
    # Check HTTPS_PROXY
    if [ "$HTTPS_PROXY" = "http://proxy:3000" ]; then
        test_pass "HTTPS_PROXY configured correctly"
    elif [ -z "$HTTPS_PROXY" ]; then
        test_warn "HTTPS_PROXY not set (direct connections will be used)"
    else
        test_fail "HTTPS_PROXY misconfigured: $HTTPS_PROXY"
    fi
    
    # Check Python environment
    if command -v python3 > /dev/null 2>&1; then
        local py_version=$(python3 --version 2>&1 | cut -d' ' -f2)
        test_pass "Python available: $py_version"
    else
        test_fail "Python not found"
    fi
    
    # Check Git
    if command -v git > /dev/null 2>&1; then
        local git_version=$(git --version 2>&1 | cut -d' ' -f3)
        test_pass "Git available: $git_version"
    else
        test_warn "Git not found"
    fi
    
    # Check curl
    if command -v curl > /dev/null 2>&1; then
        test_pass "curl available"
    else
        test_warn "curl not found"
    fi
}

# ============================================================================
# Test 3: Connectivity - Verify Proxy Access
# ============================================================================

test_connectivity() {
    print_header "🔗 Connectivity Validation"
    
    # Wait a moment for proxy to be ready
    sleep 2
    
    # Check if proxy is reachable
    if curl -s -f --max-time 5 http://proxy:3000/health > /dev/null 2>&1; then
        test_pass "Proxy health endpoint reachable"
    else
        test_fail "Cannot reach proxy health endpoint"
    fi
    
    # Check if we can resolve proxy hostname
    # Try multiple methods since Wolfi may not have all tools
    if nslookup proxy > /dev/null 2>&1; then
        test_pass "Proxy hostname resolves (nslookup)"
    elif host proxy > /dev/null 2>&1; then
        test_pass "Proxy hostname resolves (host)"
    elif getent hosts proxy > /dev/null 2>&1; then
        test_pass "Proxy hostname resolves (getent)"
    elif ping -c 1 -W 1 proxy > /dev/null 2>&1; then
        test_pass "Proxy hostname resolves (ping)"
    elif curl -s --max-time 2 http://proxy:3000/health > /dev/null 2>&1; then
        test_pass "Proxy hostname resolves (curl verified)"
    else
        test_warn "Cannot resolve proxy hostname (but health check passed)"
    fi
    
    # Check network isolation (should NOT be able to reach internet directly)
    # Note: In development mode, network may not be isolated (internal: false)
    if curl -s --max-time 3 https://www.google.com > /dev/null 2>&1; then
        test_warn "Direct internet access possible (NETWORK_INTERNAL may be false)"
    else
        test_pass "Direct internet access blocked (network isolated)"
    fi
}

# ============================================================================
# Test 4: Credentials - Verify Dummy Values
# ============================================================================

test_credentials() {
    print_header "🔑 Credential Validation"
    
    # Check common credential environment variables
    local creds_to_check=(
        "OPENAI_API_KEY:DUMMY_OPENAI"
        "ANTHROPIC_API_KEY:DUMMY_ANTHROPIC"
        "GEMINI_API_KEY:DUMMY_GEMINI"
        "GITHUB_TOKEN:DUMMY_GITHUB"
        "AWS_ACCESS_KEY_ID:DUMMY_AWS_ACCESS"
    )
    
    for cred_pair in "${creds_to_check[@]}"; do
        local key="${cred_pair%%:*}"
        local expected="${cred_pair##*:}"
        local value=$(env | grep "^${key}=" | cut -d'=' -f2-)
        
        if [ -z "$value" ]; then
            test_warn "$key not set"
        elif [ "$value" = "$expected" ]; then
            test_pass "$key = $expected (dummy value)"
        elif [[ "$value" == DUMMY_* ]]; then
            test_pass "$key = $value (dummy value)"
        else
            test_fail "$key has unexpected value (may be real credential!)"
        fi
    done
}

# ============================================================================
# Main Execution
# ============================================================================

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  SLAPENIR Agent Startup Validation                          ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"

# Run all tests
test_security
test_environment
test_connectivity
test_credentials

# Print summary
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${GREEN}Passed:${NC}  $TESTS_PASSED"
echo -e "  ${YELLOW}Warnings:${NC} $TESTS_WARNED"
echo -e "  ${RED}Failed:${NC}  $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✓ All Critical Tests Passed - Agent Ready                  ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    exit 0
else
    echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ✗ Critical Tests Failed - Review Configuration             ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
    exit 1
fi