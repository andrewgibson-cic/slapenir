# SLAPENIR Makefile
# Minimal commands for essential operations

.PHONY: up down restart status logs shell shell-unrestricted shell-raw copy-in copy-out copy-out-safe session-reset verify test rebuild clean

# Default: show available commands
help:
	@echo "Usage: make <command>"
	@echo ""
	@echo "  up                Start services"
	@echo "  down              Stop services"
	@echo "  logs              Follow logs (all or: make logs SERVICE=proxy)"
	@echo "  shell              Open shell in agent (builds blocked - use ALLOW_BUILD=1)"
	@echo "  shell-unrestricted Open shell with direct internet access (bypasses proxy)"
	@echo "  shell-raw          Open raw shell bypassing all config (for debugging)"
	@echo "  copy-in           Copy repo + tickets into container (REPO= TICKETS=)"
	@echo "  copy-out          Copy repo out with integrity check (REPO=)"
	@echo "  copy-out-safe     Copy repo out with backup of host copy first (REPO=)"
	@echo "  session-reset     Clear workspace, MCP memory, and knowledge for fresh session"
	@echo "  verify            Run pre-flight security verification (zero-knowledge + network)"
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
	@echo "🔒 Secure shell - builds blocked by default"
	@echo "   To run builds: ALLOW_BUILD=1 <command> or make shell-unrestricted"
	@exec docker-compose exec \
		-u agent \
		$(or $(SERVICE),agent) /bin/bash 2>/dev/null || \
	exec docker-compose exec -u agent $(or $(SERVICE),agent) /bin/sh

shell-unrestricted:
	@echo "🔓 Flushing iptables rules for unrestricted network access..."
	@docker-compose exec -T -u root agent bash -c 'iptables -F TRAFFIC_ENFORCE 2>/dev/null; iptables -X TRAFFIC_ENFORCE 2>/dev/null; iptables -t nat -F TRAFFIC_REDIRECT 2>/dev/null; iptables -t nat -D OUTPUT -j TRAFFIC_REDIRECT 2>/dev/null || true' || true
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
	@docker-compose exec -T -u root agent bash -c 'iptables -F TRAFFIC_ENFORCE 2>/dev/null; iptables -X TRAFFIC_ENFORCE 2>/dev/null; iptables -t nat -F TRAFFIC_REDIRECT 2>/dev/null; iptables -t nat -D OUTPUT -j TRAFFIC_REDIRECT 2>/dev/null || true' || true
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

copy-in:
ifndef REPO
	$(error REPO is required - usage: make copy-in REPO=/path/to/repo TICKETS=/path/to/tickets)
endif
	@echo "Copying repo into container..."
	docker-compose exec -T agent mkdir -p /home/agent/workspace/$(notdir $(REPO))
	docker cp "$(REPO)" slapenir-agent:/home/agent/workspace/$(notdir $(REPO))
ifdef TICKETS
	@echo "Copying tickets into container..."
	docker-compose exec -T agent mkdir -p /home/agent/workspace/tickets
	docker cp "$(TICKETS)/." slapenir-agent:/home/agent/workspace/tickets/
endif
	@echo "Copy-in complete"

copy-out:
ifndef REPO
	$(error REPO is required - usage: make copy-out REPO=/path/to/repo)
endif
	@echo "Running integrity check..."
	@docker-compose exec -T -u agent agent bash -c 'cd /home/agent/workspace/$(notdir $(REPO)) && echo "=== Changed files ===" && git status --porcelain && echo "=== Diff stat ===" && git diff --stat'
	@echo "Copying repo out of container..."
	docker cp slapenir-agent:/home/agent/workspace/$(notdir $(REPO)) "$(dir $(REPO))"
	@echo "Copy-out complete"

copy-out-safe:
ifndef REPO
	$(error REPO is required - usage: make copy-out-safe REPO=/path/to/repo)
endif
	@echo "Backing up host repo..."
	@cp -r "$(REPO)" "$(REPO).backup.$(shell date +%Y%m%d%H%M%S)"
	@echo "Backup created at $(REPO).backup.*"
	@$(MAKE) copy-out REPO=$(REPO)

session-reset:
	@echo "Clearing workspace for fresh session..."
	docker-compose exec -T agent bash -c 'rm -rf /home/agent/workspace/*'
	docker-compose exec -T agent bash -c 'rm -rf /home/agent/.local/share/mcp-memory/*'
	docker-compose exec -T agent bash -c 'rm -rf /home/agent/.local/share/mcp-knowledge/*'
	@echo "Session reset complete - workspace and MCP data cleared"

verify:
	@echo "Running pre-flight security verification..."
	@./scripts/verify-zero-knowledge.sh
	@./scripts/verify-local-llm-security.sh
	@echo "Pre-flight verification complete"

test:
	cd proxy && cargo test --all

rebuild:
	docker-compose down
	docker-compose build --no-cache
	docker-compose up -d

clean:
	docker-compose down -v --rmi local
