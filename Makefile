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
	@echo "  make shell          - Open shell in agent container (default)"
	@echo "  make shell-agent    - Open shell in agent container"
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
	@docker-compose exec agent /bin/sh

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

# Rebuild containers
build:
	@docker-compose build

# Clean everything
clean:
	@./slapenir clean