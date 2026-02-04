#!/bin/bash
# Run all agent tests and report coverage

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  SLAPENIR Agent Test Suite            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0

# Run environment export tests
echo -e "${YELLOW}Running Environment Export Tests...${NC}"
if ./test_env_export.sh; then
    ENV_RESULT="✓ PASSED"
    ENV_COLOR=$GREEN
    TOTAL_PASSED=$((TOTAL_PASSED + 8))
else
    ENV_RESULT="✗ FAILED"
    ENV_COLOR=$RED
    TOTAL_FAILED=$((TOTAL_FAILED + 8))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 8))
echo ""

# Summary
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Overall Test Summary                 ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "Total Test Suites:  1"
echo -e "Total Tests:        $TOTAL_TESTS"
echo -e "${GREEN}Passed:             $TOTAL_PASSED${NC}"
echo -e "${RED}Failed:             $TOTAL_FAILED${NC}"
echo ""

# Calculate coverage
if [ $TOTAL_TESTS -gt 0 ]; then
    COVERAGE=$(awk "BEGIN {printf \"%.1f\", ($TOTAL_PASSED / $TOTAL_TESTS) * 100}")
else
    COVERAGE="0.0"
fi

echo -e "Coverage:           ${COVERAGE}%"
echo ""

# Test suite results
echo "Test Suite Results:"
echo -e "  Environment Export: ${ENV_COLOR}${ENV_RESULT}${NC}"
echo ""

if [ $TOTAL_FAILED -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✓ ALL TESTS PASSED!                  ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ✗ SOME TESTS FAILED                  ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════╝${NC}"
    exit 1
fi
