#!/bin/bash
# ============================================================================
# OpenCode Detection Library
# ============================================================================
# Shared detection functions for build tool wrappers
# Used by: gradle-wrapper, mvn-wrapper, npm-wrapper, etc.
# ============================================================================

set -euo pipefail

# ============================================================================
# SPEC-001: Process Tree Detection
# ============================================================================

is_opencode_in_process_tree() {
    # Traverse process tree up to 20 levels deep
    local pid=$$ depth=0
    
    while [ $depth -lt 20 ] && [ "$pid" -gt 1 ]; do
        # Get process command line
        local cmdline=""
        
        # Try /proc filesystem first (Linux)
        if [ -r "/proc/$pid/cmdline" ]; then
            cmdline=$(cat "/proc/$pid/cmdline" 2>/dev/null | tr '\0' ' ')
        # Fallback to ps command
        elif command -v ps >/dev/null 2>&1; then
            cmdline=$(ps -o args= -p $pid 2>/dev/null || echo "")
        fi
        
        # Check for opencode process (but not our own detection script)
        # Match patterns like:
        # - "opencode" (the CLI itself)
        # - "node /path/to/opencode" (Node.js running OpenCode)
        # - "/usr/local/bin/opencode" (full path)
        # But NOT:
        # - "is_opencode_in_process_tree" (our detection function)
        # - "opencode-wrapper" (our wrapper scripts)
        if [[ "$cmdline" == *opencode* ]] && \
           [[ "$cmdline" != *is_opencode* ]] && \
           [[ "$cmdline" != *opencode-wrapper* ]] && \
           [[ "$cmdline" != *detection.sh* ]]; then
            return 0  # Found
        fi
        
        # Get parent PID
        local ppid=""
        if [ -r "/proc/$pid/status" ]; then
            ppid=$(grep -E "^PPid:" "/proc/$pid/status" 2>/dev/null | awk '{print $2}' || echo "")
        elif command -v ps >/dev/null 2>&1; then
            ppid=$(ps -o ppid= -p $pid 2>/dev/null | tr -d ' ')
        fi
        
        # Validate parent PID
        if [ -z "$ppid" ] || [ "$ppid" -eq "$pid" ]; then
            break  # No parent or circular reference
        fi
        
        pid=$ppid
        depth=$((depth + 1))
    done
    
    return 1  # Not found
}

# ============================================================================
# SPEC-002: Environment Variable Detection
# ============================================================================

has_opencode_env_vars() {
    # Check for OpenCode-specific environment variables
    [ -n "${OPENCODE_SESSION_ID:-}" ] && return 0
    [ -n "${OPENCODE_YOLO:-}" ] && return 0
    [ -n "${OPENCODE_CONFIG_PATH:-}" ] && return 0
    
    return 1  # No OpenCode env vars found
}

# ============================================================================
# SPEC-003: Multi-Layer Detection
# ============================================================================

is_opencode_active() {
    local lock_file="/tmp/opencode-session.lock"
    
    # Layer 1: Check lock file (fastest, most reliable)
    if [ -f "$lock_file" ]; then
        # Verify lock file is recent (not stale)
        if [ -r "$lock_file" ]; then
            local lock_time=0
            local current_time=$(date +%s)
            
            # Get lock file modification time
            if command -v stat >/dev/null 2>&1; then
                # Linux stat with -c %Y
                lock_time=$(stat -c %Y "$lock_file" 2>/dev/null || echo 0)
            elif command -v stat >/dev/null 2>&1; then
                # macOS/BSD stat with -f %m
                lock_time=$(stat -f %m "$lock_file" 2>/dev/null || echo 0)
            fi
            
            # Calculate age (less than 24 hours = 86400 seconds)
            local lock_age=$(( current_time - lock_time ))
            if [ $lock_age -lt 86400 ]; then
                return 0  # Fresh lock file found
            fi
        fi
    fi
    
    # Layer 2: Check environment variables
    if has_opencode_env_vars; then
        return 0
    fi
    
    # Layer 3: Check process tree
    if is_opencode_in_process_tree; then
        return 0
    fi
    
    return 1  # No OpenCode detected
}

# ============================================================================
# Helper Functions
# ============================================================================

log_execution() {
    local tool=$1
    local action=$2
    local reason=$3
    local log_file="${LOG_DIR:-/var/log/slapenir}/execution-control.log"
    
    # Ensure log directory exists (may fail if no permissions)
    mkdir -p "$(dirname "$log_file")" 2>/dev/null || true
    
    # Log execution attempt (fail silently if no permissions)
    echo "[$(date -Iseconds)] [$tool] $action - $reason" >> "$log_file" 2>/dev/null || true
}

get_opencode_session() {
    local lock_file="/tmp/opencode-session.lock"
    
    if [ -f "$lock_file" ]; then
        # Extract session ID from lock file
        grep "^session_id=" "$lock_file" 2>/dev/null | cut -d= -f2 || echo "unknown"
    else
        echo "unknown"
    fi
}

show_block_message() {
    local tool=$1
    local override_var=$(echo "$tool" | tr '[:lower:]' '[:upper:]')_ALLOW_FROM_OPENCODE
    
    cat >&2 << 'HEREDOC'
╔══════════════════════════════════════════════════════════════╗
HEREDOC
    echo "║  BUILD TOOL BLOCKED: $tool" >&2
    cat >&2 << 'HEREDOC'
║                                                              
║  OpenCode detected in process tree or environment.           ║
║  Build tools are blocked for security reasons:               ║
║  - Prevent arbitrary code execution                          ║
║  - Prevent supply chain attacks                              ║  
║  - Prevent data exfiltration                                 ║
║                                                              
║  TO RUN BUILDS:                                              ║
HEREDOC
    echo "║  1. Exit OpenCode (Ctrl+D or 'exit')" >&2
    echo "║  2. Run: $tool <args>" >&2
    cat >&2 << 'HEREDOC'
║                                                              
║  EMERGENCY OVERRIDE (discouraged):                           ║
HEREDOC
    echo "║  $override_var=1 $tool <args>" >&2
    cat >&2 << 'HEREDOC'
╚══════════════════════════════════════════════════════════════╝
HEREDOC
}
