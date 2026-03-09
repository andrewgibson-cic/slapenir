# SLAPENIR Makefile
# Minimal commands for essential operations

# Terminal size detection with multiple fallback methods
# Method 1: Try stty (most reliable when TTY available)
TERM_HEIGHT := $(shell stty size < /dev/tty 2>/dev/null | awk '{print $$1}')
TERM_WIDTH  := $(shell stty size < /dev/tty 2>/dev/null | awk '{print $$2}')

# Method 2: Try tput if stty failed
ifeq ($(TERM_WIDTH),)
    TERM_WIDTH := $(shell tput cols 2>/dev/null)
endif
ifeq ($(TERM_HEIGHT),)
    TERM_HEIGHT := $(shell tput lines 2>/dev/null)
endif

# Method 3: Fallback to standard size
ifeq ($(TERM_WIDTH),)
    TERM_WIDTH := 80
endif
ifeq ($(TERM_HEIGHT),)
    TERM_HEIGHT := 24
endif

# Debug info
$(info Terminal size detected: $(TERM_WIDTH)x$(TERM_HEIGHT))

# Default: show available commands
help:
	@echo "Usage: make <command>"
	@echo ""
	@echo "  up       Start services"
	@echo "  down     Stop services"
	@echo "  logs     Follow logs (all or: make logs SERVICE=proxy)"
	@echo "  shell    Open shell in agent (recommended: use ./dev.sh bash)"
	@echo "  diagnose Diagnose terminal size issues"
	@echo "  test     Run all tests"
	@echo "  rebuild  Rebuild from scratch"
	@echo "  clean    Remove containers and volumes"
	@echo ""
	@echo "Recommended usage:"
	@echo "  ./dev.sh bash      # Interactive shell with internet access"
	@echo "  ./dev.sh opencode  # OpenCode with network isolation"
	@echo ""

up:
	docker-compose up -d

down:
	docker-compose down

restart:
	docker-compose restart

status:
	docker-compose ps

logs:
	docker-compose logs -f $(SERVICE)

shell:
	@echo "=========================================="
	@echo "Opening SLAPENIR agent shell"
	@echo "=========================================="
	@echo "Using dev.sh for consistent terminal sizing and network access"
	@echo ""
	@exec ./dev.sh bash

test:
	cd proxy && cargo test --all

diagnose:
	@echo "=========================================="
	@echo "Terminal Size Diagnostic"
	@echo "=========================================="
	@echo ""
	@echo "Host Environment:"
	@echo "  stty size: $$(stty size < /dev/tty 2>/dev/null || echo 'FAILED')"
	@echo "  tput cols: $$(tput cols 2>/dev/null || echo 'FAILED')"
	@echo "  tput lines: $$(tput lines 2>/dev/null || echo 'FAILED')"
	@echo "  COLUMNS env: $${COLUMNS:-<not set>}"
	@echo "  LINES env: $${LINES:-<not set>}"
	@echo "  TERM: $${TERM:-<not set>}"
	@echo ""
	@echo "Makefile Detection:"
	@echo "  TERM_WIDTH: $(TERM_WIDTH)"
	@echo "  TERM_HEIGHT: $(TERM_HEIGHT)"
	@echo ""
	@echo "Container Test:"
	@docker-compose exec -T -u agent \
		-e COLUMNS=$(TERM_WIDTH) \
		-e LINES=$(TERM_HEIGHT) \
		-e TERM \
		agent bash -c 'echo "  Container COLUMNS: $${COLUMNS:-<not set>}"; echo "  Container LINES: $${LINES:-<not set>}"; echo "  stty size: $$(stty size 2>/dev/null || echo "FAILED - no TTY")"; echo "  tput cols: $$(tput cols 2>/dev/null || echo "FAILED")"; echo "  tput lines: $$(tput lines 2>/dev/null || echo "FAILED")"'
	@echo ""
	@echo "To run full diagnostics inside container:"
	@echo "  make shell"
	@echo "  bash /home/agent/scripts/check-terminal-size.sh"
	@echo "  bash /tmp/diagnose-terminal-size.sh"

rebuild:
	docker-compose down
	docker-compose build --no-cache
	docker-compose up -d

clean:
	@echo "Cleaning all slapenir resources..."
	docker-compose down --remove-orphans || true
	@docker ps -a -q --filter "name=slapenir-" | xargs -r docker rm -f 2>/dev/null || true
	docker network rm slape-net 2>/dev/null || true
	@docker images --format '{{.Repository}}:{{.Tag}}' | grep -E '^slapenir-' | xargs -r docker rmi -f 2>/dev/null || true
	@docker volume ls -q | grep -E '^slapenir-' | xargs -r docker volume rm 2>/dev/null || true
	@echo "Clean complete."