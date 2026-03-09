#!/bin/bash
# Development wrapper that provides git/SSH access from the container
# Usage: ./dev.sh [command] [args...]
#
# IMPORTANT: On macOS with Colima/Docker Desktop, socket forwarding has limitations.
# This script mounts the SSH keys directly (read-only).
# GPG socket mounting doesn't work reliably - use HTTPS tokens for git instead.
#
# Prerequisites:
#   1. SSH keys available in ~/.ssh/
#
# Examples:
#   ./dev.sh bash              # Start interactive shell
#   ./dev.sh opencode          # Run OpenCode CLI (with network restrictions)
#   ./dev.sh git status        # Run git command
#   ./dev.sh gradle build      # Run Gradle build
#
# Network Access:
#   - Shell sessions: Full internet access (git, package managers)
#   - OpenCode instances: DENIED internet access, ONLY local-llama access
#   - Traffic enforcement stays enabled, selective exemptions via NO_PROXY

set -e

# Detect terminal size
TERM_HEIGHT=$(stty size < /dev/tty 2>/dev/null | awk '{print $1}' || echo "24")
TERM_WIDTH=$(stty size < /dev/tty 2>/dev/null | awk '{print $2}' || echo "80")

# If stty failed, try tput
if [ "$TERM_WIDTH" = "" ] || [ "$TERM_WIDTH" = "0" ]; then
    TERM_WIDTH=$(tput cols 2>/dev/null || echo "80")
fi
if [ "$TERM_HEIGHT" = "" ] || [ "$TERM_HEIGHT" = "0" ]; then
    TERM_HEIGHT=$(tput lines 2>/dev/null || echo "24")
fi

# Final fallback
TERM_WIDTH=${TERM_WIDTH:-80}
TERM_HEIGHT=${TERM_HEIGHT:-24}

# Check if running opencode (needs stricter network access)
IS_OPENCODE=0
if [ "$#" -gt 0 ] && [ "$1" = "opencode" ]; then
    IS_OPENCODE=1
fi

# Configure network access based on command
if [ $IS_OPENCODE -eq 1 ]; then
    # OpenCode: STRICT network isolation
    # Only allow local-llama, deny all internet access
    EXTRA_NO_PROXY="localhost,127.0.0.1,host.docker.internal"
    TRAFFIC_MODE="ENABLED (OpenCode: internet DENIED, local-llama ONLY)"
else
    # Development shell: Allow internet access for git and build tools
    # Comprehensive list of development domains
    EXTRA_NO_PROXY="localhost,127.0.0.1,*.gradle.org,*.maven.org,*.npmjs.org,*.pypi.org,*.pythonhosted.org,*.crates.io,*.github.com,*.gitlab.com,*.bitbucket.org,*.golang.org,*.rubygems.org"
    TRAFFIC_MODE="ENABLED (Dev shell: internet ALLOWED for dev tools)"
fi

echo "🚀 Starting SLAPENIR agent with host git/SSH access..."
echo "   Java 21 + Gradle: ✅"
echo "   SSH keys: ✅"
echo "   GPG signing: ❌ (not supported on macOS Docker)"
echo "   Terminal: ${TERM_WIDTH}x${TERM_HEIGHT}"
echo "   Traffic enforcement: ${TRAFFIC_MODE}"

# Build docker-compose command with SSH keys
# SSH keys are mounted read-only for security
docker-compose run \
    -e TERM="${TERM:-xterm-256color}" \
    -e HOME=/root \
    -e COLUMNS=${TERM_WIDTH} \
    -e LINES=${TERM_HEIGHT} \
    -e NO_PROXY="${EXTRA_NO_PROXY}" \
    -e GRADLE_ALLOW_FROM_OPENCODE=1 \
    -e MVN_ALLOW_FROM_OPENCODE=1 \
    -e NPM_ALLOW_FROM_OPENCODE=1 \
    -e YARN_ALLOW_FROM_OPENCODE=1 \
    -e PNPM_ALLOW_FROM_OPENCODE=1 \
    -e CARGO_ALLOW_FROM_OPENCODE=1 \
    -e PIP_ALLOW_FROM_OPENCODE=1 \
    -e PIP3_ALLOW_FROM_OPENCODE=1 \
    -v "${HOME}/.ssh/id_ed25519_ho:/home/agent/.ssh/id_ed25519_ho:ro" \
    -v "${HOME}/.ssh/id_ed25519_ho.pub:/home/agent/.ssh/id_ed25519_ho.pub:ro" \
    -v "${HOME}/.ssh/id_ed25519_ibm:/home/agent/.ssh/id_ed25519_ibm:ro" \
    -v "${HOME}/.ssh/id_ed25519_ibm.pub:/home/agent/.ssh/id_ed25519_ibm.pub:ro" \
    -v "${HOME}/.ssh/id_ed25519_pythymcpyface:/home/agent/.ssh/id_ed25519_pythymcpyface:ro" \
    -v "${HOME}/.ssh/id_ed25519_pythymcpyface.pub:/home/agent/.ssh/id_ed25519_pythymcpyface.pub:ro" \
    agent /bin/bash -c "export TERM=xterm-256color; export COLUMNS=${TERM_WIDTH}; export LINES=${TERM_HEIGHT}; git config --global --add safe.directory '*' 2>/dev/null || true; stty cols ${TERM_WIDTH} rows ${TERM_HEIGHT} 2>/dev/null || true; exec \"\$@\"" -- "$@"
