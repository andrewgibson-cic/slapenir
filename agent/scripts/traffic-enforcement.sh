#!/bin/bash
# SLAPENIR Traffic Enforcement Script
# Forces all HTTP/HTTPS traffic through proxy, allows SSH, blocks and logs bypass attempts
#
# Must run as root (via s6-overlay init)
# Usage: /home/agent/scripts/traffic-enforcement.sh

set -e

PROXY_HOST="proxy"
PROXY_PORT="3000"
LOG_PREFIX="[TRAFFIC-ENFORCE]"

log() {
    echo "$LOG_PREFIX $1"
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
PROXY_IP=$(getent hosts "$PROXY_HOST" | awk '{print $1}' | head -1)
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

# Allow loopback
iptables -A TRAFFIC_ENFORCE -o lo -j ACCEPT

# Allow established connections
iptables -A TRAFFIC_ENFORCE -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow DNS (both UDP and TCP)
iptables -A TRAFFIC_ENFORCE -p udp --dport 53 -j ACCEPT
iptables -A TRAFFIC_ENFORCE -p tcp --dport 53 -j ACCEPT

# Allow SSH outbound (port 22)
iptables -A TRAFFIC_ENFORCE -p tcp --dport 22 -j ACCEPT
log "SSH traffic allowed"

# Allow connections to proxy
iptables -A TRAFFIC_ENFORCE -d "$PROXY_IP" -p tcp --dport "$PROXY_PORT" -j ACCEPT
log "Proxy connections allowed"

# Allow internal Docker network traffic (slapenir services)
iptables -A TRAFFIC_ENFORCE -d 172.21.0.0/24 -j ACCEPT

# =============================================================================
# REDIRECT RULES
# =============================================================================

# Redirect HTTP (port 80) to proxy
iptables -A TRAFFIC_ENFORCE -p tcp --dport 80 -j REDIRECT --to-ports "$PROXY_PORT"
log "HTTP traffic redirected to proxy"

# Redirect HTTPS (port 443) to proxy for CONNECT tunneling
iptables -A TRAFFIC_ENFORCE -p tcp --dport 443 -j REDIRECT --to-ports "$PROXY_PORT"
log "HTTPS traffic redirected to proxy"

# =============================================================================
# BLOCK AND LOG RULES
# =============================================================================

# Log any traffic that gets here (bypass attempt)
iptables -A TRAFFIC_ENFORCE -m limit --limit 10/min -j LOG --log-prefix "[BYPASS-ATTEMPT] " --log-level 4

# Drop all other outbound traffic
iptables -A TRAFFIC_ENFORCE -j DROP
log "Unknown traffic blocked and logged"

# =============================================================================
# APPLY CHAIN TO OUTPUT
# =============================================================================

# Insert our chain at the beginning of OUTPUT chain
iptables -I OUTPUT 1 -j TRAFFIC_ENFORCE

log "Traffic enforcement active!"
log "Summary:"
log "  - HTTP/HTTPS: Redirected to proxy:$PROXY_PORT"
log "  - SSH (port 22): Allowed directly"
log "  - DNS (port 53): Allowed"
log "  - All other traffic: Blocked and logged"
