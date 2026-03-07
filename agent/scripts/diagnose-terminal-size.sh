#!/bin/bash
# Comprehensive diagnostic script for opencode terminal size detection
# This script runs multiple tests to identify the root cause of size mismatch

set -e

echo "=========================================="
echo "OpenCode Terminal Size Diagnostic"
echo "=========================================="
echo ""

# Test 1: Check if we're in a TTY
echo "[TEST 1] TTY Detection"
echo "-------------------------------------------"
if [ -t 0 ]; then
    echo "✅ stdin is a TTY"
else
    echo "❌ stdin is NOT a TTY"
fi

if [ -t 1 ]; then
    echo "✅ stdout is a TTY"
else
    echo "❌ stdout is NOT a TTY"
fi

if [ -t 2 ]; then
    echo "✅ stderr is a TTY"
else
    echo "❌ stderr is NOT a TTY"
fi
echo ""

# Test 2: Environment Variables
echo "[TEST 2] Environment Variables"
echo "-------------------------------------------"
echo "COLUMNS: ${COLUMNS:-<not set>}"
echo "LINES: ${LINES:-<not set>}"
echo "TERM: ${TERM:-<not set>}"
echo "TERMINFO: ${TERMINFO:-<not set>}"
echo ""

# Test 3: tput commands
echo "[TEST 3] tput Commands"
echo "-------------------------------------------"
if command -v tput &>/dev/null; then
    echo "tput cols: $(tput cols 2>&1 || echo '<error>')"
    echo "tput lines: $(tput lines 2>&1 || echo '<error>')"
    echo "tput longname: $(tput longname 2>&1 || echo '<error>')"
else
    echo "❌ tput not found"
fi
echo ""

# Test 4: stty command
echo "[TEST 4] stty Command"
echo "-------------------------------------------"
if command -v stty &>/dev/null; then
    if stty size 2>/dev/null; then
        echo "✅ stty size available"
    else
        echo "❌ stty size failed (no TTY?)"
    fi
else
    echo "❌ stty not found"
fi
echo ""

# Test 5: Check $LINES and $COLUMNS in shell
echo "[TEST 5] Shell Variables (Bash)"
echo "-------------------------------------------"
bash -c 'echo "Bash COLUMNS: ${COLUMNS:-<not set>}"; echo "Bash LINES: ${LINES:-<not set>}"'
echo ""

# Test 6: Check if variables are exported
echo "[TEST 6] Export Status"
echo "-------------------------------------------"
if [ -n "$COLUMNS" ]; then
    if export -p | grep -q "COLUMNS="; then
        echo "✅ COLUMNS is exported"
    else
        echo "❌ COLUMNS is set but NOT exported"
    fi
else
    echo "❌ COLUMNS is not set"
fi

if [ -n "$LINES" ]; then
    if export -p | grep -q "LINES="; then
        echo "✅ LINES is exported"
    else
        echo "❌ LINES is set but NOT exported"
    fi
else
    echo "❌ LINES is not set"
fi
echo ""

# Test 7: Check actual terminal device
echo "[TEST 7] Terminal Device"
echo "-------------------------------------------"
TTY_DEVICE=$(tty 2>/dev/null || echo "<not a tty>")
echo "TTY device: $TTY_DEVICE"

if [ "$TTY_DEVICE" != "<not a tty>" ]; then
    TTY_MAJOR=$(stat -c %t "$TTY_DEVICE" 2>/dev/null || echo "N/A")
    echo "TTY major device number: $TTY_MAJOR"
fi
echo ""

# Test 8: Test inside Docker context
echo "[TEST 8] Docker Context"
echo "-------------------------------------------"
if [ -f /.dockerenv ]; then
    echo "✅ Running inside Docker container"
    
    # Check if we have a PTY allocated
    if [ -n "$SSH_TTY" ]; then
        echo "SSH_TTY: $SSH_TTY"
    else
        echo "No SSH_TTY set"
    fi
    
    # Check docker-specific environment
    echo "HOSTNAME: ${HOSTNAME:-<not set>}"
else
    echo "❌ Not running inside Docker"
fi
echo ""

# Test 9: Check TERM capabilities
echo "[TEST 9] TERM Capabilities"
echo "-------------------------------------------"
if [ -n "$TERM" ]; then
    echo "TERM: $TERM"
    if command -v infocmp &>/dev/null; then
        if infocmp "$TERM" &>/dev/null; then
            echo "✅ TERM definition found"
        else
            echo "❌ TERM definition NOT found"
        fi
    fi
else
    echo "❌ TERM not set"
fi
echo ""

# Test 10: Test with script command (PTY allocation)
echo "[TEST 10] PTY Allocation Test"
echo "-------------------------------------------"
if command -v script &>/dev/null; then
    echo "Testing with script (allocates PTY)..."
    SCRIPT_OUTPUT=$(script -q /dev/null bash -c 'echo "SCRIPT_COLS=$(tput cols)"; echo "SCRIPT_LINES=$(tput lines)"' 2>/dev/null || echo "script failed")
    echo "$SCRIPT_OUTPUT"
else
    echo "script command not available"
fi
echo ""

# Test 11: Compare sizes from different methods
echo "[TEST 11] Size Comparison"
echo "-------------------------------------------"
echo "Method                    | Cols | Lines"
echo "--------------------------|------|------"
printf "Environment variables     | %-4s | %-4s\n" "${COLUMNS:-N/A}" "${LINES:-N/A}"
printf "tput                      | %-4s | %-4s\n" "$(tput cols 2>/dev/null || echo 'FAIL')" "$(tput lines 2>/dev/null || echo 'FAIL')"
printf "stty size                 | %-4s | %-4s\n" "$(stty size 2>/dev/null | awk '{print $2}' || echo 'FAIL')" "$(stty size 2>/dev/null | awk '{print $1}' || echo 'FAIL')"
echo ""

# Test 12: Check for SIGWINCH handling
echo "[TEST 12] Signal Handling"
echo "-------------------------------------------"
echo "Testing SIGWINCH (window resize signal)..."
echo "Current size: $(tput cols)x$(tput lines)"
echo ""
echo "To test dynamic resize:"
echo "1. Resize your terminal window"
echo "2. Run: kill -SIGWINCH \$\$"
echo "3. Check if size updates: tput cols && tput lines"
echo ""

# Summary
echo "=========================================="
echo "DIAGNOSTIC SUMMARY"
echo "=========================================="
echo ""
echo "Key Findings:"
echo ""

if [ ! -t 0 ]; then
    echo "⚠️  PROBLEM: stdin is not a TTY"
    echo "   This means terminal size cannot be detected properly"
    echo "   Solution: Use 'docker exec -it' or 'docker-compose exec'"
    echo ""
fi

if [ -z "$COLUMNS" ] || [ -z "$LINES" ]; then
    echo "⚠️  PROBLEM: COLUMNS and/or LINES not set"
    echo "   opencode may use fallback size (80x24)"
    echo "   Solution: Set explicitly or use shell that exports them"
    echo ""
fi

TPUT_COLS=$(tput cols 2>/dev/null || echo "0")
TPUT_LINES=$(tput lines 2>/dev/null || echo "0")

if [ "$TPUT_COLS" = "0" ] || [ "$TPUT_LINES" = "0" ]; then
    echo "⚠️  PROBLEM: tput returns 0 or fails"
    echo "   Terminal size cannot be queried"
    echo "   Check TERM and TERMINFO settings"
    echo ""
fi

if [ "$TPUT_COLS" = "80" ] && [ "$TPUT_LINES" = "24" ]; then
    echo "⚠️  WARNING: tput returns default 80x24"
    echo "   This may indicate:"
    echo "   - No TTY allocated"
    echo "   - TERM database missing"
    echo "   - Running in non-interactive context"
    echo ""
fi

echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo ""
echo "1. If inside Docker, ensure using -it flags"
echo "2. Check if opencode has specific terminal size config"
echo "3. Try setting COLUMNS and LINES explicitly before opencode"
echo "4. Check opencode documentation for terminal requirements"
echo ""
