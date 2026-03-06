#!/bin/bash
# Disable traffic enforcement by flushing iptables rules
# Used for interactive shell sessions where build tools need external access

set -euo pipefail

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Must run as root to modify iptables" >&2
    exit 1
fi

echo "[traffic-disable] Disabling traffic enforcement..."

# Flush custom chains
iptables -F TRAFFIC_ENFORCE 2>/dev/null || true
iptables -X TRAFFIC_ENFORCE 2>/dev/null || true
iptables -t nat -F TRAFFIC_REDIRECT 2>/dev/null || true
iptables -t nat -X TRAFFIC_REDIRECT 2>/dev/null || true

# Remove jumps to custom chains from OUTPUT
iptables -D OUTPUT -j TRAFFIC_ENFORCE 2>/dev/null || true
iptables -t nat -D OUTPUT -j TRAFFIC_REDIRECT 2>/dev/null || true

# Set default policy to ACCEPT
iptables -P OUTPUT ACCEPT 2>/dev/null || true

echo "[traffic-disable] Traffic enforcement disabled successfully"
echo "[traffic-disable] All outbound traffic now allowed"
