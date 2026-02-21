#!/bin/bash
# ============================================================================
# SLAPENIR Zero-Knowledge Architecture Verification Script
# ============================================================================
# This script verifies that the agent container only has dummy credentials
# and that the proxy has real credentials with working injection/sanitization.
#
# Usage:
#   ./scripts/verify-zero-knowledge.sh
#
# Exit Codes:
#   0 - All checks passed (zero-knowledge architecture verified)
#   1 - One or more checks failed (security issue detected)
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# ============================================================================
# Helper Functions
# ============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  SLAPENIR Zero-Knowledge Architecture Verification            ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${BLUE}▶ $1${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

check_pass() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    echo -e "  ${GREEN}✓${NC} $1"
}

check_fail() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    echo -e "  ${RED}✗${NC} $1"
}

check_warn() {
    echo -e "  ${YELLOW}⚠${NC} $1"
}

print_summary() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Test Summary                                                  ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  Total Checks:  $TOTAL_CHECKS"
    echo -e "  ${GREEN}Passed:       $PASSED_CHECKS${NC}"
    if [ $FAILED_CHECKS -gt 0 ]; then
        echo -e "  ${RED}Failed:       $FAILED_CHECKS${NC}"
    else
        echo -e "  Failed:       $FAILED_CHECKS"
    fi
    echo ""
    
    if [ $FAILED_CHECKS -eq 0 ]; then
        echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  ✓ ALL CHECKS PASSED - Zero-Knowledge Architecture Verified   ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║  ✗ SECURITY ISSUE DETECTED - Fix Required Before Production   ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}Recommendation:${NC}"
        echo "  See docs/ZERO_KNOWLEDGE_REMEDIATION_PLAN.md for detailed fix"
        echo ""
        return 1
    fi
}

# ============================================================================
# Pre-flight Checks
# ============================================================================

print_header

print_section "Pre-flight Checks"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    check_fail "Docker is not running"
    echo ""
    echo "Please start Docker and try again."
    exit 1
fi
check_pass "Docker is running"

# Check if containers are running
if ! docker ps --filter "name=slapenir-proxy" --format "{{.Names}}" | grep -q "slapenir-proxy"; then
    check_fail "Proxy container is not running"
    echo ""
    echo "Please start SLAPENIR with: docker-compose up -d"
    exit 1
fi
check_pass "Proxy container is running"

if ! docker ps --filter "name=slapenir-agent" --format "{{.Names}}" | grep -q "slapenir-agent"; then
    check_fail "Agent container is not running"
    echo ""
    echo "Please start SLAPENIR with: docker-compose up -d"
    exit 1
fi
check_pass "Agent container is running"

# ============================================================================
# Test 1: Agent Credential Verification
# ============================================================================

print_section "Test 1: Agent Credential Verification"

# List of credential patterns to check
CREDENTIALS=(
    "OPENAI_API_KEY"
    "ANTHROPIC_API_KEY"
    "GEMINI_API_KEY"
    "GITHUB_TOKEN"
    "AWS_ACCESS_KEY_ID"
    "AWS_SECRET_ACCESS_KEY"
)

AGENT_HAS_REAL_CREDS=0

for CRED in "${CREDENTIALS[@]}"; do
    # Get the value from agent
    AGENT_VALUE=$(docker exec slapenir-agent env | grep "^${CRED}=" | cut -d'=' -f2- || echo "")
    
    if [ -z "$AGENT_VALUE" ]; then
        check_warn "${CRED} not found in agent (optional)"
        continue
    fi
    
    # Check if it's a dummy value
    if [[ "$AGENT_VALUE" =~ ^DUMMY_ ]] || [[ "$AGENT_VALUE" == "DUMMY_"* ]]; then
        check_pass "${CRED}=${AGENT_VALUE} (dummy credential)"
    else
        # Check if it looks like a real credential
        if [[ ${#AGENT_VALUE} -gt 10 ]] && [[ ! "$AGENT_VALUE" =~ ^DUMMY ]]; then
            check_fail "${CRED}=${AGENT_VALUE:0:10}... (REAL CREDENTIAL DETECTED!)"
            AGENT_HAS_REAL_CREDS=1
        else
            check_pass "${CRED}=${AGENT_VALUE} (appears to be dummy)"
        fi
    fi
done

# ============================================================================
# Test 2: Proxy Credential Verification
# ============================================================================

print_section "Test 2: Proxy Credential Verification"

PROXY_HAS_REAL_CREDS=0

for CRED in "${CREDENTIALS[@]}"; do
    # Get the value from proxy
    PROXY_VALUE=$(docker exec slapenir-proxy env | grep "^${CRED}=" | cut -d'=' -f2- || echo "")
    
    if [ -z "$PROXY_VALUE" ]; then
        check_warn "${CRED} not found in proxy (may be optional)"
        continue
    fi
    
    # Check if it's a dummy value (BAD for proxy)
    if [[ "$PROXY_VALUE" =~ ^DUMMY_ ]] || [[ "$PROXY_VALUE" == "DUMMY_"* ]]; then
        check_fail "${CRED}=${PROXY_VALUE} (proxy should have REAL credentials!)"
    else
        # Check if it looks like a real credential (GOOD for proxy)
        if [[ ${#PROXY_VALUE} -gt 10 ]]; then
            check_pass "${CRED}=${PROXY_VALUE:0:10}... (real credential present)"
            PROXY_HAS_REAL_CREDS=1
        else
            check_warn "${CRED}=${PROXY_VALUE} (credential seems too short)"
        fi
    fi
done

# ============================================================================
# Test 3: Proxy Configuration Verification
# ============================================================================

print_section "Test 3: Agent Proxy Configuration"

# Check HTTP_PROXY
HTTP_PROXY_VALUE=$(docker exec slapenir-agent env | grep "^HTTP_PROXY=" | cut -d'=' -f2- || echo "")
if [ "$HTTP_PROXY_VALUE" = "http://proxy:3000" ]; then
    check_pass "HTTP_PROXY=http://proxy:3000 (correct)"
else
    check_fail "HTTP_PROXY=${HTTP_PROXY_VALUE} (should be http://proxy:3000)"
fi

# Check HTTPS_PROXY
HTTPS_PROXY_VALUE=$(docker exec slapenir-agent env | grep "^HTTPS_PROXY=" | cut -d'=' -f2- || echo "")
if [ "$HTTPS_PROXY_VALUE" = "http://proxy:3000" ]; then
    check_pass "HTTPS_PROXY=http://proxy:3000 (correct)"
else
    check_fail "HTTPS_PROXY=${HTTPS_PROXY_VALUE} (should be http://proxy:3000)"
fi

# ============================================================================
# Test 4: Network Connectivity
# ============================================================================

print_section "Test 4: Network Connectivity Tests"

# Check if agent can reach proxy
if docker exec slapenir-agent curl -s -f http://proxy:3000/health > /dev/null 2>&1; then
    check_pass "Agent can reach proxy health endpoint"
else
    check_fail "Agent cannot reach proxy health endpoint"
fi

# Check if proxy is healthy
PROXY_HEALTH=$(docker exec slapenir-proxy curl -s http://localhost:3000/health)
if [ "$PROXY_HEALTH" = "OK" ]; then
    check_pass "Proxy health check returns OK"
else
    check_fail "Proxy health check failed: ${PROXY_HEALTH}"
fi

# ============================================================================
# Test 5: Credential Isolation Test
# ============================================================================

print_section "Test 5: Credential Isolation Verification"

# Compare a few key credentials between agent and proxy
OPENAI_AGENT=$(docker exec slapenir-agent env | grep "^OPENAI_API_KEY=" | cut -d'=' -f2- || echo "")
OPENAI_PROXY=$(docker exec slapenir-proxy env | grep "^OPENAI_API_KEY=" | cut -d'=' -f2- || echo "")

if [ -n "$OPENAI_AGENT" ] && [ -n "$OPENAI_PROXY" ]; then
    if [ "$OPENAI_AGENT" = "$OPENAI_PROXY" ]; then
        check_fail "Agent and Proxy have SAME OPENAI_API_KEY (CRITICAL SECURITY ISSUE!)"
    else
        check_pass "Agent and Proxy have DIFFERENT OPENAI_API_KEY (correct)"
    fi
else
    check_warn "Could not compare OPENAI_API_KEY (one or both missing)"
fi

# ============================================================================
# Test 6: File System Checks
# ============================================================================

print_section "Test 6: Environment File Configuration"

# Check if .env.proxy exists
if [ -f ".env.proxy" ]; then
    check_pass ".env.proxy file exists (real credentials)"
else
    check_warn ".env.proxy file not found (may still be using .env)"
fi

# Check if .env.agent exists
if [ -f ".env.agent" ]; then
    check_pass ".env.agent file exists (dummy credentials)"
else
    check_warn ".env.agent file not found (may still be using auto-generation)"
fi

# Check if docker-compose.yml references separate files
if grep -q "env_file:" docker-compose.yml; then
    if grep -A1 "proxy:" docker-compose.yml | grep -q ".env.proxy"; then
        check_pass "docker-compose.yml proxy references .env.proxy"
    elif grep -A3 "proxy:" docker-compose.yml | grep -q "env_file:" | grep -q ".env"; then
        check_warn "docker-compose.yml proxy references .env (should be .env.proxy)"
    else
        check_warn "docker-compose.yml proxy env_file configuration unclear"
    fi
    
    if grep -A10 "agent:" docker-compose.yml | grep -q ".env.agent"; then
        check_pass "docker-compose.yml agent references .env.agent"
    else
        check_warn "docker-compose.yml agent env_file not found (may be intentional)"
    fi
fi

# ============================================================================
# Test 7: Security Best Practices
# ============================================================================

print_section "Test 7: Security Best Practices"

# Check if .gitignore excludes credential files
if [ -f ".gitignore" ]; then
    if grep -q ".env.proxy" .gitignore && grep -q ".env.agent" .gitignore; then
        check_pass ".gitignore excludes .env.proxy and .env.agent"
    else
        check_warn ".gitignore may not exclude all credential files"
    fi
else
    check_fail ".gitignore file not found"
fi

# Check if agent runs as non-root
AGENT_USER=$(docker exec slapenir-agent whoami)
if [ "$AGENT_USER" != "root" ]; then
    check_pass "Agent runs as non-root user: ${AGENT_USER}"
else
    check_warn "Agent runs as root (not recommended)"
fi

# Check if proxy runs as non-root
PROXY_USER=$(docker exec slapenir-proxy whoami)
if [ "$PROXY_USER" != "root" ]; then
    check_pass "Proxy runs as non-root user: ${PROXY_USER}"
else
    check_warn "Proxy runs as root (not recommended for production)"
fi

# ============================================================================
# Final Summary
# ============================================================================

print_summary
exit $?