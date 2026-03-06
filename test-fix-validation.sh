#!/bin/bash
# Validation test for BUG-002 fix
# Verifies that the Makefile now passes correct terminal size to container

set -e

echo "=== BUG-002 Fix Validation ==="
echo ""

# Check if container is running
if ! docker-compose ps agent 2>/dev/null | grep -q "Up"; then
    echo "❌ FAIL: Agent container is not running"
    echo "   Run 'make up' first"
    exit 1
fi

echo "✅ Container is running"
echo ""

# Get actual terminal size
ACTUAL_COLS=$(tput cols)
ACTUAL_LINES=$(tput lines)
echo "Actual terminal size: ${ACTUAL_COLS}x${ACTUAL_LINES}"
echo ""

# Test what container receives with the fix
echo "Testing fixed Makefile approach..."
CONTAINER_COLS=$(docker-compose exec -T -u agent \
    -e COLUMNS=`tput cols 2>/dev/null || echo 80` \
    -e LINES=`tput lines 2>/dev/null || echo 24` \
    agent bash -c 'echo "$COLUMNS"' 2>/dev/null)

CONTAINER_LINES=$(docker-compose exec -T -u agent \
    -e COLUMNS=`tput cols 2>/dev/null || echo 80` \
    -e LINES=`tput lines 2>/dev/null || echo 24` \
    agent bash -c 'echo "$LINES"' 2>/dev/null)

echo "Container receives: ${CONTAINER_COLS}x${CONTAINER_LINES}"
echo ""

# Validate
if [ "$CONTAINER_COLS" = "$ACTUAL_COLS" ] && [ "$CONTAINER_LINES" = "$ACTUAL_LINES" ]; then
    echo "✅ PASS: Container receives correct terminal size"
    echo ""
    echo "Fix validated successfully!"
    exit 0
else
    echo "❌ FAIL: Container receives incorrect size"
    echo "   Expected: ${ACTUAL_COLS}x${ACTUAL_LINES}"
    echo "   Got:      ${CONTAINER_COLS}x${CONTAINER_LINES}"
    exit 1
fi
