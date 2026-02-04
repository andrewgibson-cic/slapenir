#!/bin/bash
# SLAPENIR Container Health Check Script
# Validates all services are healthy and properly connected

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Track overall health
HEALTH_STATUS=0

# Check if a container is running
check_container_running() {
    local container_name=$1
    log_info "Checking if $container_name is running..."
    
    if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        log_success "$container_name is running"
        return 0
    else
        log_error "$container_name is not running"
        HEALTH_STATUS=1
        return 1
    fi
}

# Check container health status
check_container_health() {
    local container_name=$1
    log_info "Checking health status of $container_name..."
    
    local health_status=$(docker inspect --format='{{.State.Health.Status}}' $container_name 2>/dev/null || echo "none")
    
    case $health_status in
        "healthy")
            log_success "$container_name is healthy"
            return 0
            ;;
        "unhealthy")
            log_error "$container_name is unhealthy"
            HEALTH_STATUS=1
            return 1
            ;;
        "starting")
            log_warning "$container_name is still starting"
            return 2
            ;;
        "none")
            log_warning "$container_name has no health check configured"
            return 3
            ;;
        *)
            log_warning "$container_name has unknown health status: $health_status"
            return 3
            ;;
    esac
}

# Check if proxy is responding to HTTP requests
check_proxy_http() {
    log_info "Testing proxy HTTP endpoint..."
    
    if curl -f -s -o /dev/null -w "%{http_code}" http://localhost:3000/health | grep -q "200"; then
        log_success "Proxy HTTP endpoint is responding"
        return 0
    else
        log_error "Proxy HTTP endpoint is not responding"
        HEALTH_STATUS=1
        return 1
    fi
}

# Check if proxy metrics are available
check_proxy_metrics() {
    log_info "Testing proxy metrics endpoint..."
    
    if curl -f -s http://localhost:3000/metrics | grep -q "slapenir_"; then
        log_success "Proxy metrics are available"
        return 0
    else
        log_warning "Proxy metrics endpoint may not be fully initialized"
        return 1
    fi
}

# Check if agent container can reach proxy
check_agent_proxy_connectivity() {
    log_info "Testing agent -> proxy connectivity..."
    
    if docker exec slapenir-agent sh -c 'curl -f -s http://proxy:3000/health' > /dev/null 2>&1; then
        log_success "Agent can reach proxy"
        return 0
    else
        log_error "Agent cannot reach proxy"
        HEALTH_STATUS=1
        return 1
    fi
}

# Check if agent has dummy credentials
check_agent_credentials() {
    log_info "Checking agent dummy credentials..."
    
    local has_dummy=$(docker exec slapenir-agent sh -c 'env | grep -E "DUMMY_|_DUMMY" | wc -l')
    
    if [ "$has_dummy" -gt 0 ]; then
        log_success "Agent has $has_dummy dummy credential(s)"
        return 0
    else
        log_warning "Agent may not have dummy credentials initialized yet"
        return 1
    fi
}

# Check if agent can execute Python
check_agent_python() {
    log_info "Testing agent Python environment..."
    
    if docker exec slapenir-agent python3 -c "import sys; print(sys.version)" > /dev/null 2>&1; then
        log_success "Agent Python environment is working"
        return 0
    else
        log_error "Agent Python environment has issues"
        HEALTH_STATUS=1
        return 1
    fi
}

# Check Step-CA health
check_stepca_health() {
    log_info "Testing Step-CA health..."
    
    if docker exec slapenir-ca step ca health > /dev/null 2>&1; then
        log_success "Step-CA is healthy"
        return 0
    else
        log_error "Step-CA is not healthy"
        HEALTH_STATUS=1
        return 1
    fi
}

# Check network connectivity
check_network_connectivity() {
    log_info "Testing network connectivity..."
    
    # Check if slape-net exists
    if docker network ls | grep -q "slape-net"; then
        log_success "slape-net network exists"
    else
        log_error "slape-net network not found"
        HEALTH_STATUS=1
        return 1
    fi
    
    # Check if containers are on the network
    local containers_on_network=$(docker network inspect slape-net --format='{{range .Containers}}{{.Name}} {{end}}')
    log_info "Containers on slape-net: $containers_on_network"
    
    return 0
}

# Check volume mounts
check_volumes() {
    log_info "Checking volume mounts..."
    
    local volumes=("slapenir-ca-config" "slapenir-proxy-certs" "slapenir-agent-workspace" "slapenir-agent-certs")
    
    for volume in "${volumes[@]}"; do
        if docker volume ls | grep -q "$volume"; then
            log_success "Volume $volume exists"
        else
            log_warning "Volume $volume not found"
        fi
    done
    
    return 0
}

# Check if prometheus is scraping metrics
check_prometheus() {
    log_info "Testing Prometheus..."
    
    if check_container_running "slapenir-prometheus"; then
        if curl -f -s http://localhost:9090/-/healthy > /dev/null 2>&1; then
            log_success "Prometheus is healthy"
            return 0
        else
            log_warning "Prometheus may not be ready yet"
            return 1
        fi
    else
        log_info "Prometheus is not running (optional)"
        return 0
    fi
}

# Check if Grafana is accessible
check_grafana() {
    log_info "Testing Grafana..."
    
    if check_container_running "slapenir-grafana"; then
        if curl -f -s http://localhost:3001/api/health > /dev/null 2>&1; then
            log_success "Grafana is healthy"
            return 0
        else
            log_warning "Grafana may not be ready yet"
            return 1
        fi
    else
        log_info "Grafana is not running (optional)"
        return 0
    fi
}

# Main health check routine
main() {
    echo ""
    echo "======================================================================"
    echo "  SLAPENIR Container Health Check"
    echo "======================================================================"
    echo ""
    
    # Core services (required)
    echo "Checking Core Services..."
    echo "----------------------------------------------------------------------"
    check_container_running "slapenir-ca"
    check_container_health "slapenir-ca"
    check_stepca_health
    echo ""
    
    check_container_running "slapenir-proxy"
    check_container_health "slapenir-proxy"
    check_proxy_http
    check_proxy_metrics
    echo ""
    
    check_container_running "slapenir-agent"
    check_container_health "slapenir-agent"
    check_agent_python
    check_agent_credentials
    echo ""
    
    # Connectivity tests
    echo "Checking Connectivity..."
    echo "----------------------------------------------------------------------"
    check_network_connectivity
    check_agent_proxy_connectivity
    echo ""
    
    # Infrastructure
    echo "Checking Infrastructure..."
    echo "----------------------------------------------------------------------"
    check_volumes
    echo ""
    
    # Optional services
    echo "Checking Optional Services..."
    echo "----------------------------------------------------------------------"
    check_prometheus
    check_grafana
    echo ""
    
    # Summary
    echo "======================================================================"
    if [ $HEALTH_STATUS -eq 0 ]; then
        log_success "All health checks passed!"
        echo "======================================================================"
        exit 0
    else
        log_error "Some health checks failed!"
        echo "======================================================================"
        exit 1
    fi
}

# Run main function
main