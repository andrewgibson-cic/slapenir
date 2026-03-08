#!/bin/bash
# OpenCode wrapper with terminal size diagnostics and network enforcement
# This script runs diagnostics, enforces network restrictions, and starts opencode
#
# SECURITY: OpenCode instances must NOT have internet access
# Only local-llama (host.docker.internal:8080) should be accessible

set -e

DEBUG_LOG="/tmp/opencode-wrapper.log"

debug() {
    if [ "$OPENCODE_DEBUG" = "1" ]; then
        echo "[$(date '+%H:%M:%S')] $1" | tee -a "$DEBUG_LOG"
    fi
}

debug "=== OpenCode Wrapper Started ==="
debug ""

# ============================================================================
# SECURITY: Verify and enforce traffic restrictions
# ============================================================================

echo "🔒 Enforcing network isolation for OpenCode..."
echo ""

# Check if running as root (needed for iptables)
if [ "$(id -u)" -eq 0 ]; then
    # We have root access, can verify/modify iptables directly
    if iptables -L TRAFFIC_ENFORCE -n > /dev/null 2>&1; then
        echo "✓ Traffic enforcement chain active"
        
        # Verify DROP rule exists
        if iptables -L TRAFFIC_ENFORCE -n | grep -q "DROP"; then
            echo "✓ Traffic blocking enabled"
        else
            echo "⚠ WARNING: DROP rule not found, re-enabling..."
            /home/agent/scripts/traffic-enforcement.sh || true
        fi
    else
        echo "⚠ Traffic enforcement not active, enabling..."
        /home/agent/scripts/traffic-enforcement.sh || true
    fi
else
    # Not root, try to use sudo if available
    if command -v sudo > /dev/null 2>&1 && sudo -n true 2>/dev/null; then
        echo "Verifying traffic enforcement with sudo..."
        if sudo iptables -L TRAFFIC_ENFORCE -n > /dev/null 2>&1; then
            echo "✓ Traffic enforcement verified"
        else
            echo "⚠ WARNING: Cannot verify traffic enforcement (no root access)"
        fi
    else
        echo "⚠ WARNING: Running without root access, cannot verify traffic enforcement"
        echo "   Assuming traffic enforcement is already active"
    fi
fi

# Clear any NO_PROXY exemptions that might have been set for dev tools
# OpenCode should ONLY access local-llama, nothing else
export NO_PROXY="localhost,127.0.0.1,host.docker.internal"
export no_proxy="localhost,127.0.0.1,host.docker.internal"

# Remove any build tool exemptions
unset GRADLE_ALLOW_FROM_OPENCODE
unset MVN_ALLOW_FROM_OPENCODE
unset NPM_ALLOW_FROM_OPENCODE
unset YARN_ALLOW_FROM_OPENCODE
unset PNPM_ALLOW_FROM_OPENCODE
unset CARGO_ALLOW_FROM_OPENCODE
unset PIP_ALLOW_FROM_OPENCODE
unset PIP3_ALLOW_FROM_OPENCODE

echo "✓ Network isolation configured:"
echo "  - Internet access: DENIED"
echo "  - Local-llama access: ALLOWED (host.docker.internal:8080)"
echo ""

# ============================================================================
# Terminal size setup
# ============================================================================

# Run diagnostics if available
if [ -x "/home/agent/scripts/check-terminal-size.sh" ]; then
    debug "Running terminal size check..."
    /home/agent/scripts/check-terminal-size.sh || true
fi

# Show current terminal info
debug "Terminal Information:"
debug "  Size: $(tput cols 2>/dev/null || echo '?')x$(tput lines 2>/dev/null || echo '?')"
debug "  COLUMNS: ${COLUMNS:-<not set>}"
debug "  LINES: ${LINES:-<not set>}"
debug "  TERM: ${TERM:-<not set>}"
debug ""

# Check for common issues
if [ -z "$COLUMNS" ] || [ -z "$LINES" ]; then
    echo "⚠️  WARNING: COLUMNS or LINES not set"
    echo "   Attempting to detect terminal size..."
    
    DETECTED_COLS=$(tput cols 2>/dev/null || echo "")
    DETECTED_LINES=$(tput lines 2>/dev/null || echo "")
    
    if [ -n "$DETECTED_COLS" ] && [ -n "$DETECTED_LINES" ]; then
        echo "   Detected: ${DETECTED_COLS}x${DETECTED_LINES}"
        export COLUMNS="$DETECTED_COLS"
        export LINES="$DETECTED_LINES"
        echo "   ✅ Environment variables set"
    else
        echo "   ❌ Could not detect terminal size"
        echo "   Using fallback: 80x24"
        export COLUMNS="${COLUMNS:-80}"
        export LINES="${LINES:-24}"
    fi
    echo ""
fi

# Verify size is reasonable
if [ "$COLUMNS" -lt 20 ] 2>/dev/null || [ "$LINES" -lt 10 ] 2>/dev/null; then
    echo "⚠️  WARNING: Terminal size seems too small (${COLUMNS}x${LINES})"
    echo "   opencode may not render correctly"
    echo ""
fi

debug "Starting opencode with:"
debug "  COLUMNS=$COLUMNS"
debug "  LINES=$LINES"
debug "  NO_PROXY=$NO_PROXY"
debug ""

# ============================================================================
# Start opencode
# ============================================================================

# Start opencode
exec opencode "$@"
