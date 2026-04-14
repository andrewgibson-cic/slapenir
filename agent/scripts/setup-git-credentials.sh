#!/bin/bash
# Configure Git credentials for SLAPENIR Agent
# Run at container startup to initialize Git with secure credential handling
#
# Uses --file to write to ~/.config/git/config instead of --global because
# ~/.gitconfig is mounted read-only from the host. The --file flag guarantees
# writes succeed regardless of git version (older versions of git ignore
# GIT_CONFIG_GLOBAL for --global writes and always target ~/.gitconfig).

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "Configuring Git credentials for SLAPENIR Agent..."

# Create writable git config directory
# ~/.gitconfig is mounted read-only from host, so all writes go here
mkdir -p ~/.config/git
GIT_CONFIG_FILE=~/.config/git/config
export GIT_CONFIG_GLOBAL="$GIT_CONFIG_FILE"

echo "Setting up writable git config at $GIT_CONFIG_FILE"
git config --file "$GIT_CONFIG_FILE" --add safe.directory '*' 2>/dev/null || true
echo -e "${GREEN}Safe directory configured for all locations${NC}"

# Add GitHub's SSH host keys to known_hosts if using SSH
if [ -d /home/agent/.ssh ]; then
    if [ "$(id -u)" = "0" ]; then
        chown -R agent:agent /home/agent/.ssh 2>/dev/null || true
    fi

    if [ -w /home/agent/.ssh/known_hosts ] 2>/dev/null; then
        echo "Adding GitHub host keys to known_hosts..."
        ssh-keyscan -t ed25519 github.com >> /home/agent/.ssh/known_hosts 2>/dev/null || true
        echo -e "${GREEN}GitHub host keys added${NC}"
    else
        echo -e "${YELLOW}known_hosts is read-only - skipping GitHub key addition${NC}"
    fi
fi

echo "Git configured for direct HTTPS authentication"
echo "   Using GitHub PAT token from environment (bypasses proxy)"

# Configure Git credential helper
echo "Setting up credential helper..."
git config --file "$GIT_CONFIG_FILE" credential.helper "/home/agent/scripts/git-credential-helper.sh"

# Configure Git user identity
# Try git config from the host's read-only ~/.gitconfig first (project-specific),
# then fall back to GIT_USER_NAME/GIT_USER_EMAIL env vars, then defaults.
# The host gitconfig uses includeIf which won't match container paths,
# so we read the local repo config if available.
GIT_USER_NAME="${GIT_USER_NAME:-SLAPENIR Agent}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-agent@slapenir.local}"

git config --file "$GIT_CONFIG_FILE" user.name "$GIT_USER_NAME"
git config --file "$GIT_CONFIG_FILE" user.email "$GIT_USER_EMAIL"
echo -e "${GREEN}Git identity configured:${NC} $GIT_USER_NAME <$GIT_USER_EMAIL>"

# Convert SSH URLs to HTTPS automatically
if [ "${GIT_CONVERT_SSH_TO_HTTPS:-true}" = "true" ]; then
  git config --file "$GIT_CONFIG_FILE" url."https://github.com/".insteadOf "git@github.com:"
  echo -e "${GREEN}SSH to HTTPS conversion enabled${NC}"
fi

# Configure sensible defaults
git config --file "$GIT_CONFIG_FILE" pull.rebase false
git config --file "$GIT_CONFIG_FILE" init.defaultBranch main
git config --file "$GIT_CONFIG_FILE" core.autocrlf input

# Configure git to bypass proxy (use PAT tokens directly via HTTPS)
echo "Configuring git to bypass proxy (direct HTTPS with PAT)..."
git config --file "$GIT_CONFIG_FILE" http.proxy ""
git config --file "$GIT_CONFIG_FILE" https.proxy ""
echo -e "${GREEN}Git configured to use direct HTTPS (bypasses proxy)${NC}"

echo -e "${GREEN}Git credentials configured successfully${NC}"
echo ""
echo "Configuration summary:"
git config --file "$GIT_CONFIG_FILE" --list 2>/dev/null | grep -E "(credential|user\.|url\.)" || true
echo ""
echo "Ready for Git operations (clone, pull, push, etc.)"