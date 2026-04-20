# SLAPENIR Makefile
# Minimal commands for essential operations

DC := $(shell docker compose version > /dev/null 2>&1 && echo "docker compose" || echo "docker-compose")

.PHONY: up down restart status logs shell shell-proxy shell-unrestricted shell-raw copy-in copy-out copy-out-safe copy-cache index session-reset verify test rebuild clean work-start work-done

# Default: show available commands
help:
	@echo "Usage: make <command>"
	@echo ""
	@echo "  Workflow:"
	@echo "  work-start          Setup: start + copy-in + verify (index/ingest are manual)"
	@echo "  shell               Enter agent workspace (opencode, git, builds, etc.)"
	@echo "  work-done           Extract: scan + copy-out + summary (REPO=)"
	@echo ""
	@echo "  Service Management:"
	@echo "  up                  Start services"
	@echo "  down                Stop services"
	@echo "  restart             Restart services"
	@echo "  status              Show service status"
	@echo "  logs                Follow logs (all or: make logs SERVICE=proxy)"
	@echo ""
	@echo "  Shell Access:"
	@echo "  shell               Open shell in agent (builds blocked - use ALLOW_BUILD=1)"
	@echo "  shell-unrestricted  Open shell with direct internet access (bypasses proxy)"
	@echo "  shell-raw           Open raw shell bypassing all config (for debugging)"
	@echo ""
	@echo "  Data Transfer:"
	@echo "  copy-in             Copy repo + docs into container (REPO= DOCS=)"
	@echo "  copy-out            Copy repo out with integrity check (REPO=)"
	@echo "  copy-out-safe       Copy repo out with backup of host copy first (REPO=)"
	@echo "  copy-cache          Copy host build cache into container (TYPE=gradle|npm|pip|yarn|maven|all)"
	@echo ""
	@echo "  Indexing & Knowledge:"
	@echo "  index               Index repo + optionally ingest docs (REPO= [DOCS=])"
	@echo "  ingest              Ingest docs into knowledge RAG (via MCP ingest_file tool)"
	@echo ""
	@echo "  Operations:"
	@echo "  session-reset       Clear workspace, MCP memory, and knowledge for fresh session"
	@echo "  verify              Run pre-flight security verification (zero-knowledge + network)"
	@echo "  test                Run all tests"
	@echo "  rebuild             Rebuild from scratch"
	@echo "  clean               Remove containers and volumes"
	@echo ""

up:
	$(DC) up -d

down:
	$(DC) down --remove-orphans

restart:
	$(DC) restart

status:
	$(DC) ps

logs:
	$(DC) logs -f $(SERVICE)

shell:
	@echo "🔒 Secure shell - builds and internet blocked by default"
	@echo "   To run builds through proxy: ALLOW_BUILD=1 <tool> <args>"
	@echo "   For ./gradlew or scripts:    net ./gradlew <args>"
	@echo "   For unrestricted access:      make shell-unrestricted"
	@exec $(DC) exec \
		-u agent \
		$(or $(SERVICE),agent) /bin/bash 2>/dev/null || \
	exec $(DC) exec -u agent $(or $(SERVICE),agent) /bin/sh

shell-proxy:
	@exec $(DC) exec -u proxy proxy /bin/sh -c 'set -a; [ -f /home/proxy/.env.repo ] && . /home/proxy/.env.repo; set +a; exec /bin/sh'

shell-unrestricted:
	@echo "🔓 Flushing iptables rules for unrestricted network access..."
	@$(DC) exec -T -u root agent bash -c 'iptables -F TRAFFIC_ENFORCE 2>/dev/null; iptables -X TRAFFIC_ENFORCE 2>/dev/null; iptables -t nat -F TRAFFIC_REDIRECT 2>/dev/null; iptables -t nat -D OUTPUT -j TRAFFIC_REDIRECT 2>/dev/null || true' || true
	@exec $(DC) exec \
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
	exec $(DC) exec -u agent $(or $(SERVICE),agent) /bin/sh

shell-raw:
	@echo "⚠️  This will flush iptables rules and disable network restrictions"
	@echo "⚠️  Container will have direct internet access"
	@$(DC) exec -T -u root agent bash -c 'iptables -F TRAFFIC_ENFORCE 2>/dev/null; iptables -X TRAFFIC_ENFORCE 2>/dev/null; iptables -t nat -F TRAFFIC_REDIRECT 2>/dev/null; iptables -t nat -D OUTPUT -j TRAFFIC_REDIRECT 2>/dev/null || true' || true
	@exec $(DC) exec \
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
	exec $(DC) exec -u agent $(or $(SERVICE),agent) /bin/sh

copy-in:
ifndef REPO
	$(error REPO is required - usage: make copy-in REPO=/path/to/repo DOCS=/path/to/docs)
endif
	@echo "Copying repo into container..."
	$(DC) exec -T agent mkdir -p /home/agent/workspace
	docker cp "$(REPO)/." slapenir-agent:/home/agent/workspace/
	$(DC) exec -T -u root agent chown -R 1000:1000 /home/agent/workspace
ifdef DOCS
	@echo "Copying docs into container..."
	$(DC) exec -T agent mkdir -p /home/agent/workspace/docs
	docker cp "$(DOCS)/." slapenir-agent:/home/agent/workspace/docs/
	$(DC) exec -T -u root agent chown -R 1000:1000 /home/agent/workspace/docs
endif
	@echo "Copy-in complete"

copy-out:
ifndef REPO
	$(error REPO is required - usage: make copy-out REPO=/path/to/repo)
endif
	@echo "Running integrity check..."
	@$(DC) exec -T -u agent agent bash -c 'cd /home/agent/workspace/$(notdir $(REPO)) && echo "=== Changed files ===" && git status --porcelain && echo "=== Diff stat ===" && git diff --stat'
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

define COPY_CACHE_GRADLE
	if [ -d "$(HOME)/.gradle/caches" ]; then \
		echo "Copying gradle caches..."; \
		docker cp "$(HOME)/.gradle/caches/." slapenir-agent:/home/agent/.gradle/caches/; \
		$(DC) exec -T -u root agent chown -R 1000:1000 /home/agent/.gradle/caches; \
		echo "  gradle caches copied"; \
	else \
		echo "  SKIP: $(HOME)/.gradle/caches not found"; \
	fi
	if [ -d "$(HOME)/.gradle/wrapper" ]; then \
		echo "Copying gradle wrapper..."; \
		docker cp "$(HOME)/.gradle/wrapper/." slapenir-agent:/home/agent/.gradle/wrapper/; \
		$(DC) exec -T -u root agent chown -R 1000:1000 /home/agent/.gradle/wrapper; \
		echo "  gradle wrapper copied"; \
	else \
		echo "  SKIP: $(HOME)/.gradle/wrapper not found"; \
	fi
endef

define COPY_CACHE_NPM
	if [ -d "$(HOME)/.npm" ]; then \
		echo "Copying npm cache..."; \
		$(DC) exec -T agent mkdir -p /home/agent/.npm; \
		docker cp "$(HOME)/.npm/." slapenir-agent:/home/agent/.npm/; \
		$(DC) exec -T -u root agent chown -R 1000:1000 /home/agent/.npm; \
		echo "  npm cache copied"; \
	else \
		echo "  SKIP: $(HOME)/.npm not found"; \
	fi
endef

define COPY_CACHE_PIP
	if [ -d "$(HOME)/Library/Caches/pip" ]; then \
		echo "Copying pip cache (macOS)..."; \
		$(DC) exec -T agent mkdir -p /home/agent/.cache/pip; \
		docker cp "$(HOME)/Library/Caches/pip/." slapenir-agent:/home/agent/.cache/pip/; \
		$(DC) exec -T -u root agent chown -R 1000:1000 /home/agent/.cache/pip; \
		echo "  pip cache copied"; \
	elif [ -d "$(HOME)/.cache/pip" ]; then \
		echo "Copying pip cache..."; \
		$(DC) exec -T agent mkdir -p /home/agent/.cache/pip; \
		docker cp "$(HOME)/.cache/pip/." slapenir-agent:/home/agent/.cache/pip/; \
		$(DC) exec -T -u root agent chown -R 1000:1000 /home/agent/.cache/pip; \
		echo "  pip cache copied"; \
	else \
		echo "  SKIP: pip cache not found"; \
	fi
endef

define COPY_CACHE_YARN
	if [ -d "$(HOME)/Library/Caches/Yarn" ]; then \
		echo "Copying yarn cache (macOS)..."; \
		$(DC) exec -T agent mkdir -p /home/agent/.yarn/cache; \
		docker cp "$(HOME)/Library/Caches/Yarn/." slapenir-agent:/home/agent/.yarn/cache/; \
		$(DC) exec -T -u root agent chown -R 1000:1000 /home/agent/.yarn/cache; \
		echo "  yarn cache copied"; \
	elif [ -d "$(HOME)/.cache/yarn" ]; then \
		echo "Copying yarn cache..."; \
		$(DC) exec -T agent mkdir -p /home/agent/.yarn/cache; \
		docker cp "$(HOME)/.cache/yarn/." slapenir-agent:/home/agent/.yarn/cache/; \
		$(DC) exec -T -u root agent chown -R 1000:1000 /home/agent/.yarn/cache; \
		echo "  yarn cache copied"; \
	else \
		echo "  SKIP: yarn cache not found"; \
	fi
endef

define COPY_CACHE_MAVEN
	if [ -d "$(HOME)/.m2" ]; then \
		echo "Copying maven cache..."; \
		docker cp "$(HOME)/.m2/." slapenir-agent:/home/agent/.m2/; \
		$(DC) exec -T -u root agent chown -R 1000:1000 /home/agent/.m2; \
		echo "  maven cache copied"; \
	else \
		echo "  SKIP: $(HOME)/.m2 not found"; \
	fi
endef

copy-cache:
ifndef TYPE
	$(error TYPE is required - usage: make copy-cache TYPE=gradle|npm|pip|yarn|maven|all)
endif
	@echo "Copying build caches (TYPE=$(TYPE))..."
ifeq ($(TYPE),gradle)
	@$(COPY_CACHE_GRADLE)
else ifeq ($(TYPE),npm)
	@$(COPY_CACHE_NPM)
else ifeq ($(TYPE),pip)
	@$(COPY_CACHE_PIP)
else ifeq ($(TYPE),yarn)
	@$(COPY_CACHE_YARN)
else ifeq ($(TYPE),maven)
	@$(COPY_CACHE_MAVEN)
else ifeq ($(TYPE),all)
	@$(COPY_CACHE_GRADLE)
	@$(COPY_CACHE_NPM)
	@$(COPY_CACHE_PIP)
	@$(COPY_CACHE_YARN)
	@$(COPY_CACHE_MAVEN)
else
	$(error Unknown TYPE '$(TYPE)' - must be one of: gradle, npm, pip, yarn, maven, all)
endif
	@echo "Copy-cache complete"

index:
ifndef REPO
	$(error REPO is required - usage: make index REPO=/path/to/repo [DOCS=/path/to/docs])
endif
	@echo "Indexing repository for Code-Graph-RAG (project: $(notdir $(REPO)))..."
	$(DC) exec -T -u agent agent bash -c 'cgr start --repo-path /home/agent/workspace --update-graph --clean --project-name $(notdir $(REPO))'
	@echo "Index complete"
ifneq ($(DOCS),)
	@echo "Ingesting documents into knowledge RAG (DOCS= provided)..."
	$(DC) exec -T -u agent agent bash -c 'node /home/agent/scripts/ingest-via-mcp.mjs /home/agent/workspace/docs'
	@echo "Ingest complete"
endif

session-reset:
	@echo "Clearing workspace for fresh session..."
	@keys=$$(curl -s http://localhost:3000/internal/secrets/list 2>/dev/null | grep -o '"keys":\[[^]]*\]' | grep -o '"DUMMY_REPO_[^"]*"' | tr '\n' ',' | sed 's/,$$//' | sed 's/"",//g; s/""//g'); \
		if [ -n "$$keys" ]; then \
			curl -s -X DELETE http://localhost:3000/internal/secrets \
				-H "Content-Type: application/json" \
				-d "{\"keys\":[$$keys]}" >/dev/null 2>&1; \
		fi
	$(DC) exec agent bash -c 'rm -rf /home/agent/workspace/*'
	$(DC) exec agent bash -c 'rm -rf /home/agent/.local/share/mcp-memory/*'
	$(DC) exec agent bash -c 'rm -rf /home/agent/.local/share/mcp-knowledge/{*,.*} 2>/dev/null || true'
	$(DC) exec agent bash -c 'rm -f /home/agent/.env.repo'
	$(DC) exec proxy rm -f /home/proxy/.env.repo
	-rm -f .slapenir-session
	@echo "Session reset complete - workspace, secrets, MCP data, and session cleared"

verify:
	@echo "Running pre-flight security verification..."
	@./scripts/verify-zero-knowledge.sh
	@./scripts/verify-local-llm-security.sh
	@echo "Pre-flight verification complete"

test:
	cd proxy && cargo test --all

rebuild:
	$(DC) down -v --remove-orphans
	docker system prune -af --filter "label=slapenir" -f || true
	docker builder prune -af --filter "type=exec.cach*.$(or $(SERVICE),agent)*" -f || true
	$(DC) build --no-cache --pull --parallel
	$(DC) up -d
	@echo "✅ Rebuild complete - containers running"
	@$(DC) ps

clean:
	$(DC) down -v --rmi local --remove-orphans
	docker system prune -af --filter "label=slapenir" -f || true
	@echo "✅ Clean complete - all containers, volumes, and images removed"

# ============================================================================
# Workflow Targets
# ============================================================================

work-start:
ifndef REPO
	$(error REPO is required - usage: make work-start REPO=/path/to/repo DOCS=/path/to/docs)
endif
	@./slapenir init "$(REPO)" "$(or $(DOCS),)"

work-done:
ifndef REPO
	$(error REPO is required - usage: make work-done REPO=/path/to/repo)
endif
	@./slapenir done "$(REPO)"
