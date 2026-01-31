#!/bin/bash
# Auto-generate dummy credentials for agent container
# This ensures agent NEVER has real credentials

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔒 Generating dummy credentials for agent...${NC}"

# Create .env with dummy credentials
cat > /home/agent/.env << 'EOF'
# ============================================================================
# SLAPENIR Agent Environment - DUMMY CREDENTIALS ONLY
# ============================================================================
# 
# ⚠️  WARNING: These are DUMMY credentials that get replaced by the proxy
# ⚠️  NEVER put real credentials in this file!
# 
# The proxy intercepts requests and injects real credentials automatically.
# The agent should NEVER see or have access to real API keys.
#
# How it works:
#   Agent uses:  DUMMY_OPENAI
#   Proxy injects: sk-proj-real-key-123...
#   Agent receives: [REDACTED]
# ============================================================================

# LLM API Keys (DUMMY - Replaced by Proxy)
OPENAI_API_KEY=DUMMY_OPENAI
ANTHROPIC_API_KEY=DUMMY_ANTHROPIC
GEMINI_API_KEY=DUMMY_GEMINI
MISTRAL_API_KEY=DUMMY_MISTRAL

# Cloud Provider Keys (DUMMY - Replaced by Proxy)
AWS_ACCESS_KEY_ID=DUMMY_AWS_ACCESS
AWS_SECRET_ACCESS_KEY=DUMMY_AWS_SECRET
AWS_REGION=us-east-1
AZURE_API_KEY=DUMMY_AZURE

# Version Control (DUMMY - Replaced by Proxy)
GITHUB_TOKEN=DUMMY_GITHUB
GITLAB_TOKEN=DUMMY_GITLAB

# Communication Services (DUMMY - Replaced by Proxy)
SLACK_BOT_TOKEN=xoxb-DUMMY
SLACK_APP_TOKEN=xapp-DUMMY
SLACK_SIGNING_SECRET=DUMMY_SLACK_SIGNING
DISCORD_BOT_TOKEN=DUMMY_DISCORD
TWILIO_AUTH_TOKEN=DUMMY_TWILIO

# Payment & E-Commerce (DUMMY - Replaced by Proxy)
STRIPE_SECRET_KEY=sk_test_DUMMY
BINANCE_API_KEY=DUMMY_BINANCE
EBAY_OAUTH_TOKEN=v^1.1#DUMMY_EBAY

# Email Services (DUMMY - Replaced by Proxy)
SENDGRID_API_KEY=SG.DUMMY

# IBM Cloud Services (DUMMY - Replaced by Proxy)
IBM_API_KEY=DUMMY_IBM
ICA_API_KEY=DUMMY_ICA
IBM_BASE_URL=https://servicesessentials.ibm.com/apis/v3
IBM_MODEL_ID=global/anthropic.claude-sonnet-4-5-20250929-v1:0

# Research & Academic APIs (DUMMY - Replaced by Proxy)
S2_API_KEY=DUMMY_S2

# ============================================================================
# Proxy Configuration (REQUIRED - DO NOT CHANGE)
# ============================================================================
# All outbound traffic MUST go through the proxy
HTTP_PROXY=http://proxy:3000
HTTPS_PROXY=http://proxy:3000
NO_PROXY=localhost,127.0.0.1,proxy

# Python Configuration
PYTHONUNBUFFERED=1

# ============================================================================
# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
# ============================================================================
EOF

chmod 600 /home/agent/.env
chown agent:agent /home/agent/.env

echo -e "${GREEN}✅ Dummy credentials generated at /home/agent/.env${NC}"
echo -e "${BLUE}   These credentials are safe and contain NO real secrets${NC}"
