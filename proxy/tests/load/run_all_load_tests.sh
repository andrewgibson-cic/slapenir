#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${SCRIPT_DIR}/results"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║         SLAPENIR Load Testing Suite                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

mkdir -p "${RESULTS_DIR}"

PROXY_URL="${PROXY_URL:-http://localhost:3000}"
TESTS=("api_load" "proxy_sanitization" "stress_test" "soak_test")

echo "Proxy URL: ${PROXY_URL}"
echo "Results directory: ${RESULTS_DIR}"
echo ""

FAILED_TESTS=()
PASSED_TESTS=()

for test in "${TESTS[@]}"; do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Running test: ${test}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    TEST_FILE="${SCRIPT_DIR}/${test}.js"
    RESULT_FILE="${RESULTS_DIR}/${test}-results.json"
    
    if [ ! -f "${TEST_FILE}" ]; then
        echo "❌ Test file not found: ${TEST_FILE}"
        FAILED_TESTS+=("${test}")
        continue
    fi
    
    if PROXY_URL="${PROXY_URL}" k6 run "${TEST_FILE}" --out json="${RESULT_FILE}"; then
        echo "✅ ${test} passed"
        PASSED_TESTS+=("${test}")
    else
        echo "❌ ${test} failed"
        FAILED_TESTS+=("${test}")
    fi
    
    echo ""
done

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                     TEST SUMMARY                                ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Passed: ${#PASSED_TESTS[@]}"
echo "Failed: ${#FAILED_TESTS[@]}"
echo ""

if [ ${#FAILED_TESTS[@]} -eq 0 ]; then
    echo "✅ All load tests passed!"
    exit 0
else
    echo "❌ Some load tests failed. Check results in ${RESULTS_DIR}"
    exit 1
fi
