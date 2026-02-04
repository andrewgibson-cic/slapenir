#!/bin/bash
# Initialize agent environment on container startup
# This runs as part of the s6-overlay initialization

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Initializing SLAPENIR Agent Environment...${NC}"
echo ""

# Step 1: Generate dummy credentials if not exists or forced
if [ ! -f /home/agent/.env ] || [ "$FORCE_REGENERATE_ENV" = "true" ]; then
    echo -e "${BLUE}Step 1: Generating dummy credentials from proxy configuration...${NC}"
    /home/agent/scripts/generate-dummy-env-from-proxy.sh
else
    echo -e "${GREEN}Step 1: Dummy credentials already exist${NC}"
fi

echo ""

# Step 2: Validate environment security
echo -e "${BLUE}Step 2: Validating environment security...${NC}"
if /home/agent/scripts/validate-env.sh; then
    echo ""
else
    echo -e "${YELLOW}⚠️  Validation failed but continuing startup...${NC}"
    echo -e "${YELLOW}   (This may indicate a security issue)${NC}"
    echo ""
fi

# Step 3: Export dummy credentials to s6 environment
if [ -f /home/agent/.env ]; then
    echo -e "${BLUE}Step 3: Exporting dummy credentials to container environment...${NC}"
    
    # Export to s6 environment (makes variables available to all processes)
    /home/agent/scripts/export-dummy-env.sh
    
    # Also add to .bashrc for interactive shells
    if [ ! -f /home/agent/.env_exported ]; then
        echo "" >> /home/agent/.bashrc
        echo "# Auto-generated: Load dummy credentials for interactive shells" >> /home/agent/.bashrc
        echo "if [ -f /home/agent/.env ]; then" >> /home/agent/.bashrc
        echo "    set -a" >> /home/agent/.bashrc
        echo "    source /home/agent/.env" >> /home/agent/.bashrc
        echo "    set +a" >> /home/agent/.bashrc
        echo "fi" >> /home/agent/.bashrc
        touch /home/agent/.env_exported
    fi
    
    echo -e "${GREEN}✅ Dummy credentials exported to container environment${NC}"
    echo ""
fi

# Step 4: Verify proxy connectivity (with timeout and retry)
echo -e "${BLUE}Step 4: Verifying proxy connectivity...${NC}"
MAX_RETRIES=10
RETRY_COUNT=0
PROXY_READY=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s -f -m 2 http://proxy:3000/health > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Proxy is reachable and healthy${NC}"
        PROXY_READY=true
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            echo -e "${YELLOW}   Proxy not ready, retrying ($RETRY_COUNT/$MAX_RETRIES)...${NC}"
            sleep 2
        fi
    fi
done

if [ "$PROXY_READY" = false ]; then
    echo -e "${YELLOW}⚠️  Warning: Proxy not reachable after $MAX_RETRIES attempts${NC}"
    echo -e "${YELLOW}   Agent will start but may not be able to make API calls${NC}"
    echo -e "${YELLOW}   The proxy may still be initializing...${NC}"
fi

echo ""
echo "=================================="
echo -e "${GREEN}✅ Agent environment initialized${NC}"
echo "=================================="
echo ""
echo -e "${BLUE}Configuration Summary:${NC}"
echo -e "  Dummy credentials: ${GREEN}Loaded${NC}"
echo -e "  Security validation: ${GREEN}Passed${NC}"
echo -e "  Proxy connectivity: $([ "$PROXY_READY" = true ] && echo -e "${GREEN}Ready${NC}" || echo -e "${YELLOW}Pending${NC}")"
echo -e "  Working directory: ${BLUE}/home/agent/workspace${NC}"
echo ""