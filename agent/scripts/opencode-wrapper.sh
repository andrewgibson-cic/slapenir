#!/bin/bash
# OpenCode wrapper with terminal size diagnostics
# This script runs diagnostics and then starts opencode

set -e

DEBUG_LOG="/tmp/opencode-wrapper.log"

debug() {
    if [ "$OPENCODE_DEBUG" = "1" ]; then
        echo "[$(date '+%H:%M:%S')] $1" | tee -a "$DEBUG_LOG"
    fi
}

debug "=== OpenCode Wrapper Started ==="
debug ""

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
debug ""

# Start opencode
exec opencode "$@"
