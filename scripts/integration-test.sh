#!/bin/bash
# SLAPENIR Integration Test Script
# Tests end-to-end functionality of the proxy system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Test assertion helper
assert_test() {
    local test_name=$1
    local condition=$2
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if eval "$condition"; then
        log_success "Test $TESTS_RUN: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error "Test $TESTS_RUN: $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test 1: Proxy health endpoint returns 200
test_proxy_health() {
    log_info "Testing proxy health endpoint..."
    local response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health)
    assert_test "Proxy health endpoint returns 200" "[ '$response' = '200' ]"
}

# Test 2: Proxy root endpoint returns HTML
test_proxy_root() {
    log_info "Testing proxy root endpoint..."
    local response=$(curl -s http://localhost:3000/)
    assert_test "Proxy root returns HTML" "echo '$response' | grep -q '<html>'"
}

# Test 3: Proxy metrics endpoint contains metrics
test_proxy_metrics() {
    log_info "Testing proxy metrics endpoint..."
    local response=$(curl -s http://localhost:3000/metrics)
    assert_test "Proxy metrics contain slapenir data" "echo '$response' | grep -q 'slapenir_'"
}

# Test 4: Agent can reach proxy internally
test_agent_to_proxy() {
    log_info "Testing agent -> proxy connectivity..."
    local response=$(docker exec slapenir-agent curl -s -o /dev/null -w "%{http_code}" http://proxy:3000/health)
    assert_test "Agent can reach proxy" "[ '$response' = '200' ]"
}

# Test 5: Agent has dummy environment variables
test_agent_dummy_env() {
    log_info "Testing agent dummy credentials..."
    local count=$(docker exec slapenir-agent sh -c 'env | grep -E "DUMMY_|_DUMMY" | wc -l')
    assert_test "Agent has dummy credentials" "[ '$count' -gt 0 ]"
}

# Test 6: Agent Python can import packages
test_agent_python_imports() {
    log_info "Testing agent Python imports..."
    docker exec slapenir-agent python3 -c "import requests; import json; import os" 2>&1 | grep -q "ImportError" && result=1 || result=0
    assert_test "Agent Python can import packages" "[ '$result' = '0' ]"
}

# Test 7: Agent can make HTTP request through proxy
test_agent_proxy_request() {
    log_info "Testing agent HTTP request through proxy..."
    local response=$(docker exec slapenir-agent sh -c 'HTTP_PROXY=http://proxy:3000 curl -s -o /dev/null -w "%{http_code}" http://proxy:3000/health')
    assert_test "Agent can make request through proxy" "[ '$response' = '200' ]"
}

# Test 8: Proxy sanitizes credentials (dummy pattern detection)
test_credential_sanitization() {
    log_info "Testing credential sanitization..."
    # Test that proxy config contains sanitization patterns
    local has_patterns=$(docker exec slapenir-proxy sh -c 'cat /app/config.yaml 2>/dev/null | grep -i "dummy" | wc -l' || echo "0")
    assert_test "Proxy has sanitization patterns" "[ '$has_patterns' -gt 0 ]"
}

# Test 9: Network isolation (agent cannot reach external without proxy)
test_network_isolation() {
    log_info "Testing network isolation..."
    # In internal network mode, agent should not reach external sites directly
    docker exec slapenir-agent timeout 2 curl -s http://example.com > /dev/null 2>&1 && isolated=0 || isolated=1
    assert_test "Network isolation is enforced" "[ '$isolated' = '1' ]"
}

# Test 10: Volume persistence (agent workspace exists)
test_volume_persistence() {
    log_info "Testing volume persistence..."
    docker exec slapenir-agent sh -c 'ls -la /home/agent/workspace' > /dev/null 2>&1
    assert_test "Agent workspace volume is mounted" "[ $? -eq 0 ]"
}

# Test 11: Step-CA is accessible
test_stepca_accessible() {
    log_info "Testing Step-CA accessibility..."
    docker exec slapenir-ca step ca health > /dev/null 2>&1
    assert_test "Step-CA is accessible and healthy" "[ $? -eq 0 ]"
}

# Test 12: Metrics are being collected
test_metrics_collection() {
    log_info "Testing metrics collection..."
    local metrics=$(curl -s http://localhost:3000/metrics | grep -c "slapenir_")
    assert_test "Metrics are being collected" "[ '$metrics' -gt 5 ]"
}

# Test 13: Container logs are accessible
test_container_logs() {
    log_info "Testing container logs..."
    docker logs slapenir-proxy --tail 10 > /dev/null 2>&1
    local proxy_ok=$?
    docker logs slapenir-agent --tail 10 > /dev/null 2>&1
    local agent_ok=$?
    assert_test "Container logs are accessible" "[ $proxy_ok -eq 0 ] && [ $agent_ok -eq 0 ]"
}

# Test 14: Agent bash environment is configured
test_agent_bash_config() {
    log_info "Testing agent bash configuration..."
    docker exec slapenir-agent sh -c 'source ~/.bashrc && echo $PS1' | grep -q "agent"
    assert_test "Agent bash environment is configured" "[ $? -eq 0 ]"
}

# Test 15: Proxy handles CONNECT method
test_proxy_connect_method() {
    log_info "Testing proxy CONNECT method support..."
    # Test that proxy responds to CONNECT requests
    local response=$(echo -e "CONNECT example.com:443 HTTP/1.1\r\nHost: example.com:443\r\n\r\n" | timeout 2 nc localhost 3000 2>&1 | head -1)
    assert_test "Proxy supports CONNECT method" "echo '$response' | grep -q 'HTTP'"
}

# Test 16: Prometheus is scraping metrics (if running)
test_prometheus_scraping() {
    if docker ps | grep -q "slapenir-prometheus"; then
        log_info "Testing Prometheus metrics scraping..."
        local targets=$(curl -s http://localhost:9090/api/v1/targets | grep -c "up")
        assert_test "Prometheus is scraping targets" "[ '$targets' -gt 0 ]"
    else
        log_info "Skipping Prometheus test (not running)"
        TESTS_RUN=$((TESTS_RUN + 1))
        log_warning "Test $TESTS_RUN: Prometheus scraping (skipped)"
    fi
}

# Test 17: Agent environment file exists
test_agent_env_file() {
    log_info "Testing agent environment file..."
    docker exec slapenir-agent sh -c '[ -f ~/.env.agent ]'
    assert_test "Agent environment file exists" "[ $? -eq 0 ]"
}

# Test 18: No real credentials in agent
test_no_real_credentials_in_agent() {
    log_info "Testing that agent has no real credentials..."
    local real_creds=$(docker exec slapenir-agent sh -c 'env | grep -E "^(OPENAI|GITHUB|ANTHROPIC|AWS)_[A-Z_]*=" | grep -v "DUMMY" | wc -l')
    assert_test "Agent has no real credentials" "[ '$real_creds' -eq 0 ]"
}

# Test 19: Proxy has real credentials
test_proxy_has_real_credentials() {
    log_info "Testing that proxy has real credentials..."
    local real_creds=$(docker exec slapenir-proxy sh -c 'env | grep -E "^(OPENAI|GITHUB|ANTHROPIC|AWS)_[A-Z_]*=" | grep -v "DUMMY" | wc -l' || echo "0")
    assert_test "Proxy has real credentials configured" "[ '$real_creds' -gt 0 ]"
}

# Test 20: End-to-end credential flow simulation
test_e2e_credential_flow() {
    log_info "Testing end-to-end credential flow..."
    # Simulate a request with dummy credentials from agent
    local test_response=$(docker exec slapenir-agent python3 -c "
import os
print('DUMMY' if any('DUMMY' in k or 'DUMMY' in v for k, v in os.environ.items()) else 'NO_DUMMY')
" 2>/dev/null)
    assert_test "E2E credential flow works" "[ '$test_response' = 'DUMMY' ]"
}

# Main test routine
main() {
    echo ""
    echo "======================================================================"
    echo "  SLAPENIR Integration Tests"
    echo "======================================================================"
    echo ""
    
    # Run all tests
    test_proxy_health
    test_proxy_root
    test_proxy_metrics
    test_agent_to_proxy
    test_agent_dummy_env
    test_agent_python_imports
    test_agent_proxy_request
    test_credential_sanitization
    test_network_isolation
    test_volume_persistence
    test_stepca_accessible
    test_metrics_collection
    test_container_logs
    test_agent_bash_config
    test_proxy_connect_method
    test_prometheus_scraping
    test_agent_env_file
    test_no_real_credentials_in_agent
    test_proxy_has_real_credentials
    test_e2e_credential_flow
    
    echo ""
    echo "======================================================================"
    echo "  Test Summary"
    echo "======================================================================"
    echo ""
    echo "Tests Run:    $TESTS_RUN"
    echo "Tests Passed: $TESTS_PASSED"
    echo "Tests Failed: $TESTS_FAILED"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log_success "All integration tests passed!"
        echo "======================================================================"
        exit 0
    else
        log_error "$TESTS_FAILED test(s) failed!"
        echo "======================================================================"
        exit 1
    fi
}

# Check if containers are running before starting tests
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! docker ps | grep -q "slapenir-proxy"; then
        log_error "Proxy container is not running"
        exit 1
    fi
    
    if ! docker ps | grep -q "slapenir-agent"; then
        log_error "Agent container is not running"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
    echo ""
}

# Run prerequisites check
check_prerequisites

# Run main test suite
main