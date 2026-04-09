#!/bin/bash
# SLAPENIR Network Enable Script
# Temporarily opens/closes internet access through the proxy for build operations.
#
# Usage:
#   network-enable.sh enable    # Open proxy access via iptables
#   network-enable.sh disable   # Close proxy access via iptables
#   network-enable.sh status    # Check if network is enabled
#
# Must run as root (via sudo or as root user).
# Build wrappers call this via: sudo -n network-enable.sh enable/disable

set -euo pipefail

PROXY_HOST="${PROXY_HOST:-proxy}"
PROXY_PORT="${PROXY_PORT:-3000}"
LOCK_FILE="/tmp/slapenir-network-enabled.lock"
LOG_PREFIX="[NETWORK]"

log() { echo "$LOG_PREFIX $1"; }

resolve_host() {
    local hostname="$1" ip=""
    ip=$(grep -E "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\s+${hostname}" /etc/hosts 2>/dev/null | awk '{print $1}' | head -1)
    [ -n "$ip" ] && { echo "$ip"; return 0; }
    ip=$(ping -c 1 -W 1 "$hostname" 2>&1 | grep -oE '\([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\)' | head -1 | tr -d '()')
    [ -n "$ip" ] && { echo "$ip"; return 0; }
    ip=$(python3 -c "import socket; print(socket.gethostbyname('$hostname'))" 2>/dev/null)
    [ -n "$ip" ] && { echo "$ip"; return 0; }
    return 1
}

do_enable() {
    if [ "$(id -u)" -ne 0 ]; then
        log "ERROR: Must run as root for iptables manipulation"
        return 1
    fi

    if [ -f "$LOCK_FILE" ]; then
        log "Network already enabled (lock file exists)"
        return 0
    fi

    local proxy_ip
    proxy_ip=$(resolve_host "$PROXY_HOST")
    if [ -z "$proxy_ip" ]; then
        log "ERROR: Cannot resolve proxy hostname '$PROXY_HOST'"
        return 1
    fi

    log "Enabling network access through proxy ($proxy_ip:$PROXY_PORT)..."

    # Insert ACCEPT before the proxy DROP rule (placed by traffic-enforcement.sh)
    # Find the DROP rule targeting the proxy IP and insert our ACCEPT before it
    local drop_line
    drop_line=$(iptables -L TRAFFIC_ENFORCE -n --line-numbers | grep "DROP.*$proxy_ip" | head -1 | awk '{print $1}')
    if [ -n "$drop_line" ]; then
        iptables -I TRAFFIC_ENFORCE "$drop_line" -d "$proxy_ip" -p tcp --dport "$PROXY_PORT" -j ACCEPT
    else
        # Fallback: insert near the top (after ESTABLISHED rule)
        iptables -I TRAFFIC_ENFORCE 4 -d "$proxy_ip" -p tcp --dport "$PROXY_PORT" -j ACCEPT
    fi

    if ! iptables -t nat -L TRAFFIC_REDIRECT -n >/dev/null 2>&1; then
        iptables -t nat -N TRAFFIC_REDIRECT
    fi

    if [ "$(iptables -t nat -L TRAFFIC_REDIRECT -n 2>/dev/null | grep -c REDIRECT)" -eq 0 ]; then
        iptables -t nat -A TRAFFIC_REDIRECT -p tcp --dport 80 -j REDIRECT --to-ports "$PROXY_PORT"
        iptables -t nat -A TRAFFIC_REDIRECT -p tcp --dport 443 -j REDIRECT --to-ports "$PROXY_PORT"
    fi

    if ! iptables -t nat -L OUTPUT -n 2>/dev/null | grep -q TRAFFIC_REDIRECT; then
        iptables -t nat -I OUTPUT 1 -j TRAFFIC_REDIRECT
    fi

    date +%s > "$LOCK_FILE"
    log "Network access ENABLED"
}

do_disable() {
    if [ "$(id -u)" -ne 0 ]; then
        log "WARNING: Cannot disable network (not root) - rules may persist"
        return 1
    fi

    if [ ! -f "$LOCK_FILE" ]; then
        return 0
    fi

    log "Disabling network access..."

    local proxy_ip
    proxy_ip=$(resolve_host "$PROXY_HOST" 2>/dev/null || true)
    if [ -n "$proxy_ip" ]; then
        iptables -D TRAFFIC_ENFORCE -d "$proxy_ip" -p tcp --dport "$PROXY_PORT" -j ACCEPT 2>/dev/null || true
    fi

    iptables -t nat -D OUTPUT -j TRAFFIC_REDIRECT 2>/dev/null || true
    iptables -t nat -F TRAFFIC_REDIRECT 2>/dev/null || true
    iptables -t nat -X TRAFFIC_REDIRECT 2>/dev/null || true

    rm -f "$LOCK_FILE"
    log "Network access DISABLED"
}

do_status() {
    if [ -f "$LOCK_FILE" ]; then
        local enabled_at
        enabled_at=$(cat "$LOCK_FILE" 2>/dev/null || echo "unknown")
        local now=$(date +%s)
        local age=$(( now - enabled_at ))
        log "Network ENABLED (active for ${age}s)"
        return 0
    else
        log "Network DISABLED"
        return 1
    fi
}

case "${1:-status}" in
    enable)  do_enable ;;
    disable) do_disable ;;
    status)  do_status ;;
    *)
        echo "Usage: $0 {enable|disable|status}" >&2
        exit 1
        ;;
esac
