# SLAPENIR Makefile
# Minimal commands for essential operations

.PHONY: up down restart status logs shell test rebuild clean

# Default: show available commands
help:
	@echo "Usage: make <command>"
	@echo ""
	@echo "  up       Start services"
	@echo "  down     Stop services"
	@echo "  logs     Follow logs (all or: make logs SERVICE=proxy)"
	@echo "  shell    Open shell in agent (or: make shell SERVICE=proxy)"
	@echo "  test     Run all tests"
	@echo "  rebuild  Rebuild from scratch"
	@echo "  clean    Remove containers and volumes"
	@echo ""

up:
	docker compose up -d

down:
	docker compose down

restart:
	docker compose restart

status:
	docker compose ps

logs:
	docker compose logs -f $(SERVICE)

shell:
	docker compose exec $(or $(SERVICE),agent) /bin/bash 2>/dev/null || \
	docker compose exec $(or $(SERVICE),agent) /bin/sh

test:
	cd proxy && cargo test --all

rebuild:
	docker compose down
	docker compose build --no-cache
	docker compose up -d

clean:
	docker compose down -v --rmi local
