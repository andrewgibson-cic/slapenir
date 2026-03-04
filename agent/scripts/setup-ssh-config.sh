#!/bin/bash
# Setup SSH config by filtering macOS-specific options
# Don't use set -e because we need to handle permission errors gracefully

echo "🔐 Setting up SSH config for container..."

# Fix .ssh directory permissions (may be owned by root from volume mounts)
if [ -d /home/agent/.ssh ]; then
    # Change ownership if running as root (don't use -R to avoid read-only mount errors)
    if [ "$(id -u)" = "0" ]; then
        chown agent:agent /home/agent/.ssh 2>/dev/null || true
    fi
    chmod 700 /home/agent/.ssh
fi

# macOS-specific SSH options that don't exist in Linux SSH
MACOS_OPTIONS="UseKeychain|IgnoreUnknown|AddKeysToAgent"

# If host SSH config exists, filter it
if [ -f /home/agent/.ssh/config.host ]; then
    echo "📝 Filtering macOS-specific options from SSH config..."
    
    # Filter out macOS-specific lines and Match blocks, write to container config
    # Also filter out the Include line for colima config (doesn't exist in container)
    grep -vE "^\s*(${MACOS_OPTIONS})|^Include.*colima|^Match host \* exec" /home/agent/.ssh/config.host > /home/agent/.ssh/config
    
    chmod 600 /home/agent/.ssh/config
    chown agent:agent /home/agent/.ssh/config 2>/dev/null || true
    
    echo "✅ SSH config filtered and configured"
    echo "📋 Config preview:"
    head -20 /home/agent/.ssh/config
else
    echo "⚠️  No host SSH config found"
fi

# Handle known_hosts - check if it's writable
if [ -f /home/agent/.ssh/known_hosts ]; then
    # Try to make it writable
    chmod 644 /home/agent/.ssh/known_hosts 2>/dev/null || true
    chown agent:agent /home/agent/.ssh/known_hosts 2>/dev/null || true
fi

# Add GitHub host keys to a temporary file if known_hosts is read-only
if ! grep -q "github.com" /home/agent/.ssh/known_hosts 2>/dev/null; then
    echo "🔑 Adding GitHub host keys..."
    if [ -w /home/agent/.ssh/known_hosts ]; then
        ssh-keyscan -t ed25519 github.com >> /home/agent/.ssh/known_hosts 2>/dev/null
        echo "✅ GitHub host keys added to known_hosts"
    else
        echo "⚠️  known_hosts is read-only - GitHub keys not added (may see host key verification errors)"
    fi
fi

echo "✅ SSH setup complete"
