#!/bin/bash
# Export dummy credentials to s6 environment
# This makes them available to all processes in the container

set -e

ENV_FILE="/home/agent/.env"
S6_ENV_DIR="/var/run/s6/container_environment"

if [ ! -f "$ENV_FILE" ]; then
    echo "⚠️  Warning: $ENV_FILE not found, skipping environment export"
    exit 0
fi

echo "📤 Exporting dummy credentials to container environment..."

# Read each line from .env and export to s6 environment
while IFS='=' read -r key value || [ -n "$key" ]; do
    # Skip comments and empty lines
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" ]] && continue
    
    # Remove any leading/trailing whitespace
    key=$(echo "$key" | tr -d '[:space:]')
    
    # Skip if not a valid variable name
    [[ ! "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]] && continue
    
    # Export to s6 environment (creates file with variable value)
    if [ -d "$S6_ENV_DIR" ]; then
        echo -n "$value" > "$S6_ENV_DIR/$key"
        echo "  ✓ Exported: $key"
    fi
done < "$ENV_FILE"

echo "✅ Environment variables exported to s6"
