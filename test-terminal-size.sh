#!/bin/bash
# Test script to verify terminal size environment variables are passed correctly
# This reproduces the issue where OpenCode doesn't maximize to window size

set -e

echo "=== Testing Terminal Size Environment Variables ==="
echo ""

# Test 1: Check if environment variables are set in the container
echo "Test 1: Verifying environment variables in container..."
RESULT=$(docker-compose exec -T agent bash -c 'echo "COLUMNS=$COLUMNS"; echo "LINES=$LINES"; echo "TERM=$TERM"' 2>&1)

echo "$RESULT"
echo ""

# Test 2: Check actual terminal size vs environment variables
echo "Test 2: Comparing actual terminal size with environment variables..."
if command -v tput &>/dev/null 2>&1; then
    ACTUAL_COLS=$(tput cols)
    ACTUAL_LINES=$(tput lines)
    
    echo "Actual terminal size: ${ACTUAL_COLS}x${ACTUAL_LINES}"
    
    # Check if the container inherits the size
    CONTAINER_SIZE=$(docker-compose exec -T agent bash -c 'echo "$COLUMNS $LINES"' 2>&1)
    echo "Container reports: $CONTAINER_SIZE"
    
    if [ "$ACTUAL_COLS $ACTUAL_LINES" = "$CONTAINER_SIZE" ]; then
        echo "✅ PASS: Container inherits correct terminal size"
    else
        echo "❌ FAIL: Container does not inherit terminal size"
        echo "   Expected: ${ACTUAL_COLS}x${ACTUAL_LINES}"
        echo "   Got:      $CONTAINER_SIZE"
    fi
else
    echo "⚠ tput not available, skipping size comparison"
fi

echo ""
echo "=== Test Complete ==="
