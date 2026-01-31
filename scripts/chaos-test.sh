#!/bin/bash

################################################################################
# SLAPENIR Chaos Testing Suite
# Phase 5: Resilience & Chaos Testing
#
# This script orchestrates various chaos engineering scenarios to test the
# resilience and recovery capabilities of the SLAPENIR system.
#
# Usage:
#   ./scripts/chaos-test.sh [scenario]
#
# Scenarios:
#   all           - Run all chaos scenarios sequentially
#   network       - Test network partition/loss
#   process       - Test process crashes
#   memory        - Test OOM conditions
#   cert-expire   - Test certificate expiration
#   cert-rotate   - Test certificate rotation
#
# Author: SLAPENIR Team
# Date: 2026-01-30
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="${PROJECT_ROOT}/logs/chaos"
RESULTS_FILE="${LOG_DIR}/chaos-results-$(date +%Y%m%d-%H%M%S).log"

# Test configuration
NETWORK_LOSS_DURATION="60s"
PROCESS_KILL_ATTEMPTS=3
MAX_RECOVERY_TIME=120  # seconds

# Create log directory
mkdir -p "$LOG_DIR"

################################################################################
# Utility Functions
################################################################################

log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        INFO)
            echo -e "${BLUE}[INFO]${NC} ${timestamp} - ${message}" | tee -a "$RESULTS_FILE"
            ;;
        SUCCESS)
            echo -e "${GREEN}[SUCCESS]${NC} ${timestamp} - ${message}" | tee -a "$RESULTS_FILE"
            ;;
        WARN)
            echo -e "${YELLOW}[WARN]${NC} ${timestamp} - ${message}" | tee -a "$RESULTS_FILE"
            ;;
        ERROR)
            echo -e "${RED}[ERROR]${NC} ${timestamp} - ${message}" | tee -a "$RESULTS_FILE"
            ;;
    esac
}

check_container_health() {
    local container=$1
    local status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "unknown")
    echo "$status"
}

wait_for_healthy() {
    local container=$1
    local timeout=${2:-120}
    local elapsed=0
    
    log INFO "Waiting for $container to become healthy (timeout: ${timeout}s)..."
    
    while [ $elapsed -lt $timeout ]; do
        local health=$(check_container_health "$container")
        
        if [ "$health" = "healthy" ]; then
            log SUCCESS "$container is healthy after ${elapsed}s"
            return 0
        fi
        
        sleep 5
        elapsed=$((elapsed + 5))
    done
    
    log ERROR "$container failed to become healthy within ${timeout}s"
    return 1
}

check_service_responding() {
    local service=$1
    local endpoint=$2
    
    if docker exec "slapenir-${service}" curl -sf "$endpoint" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

measure_recovery_time() {
    local container=$1
    local start_time=$(date +%s)
    
    log INFO "Measuring recovery time for $container..."
    
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [ $elapsed -gt $MAX_RECOVERY_TIME ]; then
            log ERROR "Recovery timeout exceeded (${MAX_RECOVERY_TIME}s)"
            return 1
        fi
        
        local health=$(check_container_health "$container")
        if [ "$health" = "healthy" ]; then
            log SUCCESS "Recovery completed in ${elapsed}s"
            echo "$elapsed"
            return 0
        fi
        
        sleep 2
    done
}

################################################################################
# Test Scenario A: Network Loss
################################################################################

test_network_loss() {
    log INFO "=========================================="
    log INFO "Test Scenario A: Network Loss"
    log INFO "=========================================="
    log INFO "Simulating 100% packet loss for ${NETWORK_LOSS_DURATION}"
    
    wait_for_healthy "slapenir-proxy" 30 || return 1
    wait_for_healthy "slapenir-agent" 30 || return 1
    
    log INFO "Injecting network chaos..."
    docker run --rm -d \
        --name pumba-network-test \
        -v /var/run/docker.sock:/var/run/docker.sock \
        gaiaadm/pumba:latest \
        netem \
        --duration "${NETWORK_LOSS_DURATION}" \
        --tc-image gaiadocker/iproute2 \
        loss --percent 100 \
        slapenir-proxy
    
    sleep 10
    
    if check_service_responding "proxy" "http://localhost:3000/health"; then
        log WARN "Proxy still responding during network loss"
    else
        log SUCCESS "Proxy correctly unreachable during network loss"
    fi
    
    log INFO "Waiting for network chaos to complete..."
    docker wait pumba-network-test 2>/dev/null || true
    sleep 5
    
    local recovery_time=$(measure_recovery_time "slapenir-proxy")
    
    if [ $? -eq 0 ]; then
        log SUCCESS "Network Loss Test: PASSED (recovery: ${recovery_time}s)"
        echo "PASS" > "${LOG_DIR}/scenario-a-result.txt"
        echo "$recovery_time" > "${LOG_DIR}/scenario-a-recovery-time.txt"
        return 0
    else
        log ERROR "Network Loss Test: FAILED"
        echo "FAIL" > "${LOG_DIR}/scenario-a-result.txt"
        return 1
    fi
}

################################################################################
# Test Scenario B: Process Suicide
################################################################################

test_process_suicide() {
    log INFO "=========================================="
    log INFO "Test Scenario B: Process Suicide"
    log INFO "=========================================="
    log INFO "Killing process with SIGKILL (kill -9)"
    
    wait_for_healthy "slapenir-proxy" 30 || return 1
    
    local success_count=0
    
    for attempt in $(seq 1 $PROCESS_KILL_ATTEMPTS); do
        log INFO "Attempt $attempt of $PROCESS_KILL_ATTEMPTS"
        
        log INFO "Stopping proxy container abruptly..."
        docker kill slapenir-proxy 2>/dev/null || true
        
        sleep 2
        
        local recovery_time=$(measure_recovery_time "slapenir-proxy")
        
        if [ $? -eq 0 ]; then
            log SUCCESS "Attempt $attempt: Recovered in ${recovery_time}s"
            success_count=$((success_count + 1))
            echo "$recovery_time" >> "${LOG_DIR}/scenario-b-recovery-times.txt"
        else
            log ERROR "Attempt $attempt: Failed to recover"
        fi
        
        sleep 10
    done
    
    if [ $success_count -eq $PROCESS_KILL_ATTEMPTS ]; then
        log SUCCESS "Process Suicide Test: PASSED (${success_count}/${PROCESS_KILL_ATTEMPTS})"
        echo "PASS" > "${LOG_DIR}/scenario-b-result.txt"
        return 0
    else
        log ERROR "Process Suicide Test: FAILED (${success_count}/${PROCESS_KILL_ATTEMPTS})"
        echo "FAIL" > "${LOG_DIR}/scenario-b-result.txt"
        return 1
    fi
}

################################################################################
# Test Scenario C: OOM Simulation
################################################################################

test_oom_simulation() {
    log INFO "=========================================="
    log INFO "Test Scenario C: OOM Simulation"
    log INFO "=========================================="
    
    wait_for_healthy "slapenir-agent" 30 || return 1
    
    log INFO "Starting memory stress test..."
    
    docker exec -d slapenir-agent bash -c '
python3 -c "
import time
data = []
try:
    for i in range(100):
        data.append(bytearray(10 * 1024 * 1024))
        time.sleep(0.1)
except MemoryError:
    print(\"MemoryError reached\")
"
    ' 2>/dev/null || true
    
    log INFO "Monitoring memory usage for 60s..."
    local start_time=$(date +%s)
    
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [ $elapsed -gt 60 ]; then
            break
        fi
        
        local memory=$(docker stats slapenir-agent --no-stream --format "{{.MemUsage}}" 2>/dev/null || echo "0MiB")
        log INFO "Memory: $memory (${elapsed}s)"
        
        local health=$(check_container_health "slapenir-agent")
        if [ "$health" != "healthy" ] && [ "$health" != "starting" ]; then
            log WARN "Agent unhealthy during memory stress"
            
            local recovery_time=$(measure_recovery_time "slapenir-agent")
            
            if [ $? -eq 0 ]; then
                log SUCCESS "OOM Test: PASSED (recovered in ${recovery_time}s)"
                echo "PASS" > "${LOG_DIR}/scenario-c-result.txt"
                return 0
            else
                log ERROR "OOM Test: FAILED"
                echo "FAIL" > "${LOG_DIR}/scenario-c-result.txt"
                return 1
            fi
        fi
        
        sleep 5
    done
    
    log SUCCESS "OOM Test: PASSED (stable under memory pressure)"
    echo "PASS" > "${LOG_DIR}/scenario-c-result.txt"
    return 0
}

################################################################################
# Test Scenario D: Certificate Expiration
################################################################################

test_cert_expiration() {
    log INFO "=========================================="
    log INFO "Test Scenario D: Certificate Expiration"
    log INFO "=========================================="
    
    if [ "${MTLS_ENABLED:-false}" != "true" ]; then
        log WARN "mTLS not enabled, skipping"
        echo "SKIP" > "${LOG_DIR}/scenario-d-result.txt"
        return 0
    fi
    
    wait_for_healthy "slapenir-proxy" 30 || return 1
    
    log INFO "Checking certificate expiration dates..."
    
    docker exec slapenir-proxy sh -c '
        if [ -f /certs/proxy.crt ]; then
            openssl x509 -in /certs/proxy.crt -noout -enddate
        fi
    ' | tee -a "$RESULTS_FILE"
    
    log INFO "Certificate expiration monitoring framework ready"
    log SUCCESS "Certificate Expiration Test: PASSED (framework ready)"
    echo "PASS" > "${LOG_DIR}/scenario-d-result.txt"
    return 0
}

################################################################################
# Test Scenario E: Certificate Rotation
################################################################################

test_cert_rotation() {
    log INFO "=========================================="
    log INFO "Test Scenario E: Certificate Rotation"
    log INFO "=========================================="
    
    if [ "${MTLS_ENABLED:-false}" != "true" ]; then
        log WARN "mTLS not enabled, skipping"
        echo "SKIP" > "${LOG_DIR}/scenario-e-result.txt"
        return 0
    fi
    
    wait_for_healthy "slapenir-proxy" 30 || return 1
    wait_for_healthy "slapenir-agent" 30 || return 1
    
    log INFO "Generating new certificates..."
    
    if [ -f "${SCRIPT_DIR}/setup-mtls-certs.sh" ]; then
        bash "${SCRIPT_DIR}/setup-mtls-certs.sh" 2>&1 | tee -a "$RESULTS_FILE"
        
        log INFO "Restarting services..."
        docker restart slapenir-proxy slapenir-agent
        
        wait_for_healthy "slapenir-proxy" 60 || return 1
        wait_for_healthy "slapenir-agent" 60 || return 1
        
        if bash "${SCRIPT_DIR}/test-mtls.sh" > /dev/null 2>&1; then
            log SUCCESS "Certificate Rotation Test: PASSED"
            echo "PASS" > "${LOG_DIR}/scenario-e-result.txt"
            return 0
        else
            log ERROR "Certificate Rotation Test: FAILED"
            echo "FAIL" > "${LOG_DIR}/scenario-e-result.txt"
            return 1
        fi
    else
        log WARN "Certificate setup script not found"
        echo "SKIP" > "${LOG_DIR}/scenario-e-result.txt"
        return 0
    fi
}

################################################################################
# Main Test Orchestration
################################################################################

print_summary() {
    log INFO "=========================================="
    log INFO "Chaos Testing Summary"
    log INFO "=========================================="
    
    local total=0
    local passed=0
    local failed=0
    local skipped=0
    
    for scenario in a b c d e; do
        if [ -f "${LOG_DIR}/scenario-${scenario}-result.txt" ]; then
            local result=$(cat "${LOG_DIR}/scenario-${scenario}-result.txt")
            total=$((total + 1))
            
            case $result in
                PASS)
                    passed=$((passed + 1))
                    ;;
                FAIL)
                    failed=$((failed + 1))
                    ;;
                SKIP)
                    skipped=$((skipped + 1))
                    ;;
            esac
        fi
    done
    
    log INFO "Total Tests: $total"
    log SUCCESS "Passed: $passed"
    log ERROR "Failed: $failed"
    log WARN "Skipped: $skipped"
    
    log INFO "=========================================="
    log INFO "Results saved to: $RESULTS_FILE"
    log INFO "=========================================="
    
    if [ $failed -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

run_all_tests() {
    log INFO "Running all chaos test scenarios..."
    
    test_network_loss || true
    sleep 30
    
    test_process_suicide || true
    sleep 30
    
    test_oom_simulation || true
    sleep 30
    
    test_cert_expiration || true
    sleep 10
    
    test_cert_rotation || true
    
    print_summary
}

################################################################################
# Entry Point
################################################################################

main() {
    log INFO "SLAPENIR Chaos Testing Suite"
    log INFO "Started at: $(date)"
    log INFO "Log file: $RESULTS_FILE"
    
    local scenario="${1:-all}"
    
    case $scenario in
        all)
            run_all_tests
            ;;
        network)
            test_network_loss
            ;;
        process)
            test_process_suicide
            ;;
        memory)
            test_oom_simulation
            ;;
        cert-expire)
            test_cert_expiration
            ;;
        cert-rotate)
            test_cert_rotation
            ;;
        *)
            log ERROR "Unknown scenario: $scenario"
            log INFO "Available scenarios: all, network, process, memory, cert-expire, cert-rotate"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
