#!/bin/bash
# ============================================================================
# Setup Build Configuration
# ============================================================================
# Initializes package manager configurations for isolated builds
# Runs on container startup via s6-overlay
#
# Creates:
#   - ~/.npmrc (npm configuration)
#   - ~/.yarnrc.yml (yarn configuration)
#   - ~/.gradle/gradle.properties (gradle configuration)
#   - ~/.config/pip/pip.conf (pip configuration)
# ============================================================================

set -euo pipefail

LOG_PREFIX="[BUILD-CONFIG]"
CONFIG_DIR="/home/agent/config"
AGENT_HOME="/home/agent"

log() {
    echo "$LOG_PREFIX $1"
}

log "Setting up build configurations for isolated environment..."

# ============================================================================
# Create Cache Directories
# ============================================================================

log "Creating cache directories..."

mkdir -p "$AGENT_HOME/.npm"
mkdir -p "$AGENT_HOME/.gradle/caches"
mkdir -p "$AGENT_HOME/.gradle/wrapper"
mkdir -p "$AGENT_HOME/.cache/pip"
mkdir -p "$AGENT_HOME/.yarn/cache"
mkdir -p "$AGENT_HOME/.yarn/global"
mkdir -p "$AGENT_HOME/.config/pip"

# ============================================================================
# Install npm Configuration
# ============================================================================

if [ -f "$CONFIG_DIR/npm/.npmrc" ]; then
    cp "$CONFIG_DIR/npm/.npmrc" "$AGENT_HOME/.npmrc"
    log "✓ npm config installed ($AGENT_HOME/.npmrc)"
else
    log "⚠ npm config not found at $CONFIG_DIR/npm/.npmrc"
fi

# ============================================================================
# Install yarn Configuration
# ============================================================================

if [ -f "$CONFIG_DIR/yarn/.yarnrc.yml" ]; then
    cp "$CONFIG_DIR/yarn/.yarnrc.yml" "$AGENT_HOME/.yarnrc.yml"
    log "✓ yarn config installed ($AGENT_HOME/.yarnrc.yml)"
else
    log "⚠ yarn config not found at $CONFIG_DIR/yarn/.yarnrc.yml"
fi

# ============================================================================
# Install gradle Configuration
# ============================================================================

mkdir -p "$AGENT_HOME/.gradle"
if [ -f "$CONFIG_DIR/gradle/gradle.properties" ]; then
    cp "$CONFIG_DIR/gradle/gradle.properties" "$AGENT_HOME/.gradle/gradle.properties"
    log "✓ gradle config installed ($AGENT_HOME/.gradle/gradle.properties)"
else
    log "⚠ gradle config not found at $CONFIG_DIR/gradle/gradle.properties"
fi

# ============================================================================
# Install pip Configuration
# ============================================================================

if [ -f "$CONFIG_DIR/pip/pip.conf" ]; then
    cp "$CONFIG_DIR/pip/pip.conf" "$AGENT_HOME/.config/pip/pip.conf"
    log "✓ pip config installed ($AGENT_HOME/.config/pip/pip.conf)"
else
    log "⚠ pip config not found at $CONFIG_DIR/pip/pip.conf"
fi

# ============================================================================
# Set Ownership
# ============================================================================

log "Setting ownership to agent user..."

chown -R agent:agent "$AGENT_HOME/.npm"
chown -R agent:agent "$AGENT_HOME/.gradle"
chown -R agent:agent "$AGENT_HOME/.cache"
chown -R agent:agent "$AGENT_HOME/.yarn"
chown -R agent:agent "$AGENT_HOME/.config/pip"
chown agent:agent "$AGENT_HOME/.npmrc" 2>/dev/null || true
chown agent:agent "$AGENT_HOME/.yarnrc.yml" 2>/dev/null || true

# ============================================================================
# Create Log Directory
# ============================================================================

mkdir -p /var/log/slapenir
chown agent:agent /var/log/slapenir 2>/dev/null || true
chmod 755 /var/log/slapenir

# ============================================================================
# Verify Configurations
# ============================================================================

log "Verifying configurations..."

VERIFY_FAILED=0

if [ -f "$AGENT_HOME/.npmrc" ]; then
    if grep -q "proxy=http://proxy:3000" "$AGENT_HOME/.npmrc"; then
        log "  ✓ npm proxy configured"
    else
        log "  ✗ npm proxy not configured"
        VERIFY_FAILED=1
    fi
else
    log "  ✗ npm config missing"
    VERIFY_FAILED=1
fi

if [ -f "$AGENT_HOME/.gradle/gradle.properties" ]; then
    if grep -q "proxyHost=proxy" "$AGENT_HOME/.gradle/gradle.properties"; then
        log "  ✓ gradle proxy configured"
    else
        log "  ✗ gradle proxy not configured"
        VERIFY_FAILED=1
    fi
else
    log "  ✗ gradle config missing"
    VERIFY_FAILED=1
fi

if [ -f "$AGENT_HOME/.config/pip/pip.conf" ]; then
    if grep -q "proxy = http://proxy:3000" "$AGENT_HOME/.config/pip/pip.conf"; then
        log "  ✓ pip proxy configured"
    else
        log "  ✗ pip proxy not configured"
        VERIFY_FAILED=1
    fi
else
    log "  ✗ pip config missing"
    VERIFY_FAILED=1
fi

# ============================================================================
# Summary
# ============================================================================

log ""
log "=========================================="
log "Build Configuration Summary"
log "=========================================="
log "  npm:    $AGENT_HOME/.npmrc"
log "  yarn:   $AGENT_HOME/.yarnrc.yml"
log "  gradle: $AGENT_HOME/.gradle/gradle.properties"
log "  pip:    $AGENT_HOME/.config/pip/pip.conf"
log ""
log "Cache directories:"
log "  npm:    $AGENT_HOME/.npm"
log "  gradle: $AGENT_HOME/.gradle/caches"
log "  pip:    $AGENT_HOME/.cache/pip"
log "  yarn:   $AGENT_HOME/.yarn/cache"
log ""
log "Log file: /var/log/slapenir/build-control.log"
log "=========================================="

if [ "$VERIFY_FAILED" -eq 1 ]; then
    log "⚠ Some configurations failed verification"
    exit 1
fi

log "✓ Build configuration complete"
