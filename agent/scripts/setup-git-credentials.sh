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

# Check if GITHUB_TOKEN is set
if [ -z "$GITHUB_TOKEN" ]; then
  echo -e "${RED}⚠️  WARNING: GITHUB_TOKEN not set${NC}"
  echo "   Git operations will fail. Please set GITHUB_TOKEN environment variable."
  echo "   Example: export GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx"
  exit 1
fi

# Validate token format (basic check)
if [[ ! "$GITHUB_TOKEN" =~ ^(ghp_|gho_|ghu_|ghs_|ghr_) ]]; then
  echo -e "${YELLOW}⚠️  WARNING: GITHUB_TOKEN doesn't match expected format${NC}"
  echo "   Expected format: ghp_*, gho_*, ghu_*, ghs_*, or ghr_*"
fi

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

# Validate token with GitHub API (optional but recommended)
if [ "${VALIDATE_GITHUB_TOKEN:-true}" = "true" ]; then
  echo "🔍 Validating GitHub token..."
  
  response=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $GITHUB_TOKEN" \
    https://api.github.com/user 2>/dev/null)
  
  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | head -n-1)
  
  if [ "$http_code" = "200" ]; then
    username=$(echo "$body" | grep -o '"login":"[^"]*"' | cut -d'"' -f4)
    echo -e "${GREEN}✅ GitHub token valid${NC} (authenticated as: $username)"
  else
    echo -e "${RED}❌ GitHub token validation failed (HTTP $http_code)${NC}"
    echo "   Token may be expired or have insufficient permissions"
    exit 1
  fi
fi

echo -e "${GREEN}✅ Git credentials configured successfully${NC}"
echo ""
echo "📋 Configuration summary:"
git config --global --list | grep -E "(credential|user\.|url\.)"
echo ""
echo "🚀 Ready for Git operations (clone, pull, push, etc.)"