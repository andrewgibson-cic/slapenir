#!/bin/bash
# Reproduction test for BUG-002: OpenCode Window Visibility on Maximize
# This test demonstrates that COLUMNS and LINES are not properly set
# when passed through the Makefile shell target

set -e

echo "=== BUG-002 Reproduction Test ==="
echo ""

# Test 1: Check host environment variables
echo "Test 1: Host Environment Variables"
echo "  COLUMNS: ${COLUMNS:-<not set>}"
echo "  LINES: ${LINES:-<not set>}"
echo "  TERM: ${TERM:-<not set>}"
echo ""

# Test 2: Get actual terminal size
echo "Test 2: Actual Terminal Size (via tput)"
ACTUAL_COLS=$(tput cols)
ACTUAL_LINES=$(tput lines)
echo "  Columns: $ACTUAL_COLS"
echo "  Lines: $ACTUAL_LINES"
echo ""

# Test 3: Check if env vars match actual size
echo "Test 3: Environment Variable Correctness"
if [ "$COLUMNS" = "$ACTUAL_COLS" ] && [ "$LINES" = "$ACTUAL_LINES" ]; then
    echo "  ✅ PASS: Environment variables match actual size"
else
    echo "  ❌ FAIL: Environment variables DO NOT match actual size"
    echo "     Expected: COLUMNS=$ACTUAL_COLS LINES=$ACTUAL_LINES"
    echo "     Got:      COLUMNS=${COLUMNS:-<empty>} LINES=${LINES:-<empty>}"
    echo ""
    echo "  This is the ROOT CAUSE of the bug!"
    echo "  When these empty/zero values are passed to the container,"
    echo "  opencode uses incorrect dimensions for rendering."
fi
echo ""

# Test 4: Simulate what docker-compose exec receives
echo "Test 4: What Container Receives (simulation)"
echo "  With current Makefile approach (-e COLUMNS -e LINES):"
echo "    COLUMNS=${COLUMNS:-<empty>}"
echo "    LINES=${LINES:-<empty>}"
echo ""
echo "  With explicit values approach (-e COLUMNS=\$(tput cols) -e LINES=\$(tput lines)):"
echo "    COLUMNS=$ACTUAL_COLS"
echo "    LINES=$ACTUAL_LINES"
echo ""

# Test 5: Verify container actually receives wrong values
echo "Test 5: Container Verification (requires running services)"
if docker-compose ps agent 2>/dev/null | grep -q "Up"; then
    CONTAINER_COLS=$(docker-compose exec -T -e COLUMNS -e LINES agent bash -c 'echo "$COLUMNS"' 2>/dev/null || echo "<error>")
    CONTAINER_LINES=$(docker-compose exec -T -e COLUMNS -e LINES agent bash -c 'echo "$LINES"' 2>/dev/null || echo "<error>")
    
    echo "  Container receives:"
    echo "    COLUMNS: $CONTAINER_COLS"
    echo "    LINES: $CONTAINER_LINES"
    
    if [ "$CONTAINER_COLS" = "$ACTUAL_COLS" ] && [ "$CONTAINER_LINES" = "$ACTUAL_LINES" ]; then
        echo "  ✅ Container has correct size"
    else
        echo "  ❌ Container has INCORRECT size - THIS IS THE BUG"
    fi
else
    echo "  ⚠ Container not running, skipping container test"
    echo "  Run 'make up' first to test container behavior"
fi

echo ""
echo "=== Reproduction Test Complete ==="
echo ""
echo "Summary:"
echo "  The bug occurs because bash does not export COLUMNS and LINES"
echo "  by default, so they are empty/zero when passed to the container."
echo ""
echo "Fix:"
echo "  Change Makefile to use explicit values:"
echo "    -e COLUMNS=\$(tput cols)"
echo "    -e LINES=\$(tput lines)"
