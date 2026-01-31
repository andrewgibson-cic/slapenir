#!/bin/bash
# Generate dummy credentials based on what's in .env.proxy
# This ensures agent only has dummies for credentials that actually exist

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔒 Generating dummy credentials based on proxy configuration...${NC}"

# Path to proxy env file (mounted or accessible)
PROXY_ENV_PATH="${PROXY_ENV_PATH:-/tmp/.env.proxy}"

# Mapping of real credential patterns to dummy values
declare -A DUMMY_MAP=(
    ["OPENAI_API_KEY"]="DUMMY_OPENAI"
    ["ANTHROPIC_API_KEY"]="DUMMY_ANTHROPIC"
    ["GEMINI_API_KEY"]="DUMMY_GEMINI"
    ["MISTRAL_API_KEY"]="DUMMY_MISTRAL"
    ["AWS_ACCESS_KEY_ID"]="DUMMY_AWS_ACCESS"
    ["AWS_SECRET_ACCESS_KEY"]="DUMMY_AWS_SECRET"
    ["GITHUB_TOKEN"]="DUMMY_GITHUB"
    ["GITLAB_TOKEN"]="DUMMY_GITLAB"
    ["SLACK_BOT_TOKEN"]="xoxb-DUMMY"
    ["SLACK_APP_TOKEN"]="xapp-DUMMY"
    ["SLACK_SIGNING_SECRET"]="DUMMY_SLACK_SIGNING"
    ["DISCORD_BOT_TOKEN"]="DUMMY_DISCORD"
    ["TWILIO_AUTH_TOKEN"]="DUMMY_TWILIO"
    ["STRIPE_SECRET_KEY"]="sk_test_DUMMY"
    ["BINANCE_API_KEY"]="DUMMY_BINANCE"
    ["EBAY_OAUTH_TOKEN"]="v^1.1#DUMMY_EBAY"
    ["SENDGRID_API_KEY"]="SG.DUMMY"
    ["IBM_API_KEY"]="DUMMY_IBM"
    ["ICA_API_KEY"]="DUMMY_ICA"
    ["S2_API_KEY"]="DUMMY_S2"
    ["AZURE_API_KEY"]="DUMMY_AZURE"
)

# Start building the .env file
cat > /home/agent/.env << 'HEADER'
# ============================================================================
# SLAPENIR Agent Environment - DUMMY CREDENTIALS ONLY
# ============================================================================
# 
# ⚠️  AUTO-GENERATED - Do not edit manually
# ⚠️  These are DUMMY credentials that get replaced by the proxy
# 
# This file contains dummy versions of ONLY the credentials that exist
# in the proxy's .env.proxy file.
#
# How it works:
#   Agent uses:  DUMMY_OPENAI
#   Proxy injects: sk-proj-real-key-123...
#   Agent receives: [REDACTED]
# ============================================================================

HEADER

# If proxy env file is accessible, read it and generate matching dummies
if [ -f "$PROXY_ENV_PATH" ]; then
    echo -e "${BLUE}   Reading credentials from $PROXY_ENV_PATH${NC}"
    
    # Read each line from proxy env
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$line" ]] && continue
        
        # Extract variable name (before =)
        var_name=$(echo "$line" | cut -d '=' -f 1 | tr -d '[:space:]')
        
        # If we have a dummy mapping for this variable, add it
        if [ -n "${DUMMY_MAP[$var_name]}" ]; then
            echo "${var_name}=${DUMMY_MAP[$var_name]}" >> /home/agent/.env
            echo -e "${GREEN}   ✓ ${var_name}=${DUMMY_MAP[$var_name]}${NC}"
        fi
    done < "$PROXY_ENV_PATH"
else
    echo -e "${YELLOW}   ⚠️  Could not access $PROXY_ENV_PATH${NC}"
    echo -e "${YELLOW}   Generating default dummy credentials${NC}"
    
    # Fallback: Generate common dummy credentials
    cat >> /home/agent/.env << 'FALLBACK'
# Common LLM API Keys (DUMMY)
OPENAI_API_KEY=DUMMY_OPENAI
ANTHROPIC_API_KEY=DUMMY_ANTHROPIC
GEMINI_API_KEY=DUMMY_GEMINI
GITHUB_TOKEN=DUMMY_GITHUB
FALLBACK
fi

# Always add proxy configuration and Python settings
cat >> /home/agent/.env << 'FOOTER'

# ============================================================================
# Proxy Configuration (REQUIRED)
# ============================================================================
HTTP_PROXY=http://proxy:3000
HTTPS_PROXY=http://proxy:3000
NO_PROXY=localhost,127.0.0.1,proxy

# Python Configuration
PYTHONUNBUFFERED=1

# ============================================================================
# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
# ============================================================================
FOOTER

chmod 600 /home/agent/.env
chown agent:agent /home/agent/.env 2>/dev/null || true

echo -e "${GREEN}✅ Dummy credentials generated at /home/agent/.env${NC}"
echo -e "${BLUE}   Only credentials present in proxy configuration were added${NC}"