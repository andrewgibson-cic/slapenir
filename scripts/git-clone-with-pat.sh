#!/bin/bash

# Git Clone with PAT Token Authentication
# Automatically uses GITHUB_TOKEN from .env file
# Usage: ./scripts/git-clone-with-pat.sh <repository-url> [destination]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if repository URL is provided
if [ -z "$1" ]; then
    print_error "Repository URL is required"
    echo "Usage: $0 <repository-url> [destination]"
    echo ""
    echo "Examples:"
    echo "  $0 https://github.com/user/repo.git"
    echo "  $0 https://github.com/user/repo.git my-folder"
    echo "  $0 github.com/user/repo.git"
    echo "  $0 user/repo"
    exit 1
fi

REPO_URL="$1"
DESTINATION="${2:-}"

# Find the .env file
ENV_FILE=".env"
if [ ! -f "$ENV_FILE" ]; then
    ENV_FILE="../.env"
    if [ ! -f "$ENV_FILE" ]; then
        print_error ".env file not found in current or parent directory"
        exit 1
    fi
fi

# Extract GITHUB_TOKEN from .env
GITHUB_TOKEN=$(grep '^GITHUB_TOKEN=' "$ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")

if [ -z "$GITHUB_TOKEN" ]; then
    print_error "GITHUB_TOKEN not found in $ENV_FILE"
    exit 1
fi

print_info "Found GitHub token in $ENV_FILE"

# Normalize the repository URL
# Handle various input formats:
# - https://github.com/user/repo.git
# - http://github.com/user/repo.git
# - github.com/user/repo.git
# - github.com/user/repo
# - user/repo

# Remove protocol if present
REPO_URL="${REPO_URL#https://}"
REPO_URL="${REPO_URL#http://}"

# Remove github.com prefix if present
REPO_URL="${REPO_URL#github.com/}"

# Add .git if not present
if [[ ! "$REPO_URL" =~ \.git$ ]]; then
    REPO_URL="${REPO_URL}.git"
fi

# Construct the authenticated URL
AUTHENTICATED_URL="https://${GITHUB_TOKEN}@github.com/${REPO_URL}"

# Clone the repository
print_info "Cloning repository..."

if [ -n "$DESTINATION" ]; then
    git clone "$AUTHENTICATED_URL" "$DESTINATION"
    print_success "Repository cloned to: $DESTINATION"
else
    git clone "$AUTHENTICATED_URL"
    REPO_NAME=$(basename "$REPO_URL" .git)
    print_success "Repository cloned to: $REPO_NAME"
fi

print_info "Done!"