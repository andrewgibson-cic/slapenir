#!/bin/bash
# Setup GPG for commit signing using forwarded agent socket
set -e

echo "🔐 Setting up GPG for commit signing..."

# Create .gnupg directory if needed
mkdir -p /home/agent/.gnupg
chmod 700 /home/agent/.gnupg

# Check for GPG agent socket
GPG_SOCKET="/home/agent/.gnupg/S.gpg-agent"
if [ -S "$GPG_SOCKET" ]; then
    echo "✅ GPG agent socket found at $GPG_SOCKET"
else
    echo "⚠️  GPG agent socket not mounted - commit signing disabled"
    echo "   Run with dev.sh to mount the socket"
    exit 0
fi

# Configure git to use GPG if key is specified
if [ -n "$GPG_KEY" ]; then
    git config --global user.signingkey "$GPG_KEY"
    git config --global commit.gpgsign true
    git config --global gpg.program gpg
    echo "✅ Git configured to sign commits with key: $GPG_KEY"
else
    echo "⚠️  GPG_KEY not set - skipping git configuration"
fi

# Verify GPG can communicate with agent
if gpg-connect-agent /bye 2>/dev/null; then
    echo "✅ GPG agent connection verified"
else
    echo "⚠️  Could not connect to GPG agent"
fi
