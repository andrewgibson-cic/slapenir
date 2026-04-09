#!/bin/bash
# SLAPENIR Traffic Enforcement Script
# Forces all HTTP/HTTPS traffic through proxy, allows SSH, blocks and logs bypass attempts
#
# Must run as root (via s6-overlay init)
# Usage: /home/agent/scripts/traffic-enforcement.sh

set -euo pipefail

# Configuration (can be overridden via environment variables)
PROXY_HOST="${PROXY_HOST:-proxy}"
PROXY_PORT="${PROXY_PORT:-3000}"
LLAMA_SERVER_HOST="${LLAMA_SERVER_HOST:-host.docker.internal}"
LLAMA_SERVER_PORT="${LLAMA_SERVER_PORT:-8080}"
LOG_PREFIX="[TRAFFIC-ENFORCE]"

log() {
    echo "$LOG_PREFIX $1"
}

# Resolve hostname to IP address (Wolfi-compatible, no getent)
# Tries multiple methods: /etc/hosts, ping, Python
resolve_host() {
    local hostname="$1"
    local ip=""

    # Method 1: Check /etc/hosts first
    ip=$(grep -E "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\s+${hostname}" /etc/hosts 2>/dev/null | awk '{print $1}' | head -1)
    if [ -n "$ip" ]; then
        echo "$ip"
        return 0
    fi

    # Method 2: Use ping (shows IP in output even if ping fails due to permissions)
    ip=$(ping -c 1 -W 1 "$hostname" 2>&1 | grep -oE '\([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\)' | head -1 | tr -d '()')
    if [ -n "$ip" ]; then
        echo "$ip"
        return 0
    fi

    # Method 3: Use Python as fallback (always available in agent container)
    ip=$(python3 -c "import socket; print(socket.gethostbyname('$hostname'))" 2>/dev/null)
    if [ -n "$ip" ]; then
        echo "$ip"
        return 0
    fi

    return 1
}

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    log "ERROR: Must run as root for iptables"
    exit 1
fi

log "Setting up traffic enforcement rules..."

# Flush existing rules in our custom chain (if exists)
iptables -F TRAFFIC_ENFORCE 2>/dev/null || true
iptables -X TRAFFIC_ENFORCE 2>/dev/null || true

# Create custom chain for traffic enforcement
iptables -N TRAFFIC_ENFORCE

# Get proxy IP from DNS
PROXY_IP=$(resolve_host "$PROXY_HOST")
if [ -z "$PROXY_IP" ]; then
    log "ERROR: Cannot resolve proxy hostname"
    exit 1
fi
log "Proxy IP: $PROXY_IP"

# Get local container IP and subnet
LOCAL_IP=$(hostname -i | awk '{print $1}')
log "Local IP: $LOCAL_IP"

# =============================================================================
# ALLOW RULES (processed first)
# =============================================================================

# Allow loopback (must be first to allow localhost connections)
iptables -A TRAFFIC_ENFORCE -o lo -j ACCEPT

# Allow direct connections to localhost on any port
iptables -A TRAFFIC_ENFORCE -d 127.0.0.0/8 -j ACCEPT

# Allow established connections
iptables -A TRAFFIC_ENFORCE -m state --state ESTABLISHED,RELATED -j ACCEPT

# DNS FILTERING: Only allow specific DNS servers (prevents DNS exfiltration)
# Allow Google DNS
iptables -A TRAFFIC_ENFORCE -p udp --dport 53 -d 8.8.8.8 -j ACCEPT
iptables -A TRAFFIC_ENFORCE -p udp --dport 53 -d 8.8.4.4 -j ACCEPT
iptables -A TRAFFIC_ENFORCE -p tcp --dport 53 -d 8.8.8.8 -j ACCEPT
iptables -A TRAFFIC_ENFORCE -p tcp --dport 53 -d 8.8.4.4 -j ACCEPT

# Allow Cloudflare DNS
iptables -A TRAFFIC_ENFORCE -p udp --dport 53 -d 1.1.1.1 -j ACCEPT
iptables -A TRAFFIC_ENFORCE -p tcp --dport 53 -d 1.1.1.1 -j ACCEPT

# Block all other DNS (prevents DNS exfiltration to arbitrary servers)
iptables -A TRAFFIC_ENFORCE -p udp --dport 53 -j LOG --log-prefix "[DNS-BLOCK] " --log-level 4
iptables -A TRAFFIC_ENFORCE -p tcp --dport 53 -j LOG --log-prefix "[DNS-BLOCK] " --log-level 4
iptables -A TRAFFIC_ENFORCE -p udp --dport 53 -j DROP
iptables -A TRAFFIC_ENFORCE -p tcp --dport 53 -j DROP
log "DNS filtered to trusted servers only (8.8.8.8, 8.8.4.4, 1.1.1.1)"

# Allow SSH outbound (port 22)
iptables -A TRAFFIC_ENFORCE -p tcp --dport 22 -j ACCEPT
log "SSH traffic allowed"

# NOTE: Proxy connections are NOT allowed by default.
# When ALLOW_BUILD=1 is set, network-enable.sh temporarily opens proxy access.
# This ensures no tool can reach the internet without explicit permission.
# Internal services (Docker network, local LLM) remain accessible.

# Block proxy access even within Docker network (must precede broad allow)
# Without this, the 172.30.0.0/24 rule allows the agent to reach the proxy
# and bypass all traffic enforcement via HTTPS_PROXY.
iptables -A TRAFFIC_ENFORCE -d "$PROXY_IP" -j DROP
log "Proxy ($PROXY_IP) blocked - only accessible via ALLOW_BUILD"

# Allow internal Docker network traffic (slapenir services)
iptables -A TRAFFIC_ENFORCE -d 172.30.0.0/24 -j ACCEPT
log "Docker internal network allowed"

# Allow connections to llama server on host
LLAMA_HOST_IP=$(resolve_host "$LLAMA_SERVER_HOST" 2>/dev/null)
if [ -n "$LLAMA_HOST_IP" ]; then
    iptables -A TRAFFIC_ENFORCE -d "$LLAMA_HOST_IP" -p tcp --dport "$LLAMA_SERVER_PORT" -j ACCEPT
    log "Llama server connections allowed to $LLAMA_HOST_IP:$LLAMA_SERVER_PORT"
else
    log "WARNING: Could not resolve $LLAMA_SERVER_HOST - llama server connections not allowed"
fi

# =============================================================================
# NAT REDIRECT RULES — NOT applied by default
# =============================================================================
# NAT redirect to proxy is intentionally omitted in default (locked) state.
# network-enable.sh adds these rules when ALLOW_BUILD=1 is active,
# and removes them when the build completes.
# This prevents any tool from reaching the internet without explicit permission.

# =============================================================================
# BLOCK AND LOG RULES
# =============================================================================

# Log any traffic that gets here (bypass attempt)
iptables -A TRAFFIC_ENFORCE -m limit --limit 10/min -j LOG --log-prefix "[BYPASS-ATTEMPT] " --log-level 4

# Drop all other outbound traffic (use REJECT for fast failure instead of DROP which hangs)
iptables -A TRAFFIC_ENFORCE -j REJECT --reject-with icmp-port-unreachable
log "Unknown traffic rejected (fast fail)"

# =============================================================================
# APPLY CHAIN TO OUTPUT
# =============================================================================

# Insert our chain at the beginning of OUTPUT chain
iptables -I OUTPUT 1 -j TRAFFIC_ENFORCE

log "Traffic enforcement active (LOCKED mode)!"
log "Summary:"
log "  - HTTP/HTTPS: BLOCKED (proxy explicitly blocked)"
log "  - Proxy ($PROXY_IP): BLOCKED despite Docker network allow"
log "  - SSH (port 22): Allowed directly"
log "  - DNS: Filtered to trusted servers (8.8.8.8, 8.8.4.4, 1.1.1.1)"
log "  - Llama server ($LLAMA_SERVER_HOST:$LLAMA_SERVER_PORT): Allowed"
log "  - Docker internal (172.30.0.0/24): Allowed (except proxy)"
log "  - All other traffic: Blocked and logged"
log ""
log "  To enable internet access:"
log "    ALLOW_BUILD=1 <command>   (build wrappers enable automatically)"
log "    make shell-unrestricted    (flushes all iptables rules)"

# =============================================================================
# FAIL-SAFE VERIFICATION
# =============================================================================

log "Verifying traffic enforcement rules..."

# Verify TRAFFIC_ENFORCE chain exists
if ! iptables -L TRAFFIC_ENFORCE -n > /dev/null 2>&1; then
    log "CRITICAL: TRAFFIC_ENFORCE chain does not exist after setup!"
    exit 1
fi

# Verify DROP rule exists
if ! iptables -L TRAFFIC_ENFORCE -n | grep -q "DROP"; then
    log "CRITICAL: DROP rule not found in TRAFFIC_ENFORCE chain!"
    exit 1
fi

# Count total rules (should have multiple rules)
RULE_COUNT=$(iptables -L TRAFFIC_ENFORCE -n | grep -c "^" || echo "0")
if [ "$RULE_COUNT" -lt 10 ]; then
    log "CRITICAL: Too few rules in TRAFFIC_ENFORCE chain (found: $RULE_COUNT, expected: >10)"
    exit 1
fi

log "✓ Fail-safe verification passed - $RULE_COUNT rules active"
log "✓ Traffic enforcement is active and protecting the container"
