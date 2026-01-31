# SLAPENIR Makefile
# Simple, universal commands for managing SLAPENIR

.PHONY: help start stop restart status logs clean shell shell-proxy shell-agent test build

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
	@echo ""
	@echo "Maintenance:"
	@echo "  make build          - Rebuild all containers"
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
	@python3 agent/tests/test_agent.py
	@python3 agent/tests/test_agent_advanced.py

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

# Clean everything
clean:
	@./slapenir clean