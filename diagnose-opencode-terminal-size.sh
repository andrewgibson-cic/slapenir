#!/bin/bash
# Comprehensive diagnostic script for opencode terminal size issues
# Run this inside the container to identify the root cause

set -e

echo "=========================================="
echo "OpenCode Terminal Size Diagnostic"
echo "=========================================="
echo ""

# 1. Check environment variables
echo "[1] Environment Variables"
echo "COLUMNS: ${COLUMNS:-<not set>}"
echo "LINES: ${LINES:-<not set>}"
echo "TERM: ${TERM:-<not set>}"
echo "TERMINFO: ${TERMINFO:-<not set>}"
echo "DISPLAY: ${DISPLAY:-<not set>}"
echo ""

# 2. Check terminal type
echo "[2] Terminal Type"
if [ -t 0 ]; then
    echo "stdin: TTY ($(tty 2>/dev/null || echo 'unknown'))"
else
    echo "stdin: NOT a TTY"
fi

if [ -t 1 ]; then
    echo "stdout: TTY"
else
    echo "stdout: NOT a TTY"
fi
echo ""

# 3. Check stty
echo "[3] stty Commands"
if command -v stty >/dev/null 2>&1; then
    echo "stty size: $(stty size 2>/dev/null || echo 'FAILED')"
    echo "stty -a:"
    stty -a 2>/dev/null || echo "  FAILED"
else
    echo "stty: NOT AVAILABLE"
fi
echo ""

# 4. Check tput
echo "[4] tput Commands"
if command -v tput >/dev/null 2>&1; then
    echo "tput cols: $(tput cols 2>/dev/null || echo 'FAILED')"
    echo "tput lines: $(tput lines 2>/dev/null || echo 'FAILED')"
    echo "tput longname: $(tput longname 2>/dev/null || echo 'FAILED')"
else
    echo "tput: NOT AVAILABLE"
fi
echo ""

# 5. Check resize (command)
echo "[5] resize Command"
if command -v resize >/dev/null 2>&1; then
    echo "resize: $(resize 2>/dev/null || echo 'FAILED')"
else
    echo "resize: NOT AVAILABLE"
fi
echo ""

# 6. Check if variables are exported
echo "[6] Export Status"
if [ -n "$COLUMNS" ]; then
    if export -p | grep -q "declare -x COLUMNS="; then
        echo "COLUMNS: EXPORTED"
    else
        echo "COLUMNS: SET but NOT EXPORTED"
    fi
else
    echo "COLUMNS: NOT SET"
fi

if [ -n "$LINES" ]; then
    if export -p | grep -q "declare -x LINES="; then
        echo "LINES: EXPORTED"
    else
        echo "LINES: SET but NOT EXPORTED"
    fi
else
    echo "LINES: NOT SET"
fi
echo ""

# 7. Test if shell updates COLUMNS/LINES
echo "[7] Shell Variable Updates"
echo "Testing if bash updates COLUMNS/LINES on window resize..."
echo "Run this in your terminal:"
echo "  bash -c 'trap \"export COLUMNS LINES\" SIGWINCH; sleep 1'"
echo "Then resize your terminal and check if variables update"
echo ""

# 8. Check opencode configuration
echo "[8] OpenCode Configuration"
if [ -f "$OPENCODE_CONFIG_PATH" ]; then
    echo "Config file: $OPENCODE_CONFIG_PATH"
    echo "Contents:"
    cat "$OPENCODE_CONFIG_PATH" | head -20
else
    echo "Config file: NOT FOUND"
    echo "OPENCODE_CONFIG_PATH: ${OPENCODE_CONFIG_PATH:-<not set>}"
fi
echo ""

# 9. Check if opencode is installed
echo "[9] OpenCode Installation"
if command -v opencode >/dev/null 2>&1; then
    echo "opencode: $(which opencode)"
    echo "Version: $(opencode --version 2>/dev/null || echo 'unknown')"
else
    echo "opencode: NOT INSTALLED"
fi
echo ""

# 10. Try running opencode with debug
echo "[10] OpenCode Debug Mode"
echo "Try running opencode with debug logging:"
echo "  OPENCODE_DEBUG=1 opencode"
echo ""
echo "This will show what opencode sees for terminal size"
echo ""

# Summary
echo "=========================================="
echo "SUMMARY"
echo "=========================================="
echo ""

if [ ! -t 0 ]; then
    echo "❌ CRITICAL: stdin is not a TTY"
    echo "   This is the main issue - opencode cannot detect terminal size"
    echo "   Solution: Run 'make shell' which allocates a PTY"
    echo ""
fi

if [ -z "$COLUMNS" ] || [ -z "$LINES" ]; then
    echo "❌ CRITICAL: COLUMNS and/or LINES not set"
    echo "   opencode may use fallback size or fail to render properly"
    echo "   Solution: Export COLUMNS and LINES before running opencode"
    echo ""
fi

TPUT_COLS=$(tput cols 2>/dev/null || echo "0")
TPUT_LINES=$(tput lines 2>/dev/null || echo "0")

if [ "$TPUT_COLS" = "0" ] || [ "$TPUT_LINES" = "0" ]; then
    echo "❌ CRITICAL: tput cannot detect terminal size"
    echo "   This suggests TERM is not set correctly or terminfo is missing"
    echo "   Solution: Check TERM and TERMINFO settings"
    echo ""
fi

if [ "$TPUT_COLS" = "80" ] && [ "$TPUT_LINES" = "24" ]; then
    echo "⚠️  WARNING: tput returns default 80x24"
    echo "   If your terminal is actually larger, this is the problem"
    echo "   opencode will use this size even though terminal is larger"
    echo ""
fi

echo "=========================================="
echo "NEXT STEPS"
echo "=========================================="
echo ""
echo "1. If stdin is not a TTY, you MUST use 'make shell'"
echo "2. Check if COLUMNS/LINES are set correctly"
echo "3. Run opencode with debug: OPENCODE_DEBUG=1 opencode"
echo "4. Try setting terminal size explicitly:"
echo "   export COLUMNS=\$(tput cols)"
echo "   export LINES=\$(tput lines)"
echo "   opencode"
echo ""
