#!/bin/bash
# Development wrapper that provides git/SSH/GPG access from the container
# Usage: ./dev.sh [command] [args...]
#
# IMPORTANT: On macOS with Colima, socket forwarding has limitations.
# This script mounts the SSH keys directly (read-only) as a fallback.
#
# Prerequisites:
#   1. SSH keys available in ~/.ssh/
#   2. GPG public keys in ~/.gnupg/
#
# Examples:
#   ./dev.sh bash              # Start interactive shell
#   ./dev.sh opencode          # Run OpenCode CLI
#   ./dev.sh git status        # Run git command

set -e

echo "🚀 Starting SLAPENIR agent with host git/SSH/GPG access..."

# Create a temporary SSH config that works in the container
# The host's SSH config uses ~/.ssh/id_ed25519_ho etc, but references
# IdentityFile ~/.ssh/id_ed25519_ho which works in both host and container
# We need to add GitHub's host key to known_hosts

# Run docker compose with:
# - SSH keys (read-only, for git operations)
# - GPG public keys (read-only, for verification)
# - Git configs (read-only)
# - SSH config (read-only)
# - known_hosts (read-only)
docker-compose run \
    -v "${HOME}/.ssh/id_ed25519_ho:/home/agent/.ssh/id_ed25519_ho:ro" \
    -v "${HOME}/.ssh/id_ed25519_ho.pub:/home/agent/.ssh/id_ed25519_ho.pub:ro" \
    -v "${HOME}/.ssh/id_ed25519_ibm:/home/agent/.ssh/id_ed25519_ibm:ro" \
    -v "${HOME}/.ssh/id_ed25519_ibm.pub:/home/agent/.ssh/id_ed25519_ibm.pub:ro" \
    -v "${HOME}/.ssh/id_ed25519_pythymcpyface:/home/agent/.ssh/id_ed25519_pythymcpyface:ro" \
    -v "${HOME}/.ssh/id_ed25519_pythymcpyface.pub:/home/agent/.ssh/id_ed25519_pythymcpyface.pub:ro" \
    agent "$@"
