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

echo "🚀 Starting SLAPENIR agent with host git/SSH access..."
echo "   Java 21 + Gradle: ✅"
echo "   SSH keys: ✅"
echo "   GPG signing: ❌ (not supported on macOS Docker)"

# Build docker-compose command with SSH keys
# SSH keys are mounted read-only for security
docker-compose run \
    -v "${HOME}/.ssh/id_ed25519_ho:/home/agent/.ssh/id_ed25519_ho:ro" \
    -v "${HOME}/.ssh/id_ed25519_ho.pub:/home/agent/.ssh/id_ed25519_ho.pub:ro" \
    -v "${HOME}/.ssh/id_ed25519_ibm:/home/agent/.ssh/id_ed25519_ibm:ro" \
    -v "${HOME}/.ssh/id_ed25519_ibm.pub:/home/agent/.ssh/id_ed25519_ibm.pub:ro" \
    -v "${HOME}/.ssh/id_ed25519_pythymcpyface:/home/agent/.ssh/id_ed25519_pythymcpyface:ro" \
    -v "${HOME}/.ssh/id_ed25519_pythymcpyface.pub:/home/agent/.ssh/id_ed25519_pythymcpyface.pub:ro" \
    agent "$@"
