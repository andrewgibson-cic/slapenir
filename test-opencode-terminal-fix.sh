#!/bin/bash
# Verification test for opencode terminal size fix
# Run this script to verify that the fix works correctly

set -e

echo "=========================================="
echo "OpenCode Terminal Size Fix Verification"
echo "=========================================="
echo ""

echo "This test will verify that OpenCode correctly detects terminal size"
echo "when started via 'make shell'"
echo ""

echo "Step 1: Check current terminal size on host"
echo "-------------------------------------------"
if command -v stty &>/dev/null && [ -t 0 ]; then
    HOST_SIZE=$(stty size 2>/dev/null || echo "0 0")
    HOST_LINES=$(echo "$HOST_SIZE" | awk '{print $1}')
    HOST_COLS=$(echo "$HOST_SIZE" | awk '{print $2}')
    echo "✓ Host terminal size: ${HOST_COLS}x${HOST_LINES}"
else
    echo "⚠ Not running in a TTY - some tests may not work"
    HOST_COLS=80
    HOST_LINES=24
fi
echo ""

echo "Step 2: Verify Makefile has -it flags"
echo "-------------------------------------------"
if grep -q "docker-compose exec -it" Makefile; then
    echo "✓ Makefile includes -it flags for TTY allocation"
else
    echo "✗ Makefile missing -it flags"
    echo "  Fix: Add '-it' to docker-compose exec command in Makefile"
    exit 1
fi
echo ""

echo "Step 3: Check environment variable handling"
echo "-------------------------------------------"
if grep -q "TERM_WIDTH" Makefile && grep -q "TERM_HEIGHT" Makefile; then
    echo "✓ Makefile sets COLUMNS and LINES explicitly"
else
    echo "⚠ Makefile may not set terminal size variables"
fi
echo ""

echo "Step 4: Compare with dev.sh approach"
echo "-------------------------------------------"
if [ -f "dev.sh" ]; then
    if grep -q "docker-compose run" dev.sh; then
        echo "✓ dev.sh uses docker-compose run (auto-allocates TTY)"
        echo "  This is the reference implementation that works correctly"
    fi
else
    echo "⚠ dev.sh not found"
fi
echo ""

echo "=========================================="
echo "Manual Test Instructions"
echo "=========================================="
echo ""
echo "Please run the following manual tests:"
echo ""
echo "1. Test with make shell:"
echo "   $ make shell"
echo "   Inside container, run:"
echo "   $ stty size"
echo "   $ echo \"COLUMNS=\$COLUMNS LINES=\$LINES\""
echo "   $ opencode"
echo "   → OpenCode should fill the entire terminal window"
echo ""
echo "2. Compare with dev.sh:"
echo "   $ ./dev.sh bash"
echo "   Inside container, run:"
echo "   $ opencode"
echo "   → Should have the same correct size as make shell"
echo ""
echo "3. Test terminal resize:"
echo "   $ make shell"
echo "   $ opencode"
echo "   → Resize your terminal window"
echo "   → OpenCode should adapt to the new size"
echo ""

echo "=========================================="
echo "Expected Behavior After Fix"
echo "=========================================="
echo ""
echo "✓ 'make shell' allocates a TTY (via -it flags)"
echo "✓ COLUMNS and LINES are set to actual terminal size"
echo "✓ stty size returns correct dimensions"
echo "✓ OpenCode fills the entire terminal window"
echo "✓ Terminal resize works correctly"
echo ""

echo "If all manual tests pass, the fix is successful!"
