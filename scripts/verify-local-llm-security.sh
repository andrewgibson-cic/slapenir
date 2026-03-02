#!/bin/bash
# SLAPENIR Local LLM Security Verification Script
# Tests network isolation and verifies that code cannot leak to the internet
# when using a local llama-server with OpenCode

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results
PASSED=0
FAILED=0
WARNINGS=0

echo "════════════════════════════════════════════════════════════════"
echo "  SLAPENIR Local LLM Security Verification"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Helper functions
pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++))
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
}

info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

section() {
    echo ""
    echo "──────────────────────────────────────────────────────────────"
    echo "  $1"
    echo "──────────────────────────────────────────────────────────────"
}

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    fail "Docker is not running"
    echo ""
    echo "Please start Docker and try again."
    exit 1
fi

# Check if agent container is running
if ! docker ps --format '{{.Names}}' | grep -q "slapenir-agent"; then
    fail "Agent container is not running"
    echo ""
    echo "Please start the agent container:"
    echo "  docker-compose up -d agent"
    exit 1
fi

pass "Docker is running and agent container is active"

# ============================================================================
# Test 1: Check if llama-server is running on host
# ============================================================================

section "Test 1: Host llama-server Status"

LLAMA_PORT="${LLAMA_SERVER_PORT:-8080}"

if curl -s -f "http://localhost:$LLAMA_PORT/health" > /dev/null 2>&1 || \
   curl -s -f "http://localhost:$LLAMA_PORT/v1/models" > /dev/null 2>&1; then
    pass "llama-server is running on localhost:$LLAMA_PORT"
    
    # Check binding
    if lsof -i :$LLAMA_PORT | grep -q "0.0.0.0:$LLAMA_PORT"; then
        pass "llama-server is bound to 0.0.0.0 (Docker-accessible)"
    elif lsof -i :$LLAMA_PORT | grep -q "127.0.0.1:$LLAMA_PORT"; then
        fail "llama-server is bound to 127.0.0.1 (not Docker-accessible)"
        echo "     Please restart llama-server with --host 0.0.0.0"
        echo "     Run: ./scripts/setup-llama-server.sh"
    else
        warn "Could not determine llama-server binding address"
    fi
else
    fail "llama-server is not running or not accessible on port $LLAMA_PORT"
    echo "     Start with: ./scripts/setup-llama-server.sh"
    echo "     Or manually with: llama-server --host 0.0.0.0 --port $LLAMA_PORT ..."
fi

# ============================================================================
# Test 2: Check agent container network configuration
# ============================================================================

section "Test 2: Agent Container Network Configuration"

# Check if extra_hosts is configured
if docker inspect slapenir-agent | grep -q "host.docker.internal"; then
    pass "extra_hosts configured (host.docker.internal mapped)"
else
    fail "extra_hosts NOT configured in agent container"
    echo "     This should have been fixed in docker-compose.yml"
    echo "     Run: docker-compose up -d --force-recreate agent"
fi

# Check if traffic enforcement is enabled
if docker exec slapenir-agent bash -c 'echo $TRAFFIC_ENFORCEMENT_ENABLED' | grep -q "true"; then
    pass "Traffic enforcement is enabled"
else
    warn "Traffic enforcement is NOT enabled (insecure)"
    echo "     Set TRAFFIC_ENFORCEMENT_ENABLED=true in docker-compose.yml"
fi

# Check if HTTP_PROXY is set
if docker exec slapenir-agent bash -c 'echo $HTTP_PROXY' | grep -q "proxy:3000"; then
    pass "HTTP_PROXY configured (proxy:3000)"
else
    warn "HTTP_PROXY not configured correctly"
fi

# Check if NO_PROXY includes host.docker.internal
if docker exec slapenir-agent bash -c 'echo $NO_PROXY' | grep -q "host.docker.internal"; then
    pass "NO_PROXY includes host.docker.internal"
else
    warn "NO_PROXY does not include host.docker.internal"
fi

# ============================================================================
# Test 3: Test connectivity from agent to llama-server
# ============================================================================

section "Test 3: Agent → Llama-server Connectivity"

# Test if agent can reach llama-server
if docker exec slapenir-agent curl -s -f --max-time 5 "http://host.docker.internal:$LLAMA_PORT/health" > /dev/null 2>&1 || \
   docker exec slapenir-agent curl -s -f --max-time 5 "http://host.docker.internal:$LLAMA_PORT/v1/models" > /dev/null 2>&1; then
    pass "Agent can reach llama-server at host.docker.internal:$LLAMA_PORT"
    
    # Try to get models list
    MODELS=$(docker exec slapenir-agent curl -s --max-time 5 "http://host.docker.internal:$LLAMA_PORT/v1/models" 2>/dev/null || echo "")
    if echo "$MODELS" | grep -q "model"; then
        pass "llama-server is responding with model information"
    else
        warn "llama-server responded but no models found"
    fi
else
    fail "Agent CANNOT reach llama-server"
    echo "     Check:"
    echo "     1. llama-server is running with --host 0.0.0.0"
    echo "     2. extra_hosts is configured in docker-compose.yml"
    echo "     3. Restart agent: docker-compose restart agent"
fi

# ============================================================================
# Test 4: Test network isolation (external access should be blocked)
# ============================================================================

section "Test 4: Network Isolation (External Access Should Be Blocked)"

# Test 4a: Try to reach external API directly (should fail)
info "Testing direct external access (should be blocked)..."
if docker exec slapenir-agent timeout 5 curl -s -f --max-time 5 "https://api.openai.com/v1/models" > /dev/null 2>&1; then
    fail "SECURITY ISSUE: Agent can reach external APIs directly!"
    echo "     This is a critical security vulnerability."
    echo "     Traffic enforcement may not be working correctly."
else
    pass "External API access is blocked (as expected)"
fi

# Test 4b: Try to reach random external website (should fail)
info "Testing random external website access (should be blocked)..."
if docker exec slapenir-agent timeout 5 curl -s -f --max-time 5 "https://www.google.com" > /dev/null 2>&1; then
    fail "SECURITY ISSUE: Agent can reach external websites!"
    echo "     This is a critical security vulnerability."
else
    pass "External website access is blocked (as expected)"
fi

# Test 4c: Try to reach external IP directly (should fail)
info "Testing direct IP access (should be blocked)..."
if docker exec slapenir-agent timeout 5 curl -s -f --max-time 5 "http://1.1.1.1" > /dev/null 2>&1; then
    fail "SECURITY ISSUE: Agent can reach external IPs directly!"
else
    pass "Direct external IP access is blocked (as expected)"
fi

# ============================================================================
# Test 5: Verify traffic enforcement rules
# ============================================================================

section "Test 5: Traffic Enforcement Rules (iptables)"

# Check if iptables rules exist
if docker exec slapenir-agent iptables -L TRAFFIC_ENFORCE > /dev/null 2>&1; then
    pass "TRAFFIC_ENFORCE iptables chain exists"
    
    # Check specific rules
    RULES=$(docker exec slapenir-agent iptables -L TRAFFIC_ENFORCE -v -n 2>/dev/null || echo "")
    
    # Check if proxy is allowed
    if echo "$RULES" | grep -q "proxy\|172.30.0"; then
        pass "Proxy access is allowed in iptables"
    else
        warn "Could not verify proxy access rule"
    fi
    
    # Check if DROP rule exists
    if echo "$RULES" | grep -q "DROP\|REJECT"; then
        pass "Default DROP/REJECT rule exists (blocks unauthorized traffic)"
    else
        warn "Could not find default DROP rule"
    fi
    
    # Check if LOG rule exists for bypass attempts
    if echo "$RULES" | grep -q "LOG"; then
        pass "Bypass attempts are logged"
    else
        warn "Bypass attempt logging not found"
    fi
else
    fail "TRAFFIC_ENFORCE iptables chain NOT found"
    echo "     Traffic enforcement may not be active"
    echo "     Check agent startup logs: docker logs slapenir-agent"
fi

# ============================================================================
# Test 6: Verify proxy bypass for local services
# ============================================================================

section "Test 6: Proxy Bypass Configuration"

# Check proxy logs to verify bypass logic
info "Checking if proxy has bypass logic for host.docker.internal..."

# This is a static check - we've already verified the code has the bypass logic
if grep -q "should_bypass_proxy" "$PROJECT_ROOT/proxy/src/proxy.rs" 2>/dev/null && \
   grep -q "host.docker.internal" "$PROJECT_ROOT/proxy/src/proxy.rs" 2>/dev/null; then
    pass "Proxy has bypass logic for host.docker.internal"
else
    warn "Could not verify proxy bypass logic in source code"
fi

# Check bypass rules in proxy config
if [ -f "$PROJECT_ROOT/proxy/config.yaml" ]; then
    if grep -q "host.docker.internal\|localhost\|127.0.0.1" "$PROJECT_ROOT/proxy/config.yaml"; then
        pass "Proxy config includes local service bypass rules"
    fi
fi

# ============================================================================
# Test 7: Verify OpenCode configuration
# ============================================================================

section "Test 7: OpenCode Configuration"

OPENCODE_CONFIG="$PROJECT_ROOT/agent/config/opencode.json"

if [ -f "$OPENCODE_CONFIG" ]; then
    pass "OpenCode config file exists"
    
    # Check if local-llama provider is configured
    if grep -q "host.docker.internal:$LLAMA_PORT" "$OPENCODE_CONFIG"; then
        pass "OpenCode configured to use host.docker.internal:$LLAMA_PORT"
    else
        warn "OpenCode may not be configured for local llama-server"
        echo "     Expected: http://host.docker.internal:$LLAMA_PORT/v1"
    fi
    
    # Check if baseURL is correct
    if grep -q "baseURL.*host.docker.internal" "$OPENCODE_CONFIG"; then
        pass "baseURL points to host.docker.internal (correct)"
    fi
else
    warn "OpenCode config not found at $OPENCODE_CONFIG"
fi

# ============================================================================
# Test 8: Docker network isolation
# ============================================================================

section "Test 8: Docker Network Isolation"

# Check if network is internal
NETWORK_INTERNAL=$(docker network inspect slape-net --format '{{.Internal}}' 2>/dev/null || echo "unknown")

if [ "$NETWORK_INTERNAL" = "true" ]; then
    pass "Docker network is internal (external routing blocked)"
elif [ "$NETWORK_INTERNAL" = "false" ]; then
    warn "Docker network is NOT internal (development mode)"
    echo "     For production, set NETWORK_INTERNAL=true"
else
    warn "Could not determine Docker network internal status"
fi

# Check network subnet
NETWORK_SUBNET=$(docker network inspect slape-net --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null || echo "unknown")
if [ "$NETWORK_SUBNET" = "172.30.0.0/24" ]; then
    pass "Docker network uses expected subnet (172.30.0.0/24)"
else
    info "Docker network subnet: $NETWORK_SUBNET"
fi

# ============================================================================
# Summary
# ============================================================================

section "Test Summary"

echo ""
echo "Results:"
echo "  ${GREEN}Passed:${NC}   $PASSED"
echo "  ${YELLOW}Warnings:${NC} $WARNINGS"
echo "  ${RED}Failed:${NC}   $FAILED"
echo ""

if [ $FAILED -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  ✓ ALL TESTS PASSED - Network isolation is SECURE${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Your code CANNOT leak to the internet when using local llama-server."
    echo ""
    echo "Next steps:"
    echo "  1. Restart your llama-server with --host 0.0.0.0"
    echo "  2. Restart the agent container: docker-compose restart agent"
    echo "  3. Test OpenCode with the local model"
    echo ""
    exit 0
elif [ $FAILED -eq 0 ]; then
    echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  ⚠ TESTS PASSED WITH WARNINGS${NC}"
    echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Network isolation is mostly secure, but some warnings were found."
    echo "Review the warnings above and address them if possible."
    echo ""
    exit 0
else
    echo -e "${RED}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}  ✗ TESTS FAILED - Security issues detected${NC}"
    echo -e "${RED}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "CRITICAL: Network isolation may not be working correctly!"
    echo ""
    echo "Required fixes:"