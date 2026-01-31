#!/bin/bash
# Run SLAPENIR Agent Security Tests
# Tests that agent NEVER has access to real credentials

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}SLAPENIR Security Test Suite${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Change to test directory
cd "$(dirname "$0")"

# Run Python security tests
echo -e "${BLUE}Running Python security tests...${NC}"
echo ""

if python3 test_security_credentials.py; then
    echo ""
    echo -e "${GREEN}✅ All Python security tests passed!${NC}"
    PYTHON_RESULT=0
else
    echo ""
    echo -e "${RED}❌ Python security tests failed!${NC}"
    PYTHON_RESULT=1
fi

echo ""
echo -e "${BLUE}================================${NC}"

# Run bash validation script
echo -e "${BLUE}Running bash security validation...${NC}"
echo ""

if /home/agent/scripts/validate-env.sh; then
    echo ""
    echo -e "${GREEN}✅ Bash security validation passed!${NC}"
    BASH_RESULT=0
else
    echo ""
    echo -e "${RED}❌ Bash security validation failed!${NC}"
    BASH_RESULT=1
fi

echo ""
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}================================${NC}"

if [ $PYTHON_RESULT -eq 0 ] && [ $BASH_RESULT -eq 0 ]; then
    echo -e "${GREEN}✅ ALL SECURITY TESTS PASSED${NC}"
    echo -e "${GREEN}   Agent environment is secure${NC}"
    echo -e "${GREEN}   No real credentials detected${NC}"
    exit 0
else
    echo -e "${RED}❌ SECURITY TESTS FAILED${NC}"
    echo -e "${RED}   Review the failures above${NC}"
    [ $PYTHON_RESULT -ne 0 ] && echo -e "${RED}   - Python tests failed${NC}"
    [ $BASH_RESULT -ne 0 ] && echo -e "${RED}   - Bash validation failed${NC}"
    exit 1
fi