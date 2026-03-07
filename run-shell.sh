#!/bin/bash
# Shell entry point with proper terminal size detection
# This script should be called from the Makefile

# Detect terminal size using multiple methods
detect_terminal_size() {
    local width height
    
    # Method 1: stty (most reliable when TTY is available)
    if [ -t 0 ]; then
        local size=$(stty size 2>/dev/null)
        if [ -n "$size" ]; then
            height=$(echo "$size" | awk '{print $1}')
            width=$(echo "$size" | awk '{print $2}')
            if [ -n "$width" ] && [ -n "$height" ] && [ "$width" -gt 0 ] 2>/dev/null && [ "$height" -gt 0 ] 2>/dev/null; then
                echo "$width $height"
                return 0
            fi
        fi
    fi
    
    # Method 2: tput
    width=$(tput cols 2>/dev/null)
    height=$(tput lines 2>/dev/null)
    if [ -n "$width" ] && [ -n "$height" ] && [ "$width" != "0" ] && [ "$height" != "0" ]; then
        echo "$width $height"
        return 0
    fi
    
    # Method 3: Environment variables (if already set)
    if [ -n "$COLUMNS" ] && [ -n "$LINES" ]; then
        echo "$COLUMNS $LINES"
        return 0
    fi
    
    # Fallback
    echo "80 24"
}

# Main execution
echo "=========================================="
echo "Terminal Size Detection"
echo "=========================================="

SIZE=$(detect_terminal_size)
WIDTH=$(echo "$SIZE" | awk '{print $1}')
HEIGHT=$(echo "$SIZE" | awk '{print $2}')

echo "Detected terminal size: ${WIDTH}x${HEIGHT}"
echo ""

# Export for use by docker-compose
export TERM_WIDTH="$WIDTH"
export TERM_HEIGHT="$HEIGHT"

echo "Environment prepared:"
echo "  TERM_WIDTH=$TERM_WIDTH"
echo "  TERM_HEIGHT=$TERM_HEIGHT"
echo ""

# Execute docker-compose with detected size
exec docker-compose exec \
    -u agent \
    -e COLUMNS="$WIDTH" \
    -e LINES="$HEIGHT" \
    -e TERM \
    -e TRAFFIC_ENFORCEMENT_ENABLED=false \
    -e GRADLE_ALLOW_FROM_OPENCODE=1 \
    -e MVN_ALLOW_FROM_OPENCODE=1 \
    -e NPM_ALLOW_FROM_OPENCODE=1 \
    -e YARN_ALLOW_FROM_OPENCODE=1 \
    -e PNPM_ALLOW_FROM_OPENCODE=1 \
    -e CARGO_ALLOW_FROM_OPENCODE=1 \
    -e PIP_ALLOW_FROM_OPENCODE=1 \
    -e PIP3_ALLOW_FROM_OPENCODE=1 \
    agent /bin/bash -c "echo 'Container terminal size:'; stty size 2>/dev/null || echo 'stty failed'; echo 'Environment: COLUMNS=\$COLUMNS LINES=\$LINES'; echo ''; stty cols $WIDTH rows $HEIGHT 2>/dev/null; exec bash"
