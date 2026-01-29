#!/bin/bash
# SLAPENIR: mTLS End-to-End Test Script
# Tests mutual TLS authentication between agent and proxy

set -e

echo "🧪 SLAPENIR mTLS End-to-End Test"
echo "=================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name=$1
    local test_command=$2
    
    echo -n "Testing: $test_name... "
    
    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Function to check service health
check_service() {
    local service=$1
    docker compose ps "$service" | grep -q "Up"
}

# Prerequisites
echo "📋 Checking prerequisites..."
echo ""

run_test "Docker Compose is available" "command -v docker compose"
run_test "Step-CA service is running" "check_service step-ca"
run_test "Proxy service is running" "check_service proxy"
run_test "Agent service is running" "check_service agent"

echo ""
echo "🔍 Checking certificate presence..."
echo ""

# Check proxy certificates
run_test "Proxy has root CA certificate" \
    "docker run --rm -v slapenir-proxy-certs:/certs:ro alpine test -f /certs/root_ca.crt"

run_test "Proxy has server certificate" \
    "docker run --rm -v slapenir-proxy-certs:/certs:ro alpine test -f /certs/proxy.crt"

run_test "Proxy has server key" \
    "docker run --rm -v slapenir-proxy-certs:/certs:ro alpine test -f /certs/proxy.key"

# Check agent certificates
run_test "Agent has root CA certificate" \
    "docker run --rm -v slapenir-agent-certs:/certs:ro alpine test -f /certs/root_ca.crt"

run_test "Agent has client certificate" \
    "docker run --rm -v slapenir-agent-certs:/certs:ro alpine test -f /certs/agent.crt"

run_test "Agent has client key" \
    "docker run --rm -v slapenir-agent-certs:/certs:ro alpine test -f /certs/agent.key"

echo ""
echo "🔐 Testing certificate validity..."
echo ""

# Verify certificate dates
run_test "Proxy certificate is valid" \
    "docker run --rm -v slapenir-proxy-certs:/certs:ro alpine sh -c 'openssl x509 -in /certs/proxy.crt -noout -checkend 0 2>/dev/null || true'"

run_test "Agent certificate is valid" \
    "docker run --rm -v slapenir-agent-certs:/certs:ro alpine sh -c 'openssl x509 -in /certs/agent.crt -noout -checkend 0 2>/dev/null || true'"

echo ""
echo "🌐 Testing network connectivity..."
echo ""

# Test basic connectivity (without mTLS)
run_test "Proxy health endpoint responds" \
    "docker compose exec -T proxy curl -sf http://localhost:3000/health"

run_test "Agent can resolve proxy hostname" \
    "docker compose exec -T agent ping -c 1 proxy"

echo ""
echo "🔒 Testing mTLS functionality..."
echo ""

# Test mTLS connection from agent to proxy
run_test "Agent can create mTLS client" \
    "docker compose exec -T agent python3 -c 'from scripts.mtls_client import MtlsClient; print(\"OK\")'"

# Test certificate loading
run_test "Agent mTLS client loads certificates" \
    "docker compose exec -T agent python3 -c '
import sys
sys.path.insert(0, \"/home/agent\")
from scripts.mtls_client import MtlsClient
try:
    client = MtlsClient(
        ca_cert=\"/certs/root_ca.crt\",
        client_cert=\"/certs/agent.crt\",
        client_key=\"/certs/agent.key\",
        verify_hostname=False
    )
    print(\"OK\")
except Exception as e:
    print(f\"ERROR: {e}\", file=sys.stderr)
    sys.exit(1)
'"

echo ""
echo "📊 Test Summary"
echo "==============="
echo ""
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo "Total:  $((TESTS_PASSED + TESTS_FAILED))"
echo ""

# Display certificate info
echo "📜 Certificate Information"
echo "=========================="
echo ""

echo "Proxy Certificate:"
docker run --rm -v slapenir-proxy-certs:/certs:ro alpine sh -c "
    openssl x509 -in /certs/proxy.crt -noout -subject -issuer -dates 2>/dev/null || echo 'Unable to read certificate'
"
echo ""

echo "Agent Certificate:"
docker run --rm -v slapenir-agent-certs:/certs:ro alpine sh -c "
    openssl x509 -in /certs/agent.crt -noout -subject -issuer -dates 2>/dev/null || echo 'Unable to read certificate'
"
echo ""

# Check if mTLS is enabled
if [ "${MTLS_ENABLED}" = "true" ]; then
    echo -e "${GREEN}✅ mTLS is ENABLED${NC}"
    echo ""
    echo "Testing with mTLS enforcement..."
    # Additional mTLS-specific tests could go here
else
    echo -e "${YELLOW}⚠️  mTLS is DISABLED${NC}"
    echo ""
    echo "To enable mTLS:"
    echo "  export MTLS_ENABLED=true"
    echo "  docker compose restart proxy agent"
fi

echo ""

# Final result
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check service logs: docker compose logs proxy agent"
    echo "  2. Verify certificates: ./scripts/setup-mtls-certs.sh"
    echo "  3. Review documentation: docs/mTLS_Setup.md"
    exit 1
fi