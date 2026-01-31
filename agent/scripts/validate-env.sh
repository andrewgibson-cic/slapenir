#!/bin/bash
# Validate that agent doesn't have real credentials
# This is a critical security check

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Validating agent environment security...${NC}"

FAILED=0
WARNINGS=0

# Patterns that indicate REAL credentials (should NOT be in agent)
declare -A REAL_PATTERNS=(
    ["OpenAI"]="sk-proj-"
    ["Anthropic"]="sk-ant-"
    ["GitHub Personal"]="ghp_"
    ["GitHub OAuth"]="gho_"
    ["Slack Bot (real)"]="xoxb-[0-9]"
    ["Slack App (real)"]="xapp-[0-9]"
    ["AWS Access Key"]="AKIA"
    ["Google API"]="AIza"
    ["Stripe Live"]="sk_live_"
    ["SendGrid"]="SG\.[A-Za-z0-9_-]{22}"
)

# Check environment variables for real credential patterns
echo -e "${BLUE}Checking for real credentials...${NC}"
for service in "${!REAL_PATTERNS[@]}"; do
    pattern="${REAL_PATTERNS[$service]}"
    if env | grep -E "$pattern" > /dev/null 2>&1; then
        echo -e "${RED}❌ SECURITY VIOLATION: Found real $service credential${NC}"
        echo -e "${RED}   Pattern detected: $pattern${NC}"
        FAILED=1
    fi
done

# Check that dummy patterns exist (they should)
echo -e "${BLUE}Checking for dummy credentials...${NC}"
declare -A DUMMY_PATTERNS=(
    ["OpenAI"]="DUMMY_OPENAI"
    ["Anthropic"]="DUMMY_ANTHROPIC"
    ["GitHub"]="DUMMY_GITHUB"
    ["Gemini"]="DUMMY_GEMINI"
)

for service in "${!DUMMY_PATTERNS[@]}"; do
    pattern="${DUMMY_PATTERNS[$service]}"
    if ! env | grep -q "$pattern" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  Warning: $service dummy pattern not found: $pattern${NC}"
        WARNINGS=$((WARNINGS + 1))
    else
        echo -e "${GREEN}✓ $service using dummy credential${NC}"
    fi
done

# Check that proxy is configured
echo -e "${BLUE}Checking proxy configuration...${NC}"
if ! env | grep -q "HTTP_PROXY=http://proxy:3000" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Warning: HTTP_PROXY not set to proxy:3000${NC}"
    WARNINGS=$((WARNINGS + 1))
else
    echo -e "${GREEN}✓ HTTP_PROXY configured correctly${NC}"
fi

if ! env | grep -q "HTTPS_PROXY=http://proxy:3000" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Warning: HTTPS_PROXY not set to proxy:3000${NC}"
    WARNINGS=$((WARNINGS + 1))
else
    echo -e "${GREEN}✓ HTTPS_PROXY configured correctly${NC}"
fi

# Final verdict
echo ""
echo "=================================="
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ SECURITY VALIDATED${NC}"
    echo -e "${GREEN}   Agent environment is secure${NC}"
    echo -e "${GREEN}   No real credentials detected${NC}"
    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}   ($WARNINGS warnings)${NC}"
    fi
    echo "=================================="
    exit 0
else
    echo -e "${RED}❌ SECURITY FAILURE${NC}"
    echo -e "${RED}   Agent has real credentials!${NC}"
    echo -e "${RED}   This violates zero-knowledge architecture${NC}"
    echo ""
    echo -e "${YELLOW}The agent container should NEVER have real credentials.${NC}"
    echo -e "${YELLOW}Only the proxy should have real credentials.${NC}"
    echo ""
    echo -e "${YELLOW}To fix:${NC}"
    echo -e "${YELLOW}1. Remove .env from agent in docker-compose.yml${NC}"
    echo -e "${YELLOW}2. Use .env.proxy for proxy container only${NC}"
    echo -e "${YELLOW}3. Let agent auto-generate dummy credentials${NC}"
    echo "=================================="
    exit 1
fi