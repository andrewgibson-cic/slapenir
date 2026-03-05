#!/bin/bash
# Mock OpenCode session for testing
# Source this file to simulate an active OpenCode session

setup_mock_opencode() {
    export OPENCODE_SESSION_ID="test-session-$(date +%s)"
    export OPENCODE_YOLO="true"
    export OPENCODE_CONFIG_PATH="/home/agent/.config/opencode/opencode.json"
    
    # Create lock file
    cat > /tmp/opencode-session.lock <<EOF
session_id=$OPENCODE_SESSION_ID
pid=$$
started=$(date -Iseconds)
command=opencode test
working_directory=$(pwd)
EOF
}

cleanup_mock_opencode() {
    unset OPENCODE_SESSION_ID
    unset OPENCODE_YOLO
    unset OPENCODE_CONFIG_PATH
    rm -f /tmp/opencode-session.lock
}

# Create fresh lock file with current timestamp
create_fresh_lock() {
    cat > /tmp/opencode-session.lock <<EOF
session_id=fresh-session-$(date +%s)
pid=$$
started=$(date -Iseconds)
command=opencode fresh
working_directory=$(pwd)
EOF
}

# Create stale lock file (>24 hours old)
create_stale_lock() {
    cat > /tmp/opencode-session.lock <<EOF
session_id=stale-session
pid=99999
started=2026-03-03T00:00:00+00:00
command=opencode stale
working_directory=/old/path
EOF
    
    # Make lock file old (macOS/BSD compatible)
    touch -t 202603030000 /tmp/opencode-session.lock
}

# Remove lock file
remove_lock() {
    rm -f /tmp/opencode-session.lock
}
