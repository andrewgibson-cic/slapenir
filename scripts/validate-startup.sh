#!/bin/bash
# Validate SLAPENIR startup configuration
# Tests mTLS, proxy routing, and credential injection

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  SLAPENIR Startup Validation              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Check if containers are running
echo -e "${BLUE}Checking containers...${NC}"
if ! docker ps | grep -q slapenir-proxy; then
    echo -e "${RED}❌ Proxy container not running${NC}"
    exit 1
fi

if ! docker ps | grep -q slapenir-agent; then
    echo -e "${RED}❌ Agent container not running${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Containers are running${NC}"
echo ""

# Run tests in agent container
echo -e "${BLUE}Running validation tests in agent container...${NC}"
echo ""

docker exec slapenir-agent python3 /home/agent/tests/test_startup_validation.py

exit_code=$?

echo ""
if [ $exit_code -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅ All validation tests passed!          ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
else
    echo -e "${YELLOW}╔════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  ⚠️  Some validation tests failed         ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════╝${NC}"
fi

exit $exit_code