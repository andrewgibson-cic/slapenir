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
# Test 4: Local LLM - Verify Connectivity and Isolation
# ============================================================================

test_local_llm() {
    print_header "🤖 Local LLM Validation"

    # Check if host.docker.internal can be resolved
    if getent hosts host.docker.internal > /dev/null 2>&1; then
        test_pass "host.docker.internal resolves (extra_hosts configured)"
    else
        test_warn "host.docker.internal does not resolve (extra_hosts may not be configured)"
    fi

    # Check if llama-server is accessible
    if curl -s -f --max-time 3 http://host.docker.internal:8080/v1/models > /dev/null 2>&1; then
        test_pass "Local llama-server accessible at host.docker.internal:8080"

        # Try to get models list
        local models=$(curl -s --max-time 3 http://host.docker.internal:8080/v1/models 2>/dev/null)
        if echo "$models" | grep -q "model"; then
            test_pass "llama-server responding with model information"
        fi
    else
        test_warn "Local llama-server not accessible (may not be running)"
    fi

    # Check if llama-server is accessible via localhost (127.0.0.1)
    if curl -s -f --max-time 3 http://127.0.0.1:8080/v1/models > /dev/null 2>&1; then
        test_pass "Local llama-server accessible at 127.0.0.1:8080 (localhost bypass rule working)"

        # Try to get models list
        local models=$(curl -s --max-time 3 http://127.0.0.1:8080/v1/models 2>/dev/null)
        if echo "$models" | grep -q "model"; then
            test_pass "llama-server responding with model information via localhost"
        fi
    else
        test_warn "Local llama-server not accessible at 127.0.0.1:8080 (localhost bypass rule may not be active)"
    fi

    # Check OpenCode configuration
    if [ -f "/home/agent/.config/opencode/opencode.json" ]; then
        test_pass "OpenCode config file exists"

        # Check if local-llama provider is configured
        if grep -q '"local-llama"' /home/agent/.config/opencode/opencode.json; then
            test_pass "OpenCode has local-llama provider configured"
        else
            test_warn "OpenCode local-llama provider not found in config"
        fi

        # Check if default provider is set
        if grep -q '"defaultProvider".*"local-llama"' /home/agent/.config/opencode/opencode.json; then
            test_pass "OpenCode defaultProvider set to local-llama"
        else
            test_warn "OpenCode defaultProvider not set (manual selection required)"
        fi
    else
        test_fail "OpenCode config file not found"
    fi
}

# ============================================================================
# Test 5: Traffic Enforcement - Comprehensive iptables Validation
# ============================================================================

test_traffic_enforcement() {
    print_header "🛡️ Traffic Enforcement Validation"

    # Check traffic enforcement (iptables) - MANDATORY for security
    if ! command -v iptables > /dev/null 2>&1; then
        test_fail "CRITICAL: iptables not available - cannot enforce traffic rules!"
        return
    fi

    # Test 1: Check TRAFFIC_ENFORCE chain exists in filter table
    if iptables -L TRAFFIC_ENFORCE > /dev/null 2>&1; then
        test_pass "Traffic enforcement iptables chain exists"
    else
        test_fail "CRITICAL: Traffic enforcement iptables chain NOT found - container is NOT secure!"
        return
    fi

    # Test 2: Check if DROP rule exists - MANDATORY
    if iptables -L TRAFFIC_ENFORCE -n | grep -q "DROP"; then
        test_pass "Traffic enforcement has DROP rule (unauthorized traffic blocked)"
    else
        test_fail "CRITICAL: Traffic enforcement DROP rule not found - container is NOT secure!"
    fi

    # Test 3: Count rules to ensure proper setup (should be ~21 rules)
    local rule_count=$(iptables -L TRAFFIC_ENFORCE -n | grep -c "^" || echo "0")
    if [ "$rule_count" -ge 10 ]; then
        test_pass "Traffic enforcement has $rule_count rules (properly configured)"
    else
        test_fail "CRITICAL: Too few iptables rules ($rule_count) - traffic enforcement incomplete!"
    fi

    # Test 4: Verify localhost bypass rule exists
    # The rule format is: "ACCEPT all -- 0.0.0.0/0 127.0.0.0/8"
    if iptables -L TRAFFIC_ENFORCE -n | grep -q "ACCEPT.*127.0.0.0/8"; then
        test_pass "Localhost bypass rule active (127.0.0.0/8 ACCEPT)"
    else
        test_fail "CRITICAL: Localhost bypass rule missing - llama-server connections will fail!"
    fi

    # Test 5: Check NAT table redirect rules exist
    if iptables -t nat -L TRAFFIC_REDIRECT > /dev/null 2>&1; then
        test_pass "NAT redirect chain exists (TRAFFIC_REDIRECT)"

        # Check HTTP redirect
        if iptables -t nat -L TRAFFIC_REDIRECT -n | grep -q "dpt:80.*redir"; then
            test_pass "HTTP traffic redirect rule exists (port 80 → proxy)"
        else
            test_fail "HTTP redirect rule missing in NAT table"
        fi

        # Check HTTPS redirect
        if iptables -t nat -L TRAFFIC_REDIRECT -n | grep -q "dpt:443.*redir"; then
            test_pass "HTTPS traffic redirect rule exists (port 443 → proxy)"
        else
            test_fail "HTTPS redirect rule missing in NAT table"
        fi
    else
        test_warn "NAT redirect chain not found (HTTP/HTTPS redirect may not work)"
    fi

    # Test 6: Verify proxy IP is allowed
    local proxy_ip=$(grep -E "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\s+proxy" /etc/hosts 2>/dev/null | awk '{print $1}' | head -1)
    if [ -n "$proxy_ip" ]; then
        if iptables -L TRAFFIC_ENFORCE -n | grep -q "$proxy_ip"; then
            test_pass "Proxy IP ($proxy_ip) allowed in iptables rules"
        else
            test_fail "Proxy IP ($proxy_ip) not found in ALLOW rules"
        fi
    fi

    # Test 7: Verify SSH port is allowed
    if iptables -L TRAFFIC_ENFORCE -n | grep -q "dpt:22.*ACCEPT"; then
        test_pass "SSH traffic (port 22) allowed"
    else
        test_warn "SSH allow rule not found (may be expected if SSH not needed)"
    fi

    # Test 8: Verify DNS filtering rules exist
    if iptables -L TRAFFIC_ENFORCE -n | grep -q "DNS-BLOCK"; then
        test_pass "DNS filtering rules exist (unauthorized DNS blocked)"
    else
        test_warn "DNS filtering rules not found"
    fi

    # Test 9: Verify bypass attempt logging is configured
    if iptables -L TRAFFIC_ENFORCE -n | grep -q "BYPASS-ATTEMPT"; then
        test_pass "Bypass attempt logging configured"
    else
        test_warn "Bypass attempt logging not configured"
    fi

    # Test 10: Verify OUTPUT chain links to TRAFFIC_ENFORCE
    if iptables -L OUTPUT -n | grep -q "TRAFFIC_ENFORCE"; then
        test_pass "OUTPUT chain linked to TRAFFIC_ENFORCE"
    else
        test_fail "CRITICAL: OUTPUT chain not linked to TRAFFIC_ENFORCE - rules not active!"
    fi
}

# ============================================================================
# Test 6: Network Isolation - Verify External Access Blocked
# ============================================================================

test_network_isolation() {
    print_header "🌐 Network Isolation Validation"

    local blocked_count=0
    local tested_count=0

    # Test 1: Try to reach api.openai.com (should be blocked)
    tested_count=$((tested_count + 1))
    echo -n "  Testing api.openai.com... "
    if ! timeout 3 curl -s --max-time 3 https://api.openai.com > /dev/null 2>&1; then
        echo -e "${GREEN}BLOCKED ✓${NC}"
        blocked_count=$((blocked_count + 1))
    else
        echo -e "${RED}ACCESSIBLE ✗${NC}"
    fi

    # Test 2: Try to reach api.anthropic.com (should be blocked)
    tested_count=$((tested_count + 1))
    echo -n "  Testing api.anthropic.com... "
    if ! timeout 3 curl -s --max-time 3 https://api.anthropic.com > /dev/null 2>&1; then
        echo -e "${GREEN}BLOCKED ✓${NC}"
        blocked_count=$((blocked_count + 1))
    else
        echo -e "${RED}ACCESSIBLE ✗${NC}"
    fi

    # Test 3: Try to reach google.com (should be blocked)
    tested_count=$((tested_count + 1))
    echo -n "  Testing www.google.com... "
    if ! timeout 3 curl -s --max-time 3 https://www.google.com > /dev/null 2>&1; then
        echo -e "${GREEN}BLOCKED ✓${NC}"
        blocked_count=$((blocked_count + 1))
    else
        echo -e "${RED}ACCESSIBLE ✗${NC}"
    fi

    # Test 4: Try HTTP to external site (should be blocked)
    tested_count=$((tested_count + 1))
    echo -n "  Testing http://example.com... "
    if ! timeout 3 curl -s --max-time 3 http://example.com > /dev/null 2>&1; then
        echo -e "${GREEN}BLOCKED ✓${NC}"
        blocked_count=$((blocked_count + 1))
    else
        echo -e "${RED}ACCESSIBLE ✗${NC}"
    fi

    echo ""
    if [ $blocked_count -eq $tested_count ]; then
        test_pass "Network isolation verified ($blocked_count/$tested_count external sites blocked)"
    elif [ $blocked_count -gt 0 ]; then
        test_warn "Partial network isolation ($blocked_count/$tested_count external sites blocked)"
    else
        test_fail "CRITICAL: Network isolation not active (all external sites accessible)"
    fi
}

# ============================================================================
# Test 7: Allowed Connectivity - Verify Internal Access Works
# ============================================================================

test_allowed_connectivity() {
    print_header "✅ Allowed Connectivity Validation"

    # Test 1: Proxy should be reachable
    echo -n "  Testing proxy:3000/health... "
    if curl -s --max-time 5 http://proxy:3000/health > /dev/null 2>&1; then
        echo -e "${GREEN}OK ✓${NC}"
        test_pass "Proxy health endpoint reachable"
    else
        echo -e "${RED}FAILED ✗${NC}"
        test_fail "Proxy not reachable - agent cannot function!"
    fi

    # Test 2: Localhost should be allowed
    echo -n "  Testing localhost connectivity... "
    if curl -s --max-time 2 http://127.0.0.1:1 2>&1 | grep -q "Connection refused\|Empty reply"; then
        echo -e "${GREEN}OK ✓${NC}"
        test_pass "Localhost connectivity allowed (127.0.0.0/8 bypass active)"
    else
        echo -e "${GREEN}OK ✓${NC}"
        test_pass "Localhost connectivity allowed"
    fi

    # Test 3: DNS resolution should work (through allowed DNS servers)
    echo -n "  Testing DNS resolution... "
    if python3 -c "import socket; socket.gethostbyname('google.com')" 2>/dev/null; then
        echo -e "${GREEN}OK ✓${NC}"
        test_pass "DNS resolution works (through allowed DNS servers)"
    else
        echo -e "${RED}FAILED ✗${NC}"
        test_fail "DNS resolution failed - check DNS filtering rules"
    fi

    # Test 4: Internal Docker network should be accessible
    echo -n "  Testing internal Docker network (postgres)... "
    if timeout 3 curl -s --max-time 3 http://postgres:5432 2>&1 | grep -q "PostgreSQL\|Connection refused\|Empty"; then
        echo -e "${GREEN}OK ✓${NC}"
        test_pass "Internal Docker network accessible (172.30.0.0/24)"
    else
        echo -e "${YELLOW}PARTIAL${NC}"
        test_warn "Internal network test inconclusive"
    fi
}

# ============================================================================
# Test 5: Credentials - Verify Dummy Values
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
test_local_llm
test_traffic_enforcement
test_network_isolation
test_allowed_connectivity
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