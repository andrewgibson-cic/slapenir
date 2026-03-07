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
#   ./dev.sh opencode          # Run OpenCode CLI
#   ./dev.sh git status        # Run git command
#   ./dev.sh gradle build      # Run Gradle build

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

echo "🚀 Starting SLAPENIR agent with host git/SSH access..."
echo "   Java 21 + Gradle: ✅"
echo "   SSH keys: ✅"
echo "   GPG signing: ❌ (not supported on macOS Docker)"
echo "   Terminal: ${TERM_WIDTH}x${TERM_HEIGHT}"

# Build docker-compose command with SSH keys
# SSH keys are mounted read-only for security
docker-compose run \
    -e TERM \
    -e COLUMNS=${TERM_WIDTH} \
    -e LINES=${TERM_HEIGHT} \
    -v "${HOME}/.ssh/id_ed25519_ho:/home/agent/.ssh/id_ed25519_ho:ro" \
    -v "${HOME}/.ssh/id_ed25519_ho.pub:/home/agent/.ssh/id_ed25519_ho.pub:ro" \
    -v "${HOME}/.ssh/id_ed25519_ibm:/home/agent/.ssh/id_ed25519_ibm:ro" \
    -v "${HOME}/.ssh/id_ed25519_ibm.pub:/home/agent/.ssh/id_ed25519_ibm.pub:ro" \
    -v "${HOME}/.ssh/id_ed25519_pythymcpyface:/home/agent/.ssh/id_ed25519_pythymcpyface:ro" \
    -v "${HOME}/.ssh/id_ed25519_pythymcpyface.pub:/home/agent/.ssh/id_ed25519_pythymcpyface.pub:ro" \
    agent "$@"
