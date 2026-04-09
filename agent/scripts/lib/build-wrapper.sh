#!/bin/bash
# Build Wrapper Library - Shared functions for all build tool wrappers
# When ALLOW_BUILD=1: passes security check, enables network via netctl, runs tool, disables network

set -euo pipefail

LOG_FILE="${LOG_DIR:-/var/log/slapenir}/build-control.log"
TOOL="${TOOL_NAME:-unknown}"

is_build_allowed() {
    if [ "${ALLOW_BUILD:-}" = "1" ]; then
        return 0
    fi

    local tool_upper
    tool_upper=$(echo "$TOOL" | tr '[:lower:]' '[:upper:]')
    if [ "${tool_upper}_ALLOW_BUILD:-}" = "1" ]; then
        return 0
    fi

    if ! is_opencode_active 2>/dev/null; then
        if [ -t 0 ] && [ -z "${OPENCODE_SESSION_ID:-}" ]; then
            return 0
        fi
    fi

    return 1
}

log_build_attempt() {
    local action="$1"
    local reason="$2"

    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

    local timestamp
    timestamp=$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S%z')

    echo "[$timestamp] [$TOOL] $action - $reason - args: ${*:3}" >> "$LOG_FILE" 2>/dev/null || true
}

_find_real_tool() {
    local real_tool="${TOOL}.real"

    if command -v "$real_tool" >/dev/null 2>&1; then
        echo "$real_tool"
        return 0
    fi

    local alt_path="/usr/bin/${real_tool}"
    if [ -x "$alt_path" ]; then
        echo "$alt_path"
        return 0
    fi

    return 1
}

run_build_wrapper() {
    if ! is_build_allowed; then
        log_build_attempt "BLOCKED" "No override, OpenCode active" "$*"
        show_build_blocked_message "$TOOL"
        exit 1
    fi

    local reason="Override enabled"
    [ -n "${ALLOW_BUILD:-}" ] && reason="ALLOW_BUILD=1"

    local tool_upper
    tool_upper=$(echo "$TOOL" | tr '[:lower:]' '[:upper:]')
    [ "${tool_upper}_ALLOW_BUILD:-}" = "1" ] && reason="${tool_upper}_ALLOW_BUILD=1"

    if ! is_opencode_active 2>/dev/null && [ -t 0 ]; then
        reason="Interactive shell (OpenCode not active)"
    fi

    log_build_attempt "ALLOWED" "$reason" "$*"

    local tool_path
    if ! tool_path=$(_find_real_tool); then
        echo "ERROR: Real tool not found: ${TOOL}.real" >&2
        echo "       This indicates a wrapper installation problem." >&2
        exit 127
    fi

    local needs_network=false
    if [ "${ALLOW_BUILD:-}" = "1" ] || [ "${tool_upper}_ALLOW_BUILD:-}" = "1" ]; then
        needs_network=true
    fi

    if $needs_network; then
        _enable_network_if_needed
        HTTP_PROXY="http://${BUILD_PROXY_HOST:-proxy}:${BUILD_PROXY_PORT:-3000}" \
        HTTPS_PROXY="http://${BUILD_PROXY_HOST:-proxy}:${BUILD_PROXY_PORT:-3000}" \
        NO_PROXY="localhost,127.0.0.1,proxy,postgres,memgraph,host.docker.internal" \
        "$tool_path" "$@"
        local exit_code=$?
        _disable_network_after_build
        exit $exit_code
    else
        exec "$tool_path" "$@"
    fi
}

show_build_blocked_message() {
    local tool="$1"
    local tool_upper
    tool_upper=$(echo "$tool" | tr '[:lower:]' '[:upper:]')

    cat >&2 << HEREDOC
+--------------------------------------------------------------+
|  BUILD TOOL BLOCKED: $tool
|
|  All builds are blocked by default for security.
|
|  TO RUN BUILDS:
|
|  Method 1: Environment variable override
|    ALLOW_BUILD=1 $tool <args>
|    ${tool_upper}_ALLOW_BUILD=1 $tool <args>
|
|  Method 2: Unrestricted shell (recommended)
|    1. Exit OpenCode (Ctrl+D or type 'exit')
|    2. Start shell: make shell-unrestricted
|    3. Run: $tool <args>
|
|  Method 3: For ./gradlew or other scripts
|    net ./gradlew <args>
|
|  LOGS: $LOG_FILE
+--------------------------------------------------------------+
HEREDOC
}

_enable_network_if_needed() {
    local lock_file="/tmp/slapenir-network-enabled.lock"

    if [ -f "$lock_file" ]; then
        log_build_attempt "NETWORK" "Already enabled (lock exists)" "$TOOL"
        return 0
    fi

    log_build_attempt "NETWORK" "Enabling internet access for build" "$TOOL $*"

    if command -v netctl >/dev/null 2>&1; then
        netctl enable 2>/dev/null || true
    elif [ "$(id -u)" -eq 0 ]; then
        bash /home/agent/scripts/network-enable.sh enable
    else
        log_build_attempt "WARNING" "Cannot enable network - no netctl or root" "$TOOL $*"
        echo "WARNING: Cannot enable network. Build may fail." >&2
        echo "         netctl not found and not running as root." >&2
    fi
}

_disable_network_after_build() {
    log_build_attempt "NETWORK" "Disabling internet access after build" "$TOOL"

    if command -v netctl >/dev/null 2>&1; then
        netctl disable 2>/dev/null || true
    elif [ "$(id -u)" -eq 0 ]; then
        bash /home/agent/scripts/network-enable.sh disable 2>/dev/null || true
    fi
}

is_opencode_active() {
    local detection_lib="/home/agent/scripts/lib/detection.sh"
    if [ -f "$detection_lib" ]; then
        source "$detection_lib"
        is_opencode_active
        return $?
    fi

    [ -n "${OPENCODE_SESSION_ID:-}" ] && return 0
    [ -n "${OPENCODE_YOLO:-}" ] && return 0
    [ -n "${OPENCODE_CONFIG_PATH:-}" ] && return 0

    return 1
}

get_opencode_session() {
    local lock_file="/tmp/opencode-session.lock"

    if [ -f "$lock_file" ]; then
        grep "^session_id=" "$lock_file" 2>/dev/null | cut -d= -f2 || echo "unknown"
    else
        echo "none"
    fi
}

validate_proxy_connection() {
    local proxy_host="${HTTP_PROXY:-http://proxy:3000}"

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
