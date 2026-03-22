#!/bin/bash
# ============================================================================
# Build Wrapper Library - Shared functions for all build tool wrappers
# ============================================================================
# Provides unified security enforcement for:
#   - npm, yarn, pnpm (Node.js)
#   - gradle, mvn (Java)
#   - pip, pip3 (Python)
#   - cargo (Rust)
#
# USAGE:
#   export TOOL_NAME="npm"
#   source /home/agent/scripts/lib/build-wrapper.sh
#   run_build_wrapper "$@"
# ============================================================================

set -euo pipefail

# Configuration
LOG_FILE="${LOG_DIR:-/var/log/slapenir}/build-control.log"
TOOL="${TOOL_NAME:-unknown}"

# ============================================================================
# Build Permission Checks
# ============================================================================

# Check if build is explicitly allowed via environment variable
# Returns 0 if allowed, 1 if blocked
is_build_allowed() {
    # Layer 1: Check global override
    if [ "${ALLOW_BUILD:-}" = "1" ]; then
        return 0
    fi
    
    # Layer 2: Check tool-specific override (e.g., GRADLE_ALLOW_BUILD=1)
    local tool_upper
    tool_upper=$(echo "$TOOL" | tr '[:lower:]' '[:upper:]')
    if [ "${tool_upper}_ALLOW_BUILD:-}" = "1" ]; then
        return 0
    fi
    
    # Layer 3: Check for interactive shell (not in OpenCode session)
    # If we're in an interactive shell outside OpenCode, allow builds
    if ! is_opencode_active 2>/dev/null; then
        # Additional check: are we in a real interactive terminal?
        if [ -t 0 ] && [ -z "${OPENCODE_SESSION_ID:-}" ]; then
            return 0
        fi
    fi
    
    # Default: Block all builds
    return 1
}

# ============================================================================
# Logging Functions
# ============================================================================

# Log build attempt to audit log
log_build_attempt() {
    local action="$1"   # ALLOWED or BLOCKED
    local reason="$2"   # Explanation
    
    # Ensure log directory exists
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    
    # Format: [timestamp] [TOOL] ACTION - reason - args
    local timestamp
    timestamp=$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S%z')
    local args="${*:-}"
    
    echo "[$timestamp] [$TOOL] $action - $reason - args: $args" >> "$LOG_FILE" 2>/dev/null || true
}

# ============================================================================
# Tool Execution
# ============================================================================

# Execute the real tool (after passing security checks)
execute_real_tool() {
    local real_tool="${TOOL}.real"
    
    # Find real tool
    if command -v "$real_tool" >/dev/null 2>&1; then
        exec "$real_tool" "$@"
    else
        # Try alternative locations
        local alt_path="/usr/bin/${real_tool}"
        if [ -x "$alt_path" ]; then
            exec "$alt_path" "$@"
        fi
        
        echo "ERROR: Real tool not found: $real_tool" >&2
        echo "       This indicates a wrapper installation problem." >&2
        exit 127
    fi
}

# ============================================================================
# Main Wrapper Logic
# ============================================================================

# Main entry point for build wrappers
# Call this after setting TOOL_NAME and sourcing this file
run_build_wrapper() {
    # Check if build is allowed
    if is_build_allowed; then
        local reason="Override enabled"
        [ -n "${ALLOW_BUILD:-}" ] && reason="ALLOW_BUILD=1"
        
        local tool_upper
        tool_upper=$(echo "$TOOL" | tr '[:lower:]' '[:upper:]')
        [ "${tool_upper}_ALLOW_BUILD:-}" = "1" ] && reason="${tool_upper}_ALLOW_BUILD=1"
        
        # Check if not in OpenCode
        if ! is_opencode_active 2>/dev/null && [ -t 0 ]; then
            reason="Interactive shell (OpenCode not active)"
        fi
        
        log_build_attempt "ALLOWED" "$reason" "$*"
        execute_real_tool "$@"
    fi
    
    # Build is blocked
    log_build_attempt "BLOCKED" "No override, OpenCode active" "$*"
    show_build_blocked_message "$TOOL"
    exit 1
}

# ============================================================================
# User Messages
# ============================================================================

# Display blocked message with instructions
show_build_blocked_message() {
    local tool="$1"
    local tool_upper
    tool_upper=$(echo "$tool" | tr '[:lower:]' '[:upper:]')
    
    cat >&2 << HEREDOC
╔══════════════════════════════════════════════════════════════╗
║  BUILD TOOL BLOCKED: $tool
║                                                              
║  All builds are blocked by default for security:             ║
║  - Prevent arbitrary code execution                          ║
║  - Prevent supply chain attacks                              ║
║  - Ensure dependency audit trail                             ║
║                                                              
║  TO RUN BUILDS:                                              ║
║                                                              
║  Method 1: Environment variable override                     ║
║    ALLOW_BUILD=1 $tool <args>
║    ${tool_upper}_ALLOW_BUILD=1 $tool <args>
║                                                              
║  Method 2: Interactive shell (recommended)                   ║
║    1. Exit OpenCode (Ctrl+D or type 'exit')                  ║
║    2. Start shell: make shell                                ║
║    3. Run: $tool <args>
║                                                              
║  LOGS: $LOG_FILE
║                                                              
╚══════════════════════════════════════════════════════════════╝
HEREDOC
}

# ============================================================================
# Helper Functions
# ============================================================================

# Check if we're in an OpenCode session
# Sources detection.sh if available
is_opencode_active() {
    # Try to source detection library
    local detection_lib="/home/agent/scripts/lib/detection.sh"
    if [ -f "$detection_lib" ]; then
        source "$detection_lib"
        is_opencode_active
        return $?
    fi
    
    # Fallback: check environment variables only
    [ -n "${OPENCODE_SESSION_ID:-}" ] && return 0
    [ -n "${OPENCODE_YOLO:-}" ] && return 0
    [ -n "${OPENCODE_CONFIG_PATH:-}" ] && return 0
    
    return 1
}

# Get current OpenCode session ID
get_opencode_session() {
    local lock_file="/tmp/opencode-session.lock"
    
    if [ -f "$lock_file" ]; then
        grep "^session_id=" "$lock_file" 2>/dev/null | cut -d= -f2 || echo "unknown"
    else
        echo "none"
    fi
}

# Validate proxy is accessible before running build
validate_proxy_connection() {
    local proxy_host="${HTTP_PROXY:-http://proxy:3000}"
    
    # Extract host:port from proxy URL
    local host_port
    host_port=$(echo "$proxy_host" | sed 's|http://||' | sed 's|/.*||')
    
    if command -v nc >/dev/null 2>&1; then
        if ! nc -z -w5 ${host_port%:*} ${host_port#*:} 2>/dev/null; then
            echo "WARNING: Cannot reach proxy at $host_port" >&2
            echo "         Builds may fail due to network isolation." >&2
            return 1
        fi
    fi
    
    return 0
}
