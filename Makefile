# SLAPENIR Makefile
# Minimal commands for essential operations

.PHONY: up down restart status logs shell shell-unrestricted shell-raw test rebuild clean

# Default: show available commands
help:
	@echo "Usage: make <command>"
	@echo ""
	@echo "  up                Start services"
	@echo "  down              Stop services"
	@echo "  logs              Follow logs (all or: make logs SERVICE=proxy)"
	@echo "  shell              Open shell in agent (or: make shell SERVICE=proxy)"
	@echo "  shell-unrestricted Open shell with direct internet access (bypasses proxy)"
	@echo "  shell-raw          Open raw shell bypassing all config (for debugging)"
	@echo "  test              Run all tests"
	@echo "  rebuild           Rebuild from scratch"
	@echo "  clean             Remove containers and volumes"
	@echo ""

up:
	docker-compose up -d

down:
	docker-compose down --remove-orphans

restart:
	docker-compose restart

status:
	docker-compose ps

logs:
	docker-compose logs -f $(SERVICE)

shell:
	@exec docker-compose exec \
		-u agent \
		-e GRADLE_ALLOW_FROM_OPENCODE=1 \
		-e MVN_ALLOW_FROM_OPENCODE=1 \
		-e NPM_ALLOW_FROM_OPENCODE=1 \
		-e YARN_ALLOW_FROM_OPENCODE=1 \
		-e PNPM_ALLOW_FROM_OPENCODE=1 \
		-e CARGO_ALLOW_FROM_OPENCODE=1 \
		-e PIP_ALLOW_FROM_OPENCODE=1 \
		-e PIP3_ALLOW_FROM_OPENCODE=1 \
		$(or $(SERVICE),agent) /bin/bash 2>/dev/null || \
	exec docker-compose exec -u agent $(or $(SERVICE),agent) /bin/sh

shell-unrestricted:
	@echo "🔓 Flushing iptables rules for unrestricted network access..."
	@docker-compose exec -T agent bash -c 'iptables -F TRAFFIC_ENFORCE 2>/dev/null; iptables -F OUTPUT 2>/dev/null; iptables -X TRAFFIC_ENFORCE 2>/dev/null' || true
	@exec docker-compose exec \
		-u agent \
		-e ALLOW_BUILD=1 \
		-e GRADLE_ALLOW_FROM_OPENCODE=1 \
		-e MVN_ALLOW_FROM_OPENCODE=1 \
		-e NPM_ALLOW_FROM_OPENCODE=1 \
		-e YARN_ALLOW_FROM_OPENCODE=1 \
		-e PNPM_ALLOW_FROM_OPENCODE=1 \
		-e CARGO_ALLOW_FROM_OPENCODE=1 \
		-e PIP_ALLOW_FROM_OPENCODE=1 \
		-e PIP3_ALLOW_FROM_OPENCODE=1 \
		-e HTTP_PROXY= \
		-e HTTPS_PROXY= \
		-e http_proxy= \
		-e https_proxy= \
		-e NO_PROXY= \
		-e no_proxy= \
		-e GRADLE_OPTS= \
		-e JAVA_OPTS= \
		$(or $(SERVICE),agent) /bin/bash 2>/dev/null || \
	exec docker-compose exec -u agent $(or $(SERVICE),agent) /bin/sh

shell-raw:
	@echo "⚠️  This will flush iptables rules and disable network restrictions"
	@echo "⚠️  Container will have direct internet access"
	@docker-compose exec -T agent bash -c 'iptables -F TRAFFIC_ENFORCE 2>/dev/null; iptables -F OUTPUT 2>/dev/null; iptables -X TRAFFIC_ENFORCE 2>/dev/null' || true
	@exec docker-compose exec \
		-u agent \
		-e ALLOW_BUILD=1 \
		-e GRADLE_ALLOW_FROM_OPENCODE=1 \
		-e MVN_ALLOW_FROM_OPENCODE=1 \
		-e NPM_ALLOW_FROM_OPENCODE=1 \
		-e YARN_ALLOW_FROM_OPENCODE=1 \
		-e PNPM_ALLOW_FROM_OPENCODE=1 \
		-e CARGO_ALLOW_FROM_OPENCODE=1 \
		-e PIP_ALLOW_FROM_OPENCODE=1 \
		-e PIP3_ALLOW_FROM_OPENCODE=1 \
		-e HTTP_PROXY= \
		-e HTTPS_PROXY= \
		-e http_proxy= \
		-e https_proxy= \
		-e NO_PROXY= \
		-e no_proxy= \
		-e GRADLE_OPTS= \
		-e JAVA_OPTS= \
		$(or $(SERVICE),agent) /bin/bash --norc --noprofile 2>/dev/null || \
	exec docker-compose exec -u agent $(or $(SERVICE),agent) /bin/sh

test:
	cd proxy && cargo test --all

rebuild:
	docker-compose down
	docker-compose build --no-cache
	docker-compose up -d

clean:
	docker-compose down -v --rmi local
