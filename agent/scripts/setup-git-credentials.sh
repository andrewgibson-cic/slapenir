#!/bin/bash
# Configure Git credentials for SLAPENIR Agent
# Run at container startup to initialize Git with secure credential handling

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "🔧 Configuring Git credentials for SLAPENIR Agent..."

# Git uses direct HTTPS with PAT tokens (bypasses proxy)
# This is the recommended and most secure method
echo "📡 Git configured for direct HTTPS authentication"
echo "   Using GitHub PAT token from environment (bypasses proxy)"

# Configure Git credential helper
echo "📝 Setting up credential helper..."
git config --global credential.helper "/home/agent/scripts/git-credential-helper.sh"

# Configure Git user identity
GIT_USER_NAME="${GIT_USER_NAME:-SLAPENIR Agent}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-agent@slapenir.local}"

git config --global user.name "$GIT_USER_NAME"
git config --global user.email "$GIT_USER_EMAIL"
echo -e "${GREEN}✅ Git identity configured:${NC} $GIT_USER_NAME <$GIT_USER_EMAIL>"

# Optional: Configure GitHub CLI compatibility
# Convert SSH URLs to HTTPS automatically
if [ "${GIT_CONVERT_SSH_TO_HTTPS:-true}" = "true" ]; then
  git config --global url."https://github.com/".insteadOf "git@github.com:"
  echo -e "${GREEN}✅ SSH to HTTPS conversion enabled${NC}"
fi

# Configure sensible defaults
git config --global pull.rebase false
git config --global init.defaultBranch main
git config --global core.autocrlf input

# Configure git to bypass proxy (use PAT tokens directly via HTTPS)
# This is more secure and reliable than routing through the proxy
echo "🔧 Configuring git to bypass proxy (direct HTTPS with PAT)..."
git config --global http.proxy ""
git config --global https.proxy ""
echo -e "${GREEN}✅ Git configured to use direct HTTPS${NC} (bypasses proxy)"
echo -e "${GREEN}   This is the recommended and most secure method${NC}"

echo -e "${GREEN}✅ Git credentials configured successfully${NC}"
echo ""
echo "📋 Configuration summary:"
git config --global --list | grep -E "(credential|user\.|url\.)"
echo ""
echo "🚀 Ready for Git operations (clone, pull, push, etc.)"