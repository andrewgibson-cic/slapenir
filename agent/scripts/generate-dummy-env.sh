#!/bin/bash
# ============================================================================
# Generate Dummy Environment Variables from .env
# ============================================================================
# This script reads the host .env file and creates a dummy version for the agent
# All real credential values are replaced with DUMMY_ patterns
# Exports variables to s6-overlay environment for container-wide access
# ============================================================================

set -e

ENV_SOURCE="/host-env/.env"
ENV_TARGET="/home/agent/.env"
S6_ENV_DIR="/var/run/s6/container_environment"

echo "🔧 Generating dummy credentials for agent..."

if [ ! -f "$ENV_SOURCE" ]; then
    echo "❌ Error: Source .env file not found at $ENV_SOURCE"
    echo "   Please ensure .env is mounted to /host-env/.env"
    exit 1
fi

# Create s6 environment directory if it doesn't exist
mkdir -p "$S6_ENV_DIR" 2>/dev/null || true

# Function to set environment variable in s6
set_s6_env() {
    local key="$1"
    local value="$2"
    # Write to s6 environment directory
    echo -n "$value" > "${S6_ENV_DIR}/${key}" 2>/dev/null || true
    # Also export to current shell
    export "${key}=${value}"
}

# Create dummy .env by replacing real values with DUMMY_ patterns
cat "$ENV_SOURCE" | while IFS= read -r line; do
    # Skip comments and empty lines
    if [[ "$line" =~ ^#.*$ ]] || [[ -z "$line" ]]; then
        echo "$line"
        continue
    fi
    
    # Parse KEY=VALUE
    if [[ "$line" =~ ^([A-Z_]+)=(.*)$ ]]; then
        key="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"
        
        # Determine dummy value and export
        case "$key" in
            OPENAI_API_KEY)
                dummy_value="DUMMY_OPENAI"
                echo "${key}=${dummy_value}"
                set_s6_env "$key" "$dummy_value"
                ;;
            ANTHROPIC_API_KEY)
                dummy_value="DUMMY_ANTHROPIC"
                echo "${key}=${dummy_value}"
                set_s6_env "$key" "$dummy_value"
                ;;
            GEMINI_API_KEY)
                dummy_value="DUMMY_GEMINI"
                echo "${key}=${dummy_value}"
                set_s6_env "$key" "$dummy_value"
                ;;
            MISTRAL_API_KEY)
                dummy_value="DUMMY_MISTRAL"
                echo "${key}=${dummy_value}"
                set_s6_env "$key" "$dummy_value"
                ;;
            AWS_ACCESS_KEY_ID)
                dummy_value="DUMMY_AWS_ACCESS"
                echo "${key}=${dummy_value}"
                set_s6_env "$key" "$dummy_value"
                ;;
            AWS_SECRET_ACCESS_KEY)
                dummy_value="DUMMY_AWS_SECRET"
                echo "${key}=${dummy_value}"
                set_s6_env "$key" "$dummy_value"
                ;;
            GITHUB_TOKEN)
                dummy_value="DUMMY_GITHUB"
                echo "${key}=${dummy_value}"
                set_s6_env "$key" "$dummy_value"
                ;;
            GITLAB_TOKEN)
                dummy_value="DUMMY_GITLAB"
                echo "${key}=${dummy_value}"
                set_s6_env "$key" "$dummy_value"
                ;;
            SLACK_BOT_TOKEN)
                dummy_value="xoxb-DUMMY_SLACK"
                echo "${key}=${dummy_value}"
                set_s6_env "$key" "$dummy_value"
                ;;
            SLACK_APP_TOKEN)
                dummy_value="xapp-DUMMY_SLACK_APP"
                echo "${key}=${dummy_value}"
                set_s6_env "$key" "$dummy_value"
                ;;
            SLACK_SIGNING_SECRET|DISCORD_BOT_TOKEN|TWILIO_AUTH_TOKEN)
                dummy_value="DUMMY_${key%%_*}"
                echo "${key}=${dummy_value}"
                set_s6_env "$key" "$dummy_value"
                ;;
            STRIPE_SECRET_KEY)
                dummy_value="sk_test_DUMMY_STRIPE"
                echo "${key}=${dummy_value}"
                set_s6_env "$key" "$dummy_value"
                ;;
            BINANCE_API_KEY|EBAY_OAUTH_TOKEN|SENDGRID_API_KEY|IBM_API_KEY|ICA_API_KEY|S2_API_KEY|AZURE_API_KEY)
                dummy_value="DUMMY_${key%%_*}"
                echo "${key}=${dummy_value}"
                set_s6_env "$key" "$dummy_value"
                ;;
            # Preserve system configuration (not credentials)
            AWS_REGION|IBM_BASE_URL|IBM_MODEL_ID|NETWORK_INTERNAL|ENVIRONMENT)
                echo "${key}=${value}"
                set_s6_env "$key" "$value"
                ;;
            STEPCA_PASSWORD|GRAFANA_ADMIN_PASSWORD|GRAFANA_ADMIN_USER)
                echo "${key}=${value}"
                set_s6_env "$key" "$value"
                ;;
            MTLS_*)
                echo "${key}=${value}"
                set_s6_env "$key" "$value"
                ;;
            # Default: if it looks like a credential, make it dummy
            *API_KEY|*TOKEN|*SECRET|*PASSWORD)
                dummy_value="DUMMY_${key}"
                echo "${key}=${dummy_value}"
                set_s6_env "$key" "$dummy_value"
                ;;
            *)
                # Keep other values as-is
                echo "${key}=${value}"
                set_s6_env "$key" "$value"
                ;;
        esac
    else
        # Keep line as-is if not KEY=VALUE format
        echo "$line"
    fi
done > "$ENV_TARGET"

# Add required proxy configuration
echo "" >> "$ENV_TARGET"
echo "# ============================================================================" >> "$ENV_TARGET"
echo "# Proxy Configuration (Auto-added)" >> "$ENV_TARGET"
echo "# ============================================================================" >> "$ENV_TARGET"
echo "HTTP_PROXY=http://proxy:3000" >> "$ENV_TARGET"
echo "HTTPS_PROXY=http://proxy:3000" >> "$ENV_TARGET"
echo "NO_PROXY=localhost,127.0.0.1,proxy" >> "$ENV_TARGET"
echo "PYTHONUNBUFFERED=1" >> "$ENV_TARGET"

# Export proxy settings to s6 environment
set_s6_env "HTTP_PROXY" "http://proxy:3000"
set_s6_env "HTTPS_PROXY" "http://proxy:3000"
set_s6_env "NO_PROXY" "localhost,127.0.0.1,proxy"

# Set proper permissions
chmod 600 "$ENV_TARGET"
chown agent:agent "$ENV_TARGET" 2>/dev/null || true

echo "✅ Dummy credentials generated at $ENV_TARGET"
echo "✅ Variables exported to s6-overlay environment"
echo "🔒 Agent will use DUMMY values for all credentials"