#!/bin/bash

# Setup Git PAT Token Authentication
# Configures git credential helper to use GITHUB_TOKEN from .env
# This makes git automatically authenticate for all operations (clone, push, pull, etc.)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
}

print_info() {
    echo -e "${YELLOW}INFO: $1${NC}"
}

print_step() {
    echo -e "${BLUE}>>> $1${NC}"
}

# Find the .env file
ENV_FILE=".env"
if [ ! -f "$ENV_FILE" ]; then
    ENV_FILE="../.env"
    if [ ! -f "$ENV_FILE" ]; then
        print_error ".env file not found in current or parent directory"
        exit 1
    fi
fi

# Extract tokens from .env
GITHUB_TOKEN=$(grep '^GITHUB_TOKEN=' "$ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
GIT_USER_NAME=$(grep '^GIT_USER_NAME=' "$ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
GIT_USER_EMAIL=$(grep '^GIT_USER_EMAIL=' "$ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")

if [ -z "$GITHUB_TOKEN" ]; then
    print_error "GITHUB_TOKEN not found in $ENV_FILE"
    exit 1
fi

print_info "Found GitHub token in $ENV_FILE"

# Configure git user if available
if [ -n "$GIT_USER_NAME" ]; then
    print_step "Configuring git user name: $GIT_USER_NAME"
    git config --global user.name "$GIT_USER_NAME"
    print_success "Git user name configured"
fi

if [ -n "$GIT_USER_EMAIL" ]; then
    print_step "Configuring git user email: $GIT_USER_EMAIL"
    git config --global user.email "$GIT_USER_EMAIL"
    print_success "Git user email configured"
fi

# Configure git credential helper
print_step "Configuring git credential helper..."

# Use the store credential helper
git config --global credential.helper store

# Create/update the credentials file
CRED_FILE="$HOME/.git-credentials"

# Remove any existing github.com credentials
if [ -f "$CRED_FILE" ]; then
    grep -v "github.com" "$CRED_FILE" > "$CRED_FILE.tmp" 2>/dev/null || true
    mv "$CRED_FILE.tmp" "$CRED_FILE"
fi

# Add the new credentials
echo "https://${GITHUB_TOKEN}@github.com" >> "$CRED_FILE"
chmod 600 "$CRED_FILE"

print_success "Git credentials configured"

# Configure git to use HTTPS instead of SSH for github.com (optional)
print_step "Configuring git URL rewriting..."
git config --global url."https://github.com/".insteadOf "git@github.com:"
print_success "Git will automatically use HTTPS with PAT for github.com"

echo ""
print_success "Git PAT authentication setup complete!"
echo ""
echo "You can now use git commands without specifying credentials:"
echo "  git clone https://github.com/user/repo.git"
echo "  git pull"
echo "  git push"
echo ""
print_info "To undo this configuration, run:"
echo "  git config --global --unset credential.helper"
echo "  git config --global --unset url.https://github.com/.insteadOf"
echo "  rm ~/.git-credentials"