#!/bin/bash
# Network Isolation Verification Script
# Tests that network isolation is correctly enforced

set -e

echo "=== Network Isolation Verification ==="
echo ""

PASS=0
FAIL=0

# Test 1: Verify iptables chain exists
echo "Test 1: Verify TRAFFIC_ENFORCE chain exists"
if iptables -L TRAFFIC_ENFORCE -n > /dev/null 2>&1; then
    echo "  ✓ PASS"
    ((PASS++))
else
    echo "  ✗ FAIL: TRAFFIC_ENFORCE chain not found"
    ((FAIL++))
fi

# Test 2: Verify external traffic blocked
echo "Test 2: Verify external traffic blocked (google.com)"
if ! curl -s --connect-timeout 5 https://www.google.com > /dev/null 2>&1; then
    echo "  ✓ PASS: External traffic blocked"
    ((PASS++))
else
    echo "  ✗ FAIL: External traffic allowed (security risk!)"
    ((FAIL++))
fi

# Test 3: Verify llama-server accessible
echo "Test 3: Verify llama-server accessible (host.docker.internal:8080)"
LLAMA_PORT=${LLAMA_SERVER_PORT:-8080}
if curl -s --connect-timeout 5 "http://host.docker.internal:${LLAMA_PORT}/health" > /dev/null 2>&1; then
    echo "  ✓ PASS: Llama server accessible"
    ((PASS++))
else
    echo "  ⚠ SKIP: Llama server not running (expected if not started yet)"
    # Don't count as failure since llama-server might not be running
fi

# Test 4: Verify proxy accessible
echo "Test 4: Verify proxy accessible (proxy:3000)"
if curl -s --connect-timeout 5 "http://proxy:3000/health" > /dev/null 2>&1; then
    echo "  ✓ PASS: Proxy accessible"
    ((PASS++))
else
    echo "  ✗ FAIL: Proxy not accessible"
    ((FAIL++))
fi

# Test 5: Verify iptables DROP rule present
echo "Test 5: Verify DROP rule present in TRAFFIC_ENFORCE"
if iptables -L TRAFFIC_ENFORCE -n | grep -q "DROP"; then
    echo "  ✓ PASS"
    ((PASS++))
else
    echo "  ✗ FAIL: DROP rule not found"
    ((FAIL++))
fi

# Test 6: Verify LOG rule present
echo "Test 6: Verify LOG rule present for bypass attempts"
if iptables -L TRAFFIC_ENFORCE -n | grep -q "LOG"; then
    echo "  ✓ PASS"
    ((PASS++))
else
    echo "  ✗ FAIL: LOG rule not found"
    ((FAIL++))
fi

echo ""
echo "=== Results ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo ""

if [ $FAIL -eq 0 ]; then
    echo "✅ All network isolation tests passed"
    exit 0
else
    echo "❌ Some network isolation tests failed"
    exit 1
fi
