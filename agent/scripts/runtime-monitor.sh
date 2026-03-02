#!/bin/bash
# ============================================================================
# SLAPENIR Runtime Traffic Enforcement Monitor
# ============================================================================
# Continuously monitors iptables rules and logs bypass attempts
# Automatically shuts down agent if traffic enforcement fails
# ============================================================================

set -euo pipefail

LOG_PREFIX="[RUNTIME-MONITOR]"
CHECK_INTERVAL=30  # Check every 30 seconds
BYPASS_LOG="/tmp/bypass-attempts.log"
MONITOR_ENABLED="${RUNTIME_MONITOR_ENABLED:-true}"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_PREFIX $1"
}

# Check if monitoring is enabled
if [ "$MONITOR_ENABLED" != "true" ]; then
    log "Runtime monitoring disabled (RUNTIME_MONITOR_ENABLED != true)"
    exit 0
fi

log "Starting runtime traffic enforcement monitor (interval: ${CHECK_INTERVAL}s)"

# Counter for consecutive failures
FAILURE_COUNT=0
MAX_FAILURES=3

# Main monitoring loop
while true; do
    # Check if iptables is available
    if ! command -v iptables > /dev/null 2>&1; then
        log "CRITICAL: iptables command not available!"
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
    # Check if TRAFFIC_ENFORCE chain exists
    elif ! iptables -L TRAFFIC_ENFORCE -n > /dev/null 2>&1; then
        log "CRITICAL: TRAFFIC_ENFORCE chain missing!"
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
    # Check if DROP rule exists
    elif ! iptables -L TRAFFIC_ENFORCE -n | grep -q "DROP"; then
        log "CRITICAL: DROP rule missing from TRAFFIC_ENFORCE chain!"
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
    # Verify rule count
    else
        RULE_COUNT=$(iptables -L TRAFFIC_ENFORCE -n | grep -c "^" || echo "0")
        if [ "$RULE_COUNT" -lt 10 ]; then
            log "CRITICAL: Too few rules in TRAFFIC_ENFORCE ($RULE_COUNT)"
            FAILURE_COUNT=$((FAILURE_COUNT + 1))
        else
            # All checks passed
            if [ $FAILURE_COUNT -gt 0 ]; then
                log "Traffic enforcement restored (was failing)"
            fi
            FAILURE_COUNT=0

            # Check for bypass attempts in kernel logs (skip if dmesg not available)
            if command -v dmesg > /dev/null 2>&1 && dmesg > /dev/null 2>&1; then
                BYPASS_COUNT=$(dmesg | grep -c "BYPASS-ATTEMPT" 2>/dev/null || echo 0)
                if [ "$BYPASS_COUNT" -gt 0 ] 2>/dev/null; then
                    log "⚠ Detected $BYPASS_COUNT bypass attempts in kernel log"
                    dmesg | grep "BYPASS-ATTEMPT" | tail -5 >> "$BYPASS_LOG" 2>/dev/null
                fi
            fi

            # Check for DNS block attempts
            if command -v dmesg > /dev/null 2>&1 && dmesg > /dev/null 2>&1; then
                DNS_BLOCK_COUNT=$(dmesg | grep -c "DNS-BLOCK" 2>/dev/null || echo 0)
                if [ "$DNS_BLOCK_COUNT" -gt 0 ] 2>/dev/null; then
                    log "⚠ Detected $DNS_BLOCK_COUNT unauthorized DNS attempts"
                fi
            fi
        fi
    fi
    
    # If we've had multiple consecutive failures, take action
    if [ $FAILURE_COUNT -ge $MAX_FAILURES ]; then
        log "EMERGENCY: Traffic enforcement failed $FAILURE_COUNT consecutive checks!"
        log "EMERGENCY: Initiating emergency shutdown to prevent data leakage"
        
        # Log the emergency
        echo "$(date '+%Y-%m-%d %H:%M:%S') EMERGENCY SHUTDOWN: Traffic enforcement failure" >> "$BYPASS_LOG"
        
        # Try to stop the agent service gracefully
        if command -v s6-svc > /dev/null 2>&1; then
            log "Stopping agent service via s6"
            s6-svc -d /run/service/agent-svc 2>/dev/null || true
        fi
        
        # Force kill all user processes as last resort
        log "Killing all agent processes"
        pkill -U agent || true
        
        # Exit with error
        exit 1
    fi
    
    # Sleep until next check
    sleep "$CHECK_INTERVAL"
done