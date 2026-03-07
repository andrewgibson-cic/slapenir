#!/bin/bash
# Startup diagnostics for OpenCode terminal size
# Run this script inside the container before starting opencode

set -e

LOG_FILE="/tmp/opencode-terminal-debug.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=========================================="
log "OpenCode Terminal Size Startup Check"
log "=========================================="
log ""

# Check environment
log "Environment:"
log "  COLUMNS=${COLUMNS:-<not set>}"
log "  LINES=${LINES:-<not set>}"
log "  TERM=${TERM:-<not set>}"
log "  TERMINFO=${TERMINFO:-<not set>}"
log ""

# Check TTY
log "TTY Status:"
if [ -t 0 ]; then
    log "  stdin: TTY ($(tty 2>/dev/null || echo 'unknown'))"
else
    log "  stdin: NOT TTY (piped/redirected)"
fi

if [ -t 1 ]; then
    log "  stdout: TTY"
else
    log "  stdout: NOT TTY"
fi
log ""

# Check terminal size
log "Terminal Size Detection:"
log "  tput cols: $(tput cols 2>/dev/null || echo 'FAILED')"
log "  tput lines: $(tput lines 2>/dev/null || echo 'FAILED')"

if command -v stty &>/dev/null && [ -t 0 ]; then
    STTY_SIZE=$(stty size 2>/dev/null || echo "0 0")
    log "  stty size: $STTY_SIZE"
else
    log "  stty size: FAILED (no TTY or stty not available)"
fi
log ""

# Validation
TPUT_COLS=$(tput cols 2>/dev/null || echo "0")
TPUT_LINES=$(tput lines 2>/dev/null || echo "0")

log "Validation:"

if [ "$TPUT_COLS" = "0" ] || [ "$TPUT_LINES" = "0" ]; then
    log "  ❌ CRITICAL: Cannot detect terminal size"
    log "  This will cause opencode to use fallback size"
    exit 1
fi

if [ "$TPUT_COLS" = "80" ] && [ "$TPUT_LINES" = "24" ]; then
    log "  ⚠️  WARNING: Using default size 80x24"
    log "  If your terminal is larger, opencode won't fill it"
    log ""
    log "  Attempting to fix..."
    
    # Try to get actual size from stty
    if command -v stty &>/dev/null && [ -t 0 ]; then
        STTY_SIZE=$(stty size 2>/dev/null || echo "")
        if [ -n "$STTY_SIZE" ]; then
            ACTUAL_LINES=$(echo "$STTY_SIZE" | awk '{print $1}')
            ACTUAL_COLS=$(echo "$STTY_SIZE" | awk '{print $2}')
            
            if [ "$ACTUAL_COLS" != "80" ] && [ "$ACTUAL_LINES" != "24" ]; then
                log "  Found actual size via stty: ${ACTUAL_COLS}x${ACTUAL_LINES}"
                log "  Setting COLUMNS=$ACTUAL_COLS LINES=$ACTUAL_LINES"
                export COLUMNS="$ACTUAL_COLS"
                export LINES="$ACTUAL_LINES"
                log "  ✅ Environment updated"
            else
                log "  stty also reports 80x24, terminal may actually be that size"
            fi
        fi
    fi
else
    log "  ✅ Terminal size detected: ${TPUT_COLS}x${TPUT_LINES}"
    
    # Sync environment variables
    if [ "$COLUMNS" != "$TPUT_COLS" ] || [ "$LINES" != "$TPUT_LINES" ]; then
        log "  Updating environment variables..."
        export COLUMNS="$TPUT_COLS"
        export LINES="$TPUT_LINES"
        log "  ✅ COLUMNS=$COLUMNS LINES=$LINES"
    fi
fi

log ""
log "=========================================="
log "Ready to start opencode"
log "=========================================="
log ""

exit 0
