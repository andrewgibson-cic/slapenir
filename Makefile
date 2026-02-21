# SLAPENIR Makefile
# Simple, universal commands for managing SLAPENIR

.PHONY: help start stop restart status logs clean shell shell-proxy shell-agent test build rebuild rebuild-agent rebuild-proxy

# Default target - show help
help:
	@echo "SLAPENIR Control Commands"
	@echo ""
	@echo "Setup & Control:"
	@echo "  make start          - Start all services"
	@echo "  make stop           - Stop all services"
	@echo "  make restart        - Restart all services"
	@echo "  make status         - Show service status"
	@echo ""
	@echo "Access Containers:"
	@echo "  make shell          - Open bash shell in agent"
	@echo "  make shell-agent    - Open bash shell in agent container"
	@echo "  make shell-proxy    - Open shell in proxy container"
	@echo ""
	@echo "Logs & Debugging:"
	@echo "  make logs           - Follow all logs"
	@echo "  make logs-proxy     - Follow proxy logs"
	@echo "  make logs-agent     - Follow agent logs"
	@echo ""
	@echo "Testing:"
	@echo "  make test           - Run all tests"
	@echo "  make test-proxy     - Run proxy tests"
	@echo "  make test-agent     - Run agent tests"
	@echo "  make test-integration - Run integration tests"
	@echo "  make health-check   - Check container health"
	@echo ""
	@echo "Maintenance:"
	@echo "  make build          - Rebuild all containers"
	@echo "  make rebuild        - Rebuild agent + proxy from scratch"
	@echo "  make rebuild-agent  - Rebuild only agent from scratch"
	@echo "  make rebuild-proxy  - Rebuild only proxy from scratch"
	@echo "  make clean          - Remove all containers and volumes"
	@echo ""
	@echo "📖 Documentation:"
	@echo "  Quick Start:  docs/QUICK_START_AGENT.md"
	@echo "  Full Guide:   docs/AGENT_WORKFLOW.md"
	@echo "  Git Clone:    make shell, then: git clone <url>"
	@echo ""

# Start all services
start:
	@./slapenir start

# Stop all services
stop:
	@./slapenir stop

# Restart all services
restart:
	@./slapenir restart

# Show status
status:
	@./slapenir status

# View all logs
logs:
	@./slapenir logs

# View proxy logs
logs-proxy:
	@./slapenir logs proxy

# View agent logs
logs-agent:
	@./slapenir logs agent

# Open shell in agent container (default)
shell: shell-agent

# Open shell in agent container
shell-agent:
	@echo "Opening shell in agent container..."
	@docker-compose exec agent /bin/bash

# Open shell in proxy container
shell-proxy:
	@echo "Opening shell in proxy container..."
	@docker-compose exec proxy /bin/sh

# Run all tests
test:
	@./test-system.sh

# Run proxy tests
test-proxy:
	@cd proxy && cargo test

# Run agent tests
test-agent:
	@echo "Running agent shell script tests..."
	@cd agent/tests && ./run_all_tests.sh
	@echo ""
	@echo "Running agent Python tests..."
	@python3 agent/tests/test_agent.py || true
	@python3 agent/tests/test_agent_advanced.py || true

# Run security tests (verify no real credentials in agent)
test-security:
	@echo "Running security tests in agent container..."
	@docker-compose exec agent /home/agent/tests/run_security_tests.sh

# Verify security configuration
verify-security:
	@echo "Verifying security configuration..."
	@echo ""
	@echo "Checking proxy credentials..."
	@docker-compose exec proxy sh -c 'env | grep -E "(OPENAI|GITHUB|ANTHROPIC)" | head -3' || echo "  ⚠️  No credentials found in proxy"
	@echo ""
	@echo "Checking agent credentials..."
	@docker-compose exec agent sh -c 'env | grep -E "(OPENAI|GITHUB|ANTHROPIC)" | head -3' || echo "  ⚠️  No credentials found in agent"
	@echo ""
	@echo "Run 'make test-security' for comprehensive security testing"

# Rebuild containers
build:
	@docker-compose build

# Run integration tests
test-integration:
	@echo "Running integration tests..."
	@chmod +x scripts/integration-test.sh
	@./scripts/integration-test.sh

# Check container health
health-check:
	@echo "Running health checks..."
	@chmod +x scripts/health-check.sh
	@./scripts/health-check.sh

# Clean everything
clean:
	@./slapenir clean

# Rebuild agent from scratch (clears image, volumes, rebuilds)
rebuild-agent:
	@echo "🔄 Rebuilding agent container from scratch..."
	@docker-compose stop agent 2>/dev/null || true
	@docker-compose rm -f agent 2>/dev/null || true
	@docker rmi slapenir-agent 2>/dev/null || echo "  (agent image not found)"
	@docker volume rm slapenir-agent-workspace 2>/dev/null || echo "  (workspace volume not found)"
	@docker-compose build --no-cache agent
	@docker-compose up -d agent
	@echo "✅ Agent rebuild complete! Check logs with: make logs-agent"

# Rebuild proxy from scratch (clears image, rebuilds)
rebuild-proxy:
	@echo "🔄 Rebuilding proxy container from scratch..."
	@docker-compose stop proxy 2>/dev/null || true
	@docker-compose rm -f proxy 2>/dev/null || true
	@docker rmi slapenir-proxy 2>/dev/null || echo "  (proxy image not found)"
	@docker-compose build --no-cache proxy
	@docker-compose up -d proxy
	@echo "✅ Proxy rebuild complete! Check logs with: make logs-proxy"

# Rebuild both agent and proxy from scratch
rebuild:
	@echo "🔄 Rebuilding agent and proxy from scratch..."
	@docker-compose down
	@docker rmi slapenir-agent slapenir-proxy 2>/dev/null || true
	@docker volume rm slapenir-agent-workspace 2>/dev/null || true
	@docker-compose build --no-cache agent proxy
	@docker-compose up -d
	@echo "✅ Rebuild complete!"
	@echo ""
	@echo "📋 View startup validation:"
	@echo "   docker logs slapenir-agent | grep -A30 'Startup Validation'"
	@echo ""
	@echo "🔍 Verify credentials:"
	@echo "   docker exec slapenir-agent env | grep -E '(OPENAI|GITHUB|HTTP_PROXY)'"
