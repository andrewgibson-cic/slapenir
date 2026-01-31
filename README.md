# SLAPENIR

**Secure LLM Agent Proxy Environment: Network Isolation & Resilience**

A zero-knowledge credential sanitization proxy for AI agents, providing network isolation and automatic secret management.

## 🎯 Overview

SLAPENIR is a security-focused proxy system that sits between AI agents and external APIs, automatically:
- **Injecting** real credentials into outbound requests
- **Sanitizing** secrets from inbound responses
- **Isolating** agents in a controlled network environment
- **Supervising** agent processes with automatic restart

This enables AI agents to make API calls without ever seeing real credentials, dramatically reducing the attack surface.

## 🏗️ Architecture

```
┌──────────────┐
│  step-ca     │ Certificate Authority
│  :9000       │
└──────────────┘
       │
       │ mTLS
       ↓
┌──────────────┐     ┌──────────────┐
│ prometheus   │────▶│  grafana     │
│  :9090       │     │  :3001       │
└──────────────┘     └──────────────┘
       ▲
       │ /metrics
       │
┌──────┴───────┐
│  proxy       │ Rust Sanitizing Gateway + Monitoring
│  :3000       │ • Aho-Corasick pattern matching O(N)
│              │ • Zero-knowledge credential handling
│              │ • Memory-safe with Zeroize trait
│              │ • Prometheus metrics instrumentation
└──────┬───────┘
       │
       │ mTLS
       ↓
┌──────────────┐
│  agent       │ Wolfi Python Environment  
│  Python 3.11 │ • s6-overlay supervision
│              │ • glibc for PyTorch/ML libraries
│              │ • Network-isolated workspace
│              │ • mTLS client
└──────────────┘
```

## 🚀 Quick Start

### Prerequisites

- **Docker Desktop** (v27+) - [Download](https://www.docker.com/products/docker-desktop)
- **Docker Compose** (v2.24+) - Included with Docker Desktop
- **Git** - For cloning the repository

### 1. Configure Environment Variables

First, set up your API keys and secrets:

```bash
# Copy the environment template
cp .env.example .env

# Edit .env with your real API keys
# nano .env  # or use your favorite editor
```

**Required variables** (at minimum):
- `OPENAI_API_KEY` - For OpenAI API access
- `ANTHROPIC_API_KEY` - For Claude API access

See `.env.example` for all available configuration options.

**⚠️ Security Note:** Never commit your `.env` file to version control! It's already in `.gitignore`.

### 2. Start SLAPENIR 🚀

Use the simple control script for all operations:

```bash
# Start everything (one command!)
./slapenir start
```

**That's it!** The script automatically:
1. ✅ Checks for .env file (creates from template if missing)
2. 🔐 Generates mTLS certificates (if needed)
3. 🚀 Builds and starts all services
4. 🏥 Verifies health of all components
5. 📊 Displays access URLs

> 💡 **Tip**: The entire setup takes ~2-3 minutes on first run (includes building Docker images)

### 3. Common Operations ⚡

```bash
# Check status and health
./slapenir status

# Access containers
./slapenir shell          # Open shell in agent (default)
./slapenir shell agent    # Open shell in agent
./slapenir shell proxy    # Open shell in proxy

# View logs (all services)
./slapenir logs

# View specific service logs
./slapenir logs proxy
./slapenir logs agent

# Restart everything
./slapenir restart

# Stop all services
./slapenir stop

# Clean everything (removes volumes)
./slapenir clean
```

**Using Make (Alternative):**

```bash
make help           # Show all commands
make start          # Start services
make shell          # Shell into agent
make shell-proxy    # Shell into proxy
make logs-agent     # View agent logs
make test           # Run all tests
```

### Manual Setup (Alternative)

```bash
# If you prefer docker-compose directly
docker-compose up -d --build
docker-compose logs -f
docker-compose down
```

### Access Your Instance

| Service | URL | Credentials |
|---------|-----|-------------|
| **Proxy** | http://localhost:3000 | N/A |
| **Health** | http://localhost:3000/health | N/A |
| **Metrics** | http://localhost:3000/metrics | N/A |
| **Prometheus** | http://localhost:9090 | N/A |
| **Grafana** | http://localhost:3001 | admin/admin |

### 4. Monitor & Debug 📊

**View Logs:**
```bash
./slapenir logs              # All services
./slapenir logs proxy        # Proxy only
./slapenir logs agent        # Agent only
make logs                    # Alternative
```

**Monitor Metrics:**
```bash
# Raw metrics (CLI)
curl http://localhost:3000/metrics

# Prometheus UI (queries & graphs)
open http://localhost:9090

# Grafana Dashboards (visual)
open http://localhost:3001    # admin/admin
```

**Health & Status:**
```bash
./slapenir status            # Service health check
curl http://localhost:3000/health
```

**Useful Prometheus Queries:**
- Request rate: `rate(slapenir_http_requests_total[5m])`
- Error rate: `rate(slapenir_http_requests_total{status=~"5.."}[5m])`
- Secrets sanitized: `rate(slapenir_secrets_sanitized_total[1m]) * 60`

**Run Tests:**
```bash
./test-system.sh             # All tests
make test                    # Alternative
```

### Stop Services

```bash
# Stop (keeps data)
docker-compose down

# Stop and remove volumes
docker-compose down -v
```

---

## 🎯 Quickstart: Make Commands Reference

SLAPENIR provides a comprehensive `Makefile` for easy management. All commands are documented below.

### 📋 View All Commands

```bash
make help
# Displays all available commands with descriptions
```

### 🚀 Setup & Control

**Start all services:**
```bash
make start
# Equivalent to: ./slapenir start
# Starts: CA, proxy, agent, Prometheus, Grafana
# Takes ~2-3 minutes on first run (builds images)
```

**Stop all services:**
```bash
make stop
# Gracefully stops all containers
# Preserves data in Docker volumes
```

**Restart all services:**
```bash
make restart
# Useful after: configuration changes, .env updates
# Performs: make stop && make start
```

**Check service status:**
```bash
make status
# Shows: container name, status, health check results
# Verifies all services are running correctly
```

**Rebuild containers:**
```bash
make build
# Use after: Dockerfile changes, dependency updates
# Rebuilds Docker images without starting services
```

**Clean everything:**
```bash
make clean
# ⚠️ WARNING: Removes all containers, volumes, and data
# Use when: starting completely fresh, troubleshooting issues
```

### 🔍 Container Access

**Open shell in agent (default):**
```bash
make shell
# or
make shell-agent

# Opens /bin/sh in agent container
# Useful for: testing scripts, Git operations, debugging Python code
```

**Open shell in proxy:**
```bash
make shell-proxy

# Opens /bin/sh in Rust proxy container
# Useful for: checking logs, debugging, inspecting configuration
```

**Example shell session:**
```bash
$ make shell
Opening shell in agent container...
/home/agent/workspace $ python3 --version
Python 3.11.x
/home/agent/workspace $ git config --list
user.name=SLAPENIR Agent
credential.helper=/home/agent/scripts/git-credential-helper.sh
```

### 📊 Logs & Debugging

**View all service logs:**
```bash
make logs
# Follows logs from all containers in real-time
# Press Ctrl+C to exit
# Shows: proxy, agent, CA, Prometheus, Grafana logs
```

**View proxy logs:**
```bash
make logs-proxy
# Shows: HTTP requests, secret operations, mTLS activity, errors
# Useful for: debugging request flow, monitoring sanitization
```

**View agent logs:**
```bash
make logs-agent
# Shows: process supervision, Git setup, health checks, Python output
# Useful for: debugging scripts, verifying Git configuration
```

**Log patterns to watch for:**
```bash
# Success patterns
✅ Git credentials configured successfully
✅ GitHub token valid (authenticated as: username)
✅ mTLS enabled
✅ Health check passed

# Warning patterns  
⚠️ GITHUB_TOKEN not set
⚠️ Token validation failed
⚠️ Certificate expires soon

# Error patterns
❌ Failed to connect to proxy
❌ Certificate not found
❌ Authentication failed
```

### 🧪 Testing

**Run all tests:**
```bash
make test
# Runs: proxy tests (Rust) + agent tests (Python) + integration tests
# 105 total tests (57 proxy, 32 agent, 16 mTLS)
# Takes ~30 seconds
```

**Run proxy tests only:**
```bash
make test-proxy
# Runs Rust test suite with cargo test
# 57 tests covering: sanitization, injection, mTLS, metrics
```

**Run agent tests only:**
```bash
make test-agent
# Runs Python test suite
# 32 tests covering: supervision, health checks, process management
```

---

## 🔐 Git Operations in Agent (Optional Feature)

The SLAPENIR agent supports **secure Git operations** (clone, pull, push, commit) using **GitHub Personal Access Tokens (PATs)** instead of SSH keys for enhanced security.

### Why PATs Instead of SSH Keys?

**Security & Operational Advantages:**

| Feature | PATs (HTTPS) ✅ | SSH Keys ⚠️ |
|---------|----------------|-------------|
| **Security scope** | Repository-specific permissions | Full account access |
| **Revocation** | Instant via GitHub UI | Manual key removal from systems |
| **Rotation** | Update `.env`, restart container | Rebuild containers, update file mounts |
| **Storage** | Environment variable (ephemeral) | File mounting (persistent risk) |
| **Audit trail** | Full GitHub activity logging | Limited visibility |
| **Leakage risk** | Low (not in image layers) | High (persistent files, image history) |
| **Complexity** | Simple HTTPS URLs | SSH config, key permissions, known_hosts |
| **Multi-repo** | One token for multiple repos | One key per repo or shared risk |

### Git Setup Instructions

#### Step 1: Generate GitHub Personal Access Token

1. Visit [GitHub Settings → Tokens (Fine-grained)](https://github.com/settings/tokens?type=beta)
2. Click **"Generate new token"**
3. Configure token settings:
   - **Token name**: `slapenir-agent-token`
   - **Expiration**: 90 days (recommended for security)
   - **Repository access**: Select specific repositories the agent needs access to
   - **Permissions** (Repository permissions):
     - ✅ **Contents**: Read and Write (required for clone/pull/push)
     - ✅ **Metadata**: Read (required by GitHub)
     - ✅ **Pull requests**: Read and Write (optional, if managing PRs)
     - ✅ **Workflows**: Read and Write (optional, if managing GitHub Actions)
4. Click **"Generate token"** and **copy it immediately** (shown only once!)

**Token format:** `ghp_xxxxxxxxxxxxxxxxxxxx` (starts with `ghp_`)

#### Step 2: Add to Environment Configuration

Edit your `.env` file and add:

```bash
# Git Configuration (Optional - for agent Git operations)
GITHUB_TOKEN=ghp_your_actual_token_here
GIT_USER_NAME=SLAPENIR Agent
GIT_USER_EMAIL=agent@slapenir.local

# Optional: Additional Git settings
GIT_CONVERT_SSH_TO_HTTPS=true    # Auto-convert SSH URLs to HTTPS
VALIDATE_GITHUB_TOKEN=true        # Validate token at container startup
```

**Security Note:** The `.env` file is already in `.gitignore` - never commit it!

#### Step 3: Restart Agent Container

```bash
# Option 1: Restart just the agent
docker-compose restart agent

# Option 2: Restart everything with make
make restart

# Option 3: Restart everything with slapenir script
./slapenir restart
```

**No rebuild required!** Tokens are injected at runtime via environment variables.

#### Step 4: Verify Git Configuration

```bash
# Check agent logs for Git setup confirmation
make logs-agent | grep -A 5 "Git credentials"

# Expected output:
# 🔧 Configuring Git credentials for SLAPENIR Agent...
# 📝 Setting up credential helper...
# ✅ Git identity configured: SLAPENIR Agent <agent@slapenir.local>
# ✅ SSH to HTTPS conversion enabled
# 🔍 Validating GitHub token...
# ✅ GitHub token valid (authenticated as: your-username)
# 🚀 Ready for Git operations (clone, pull, push, etc.)
```

### Using Git in Agent Container

Once configured, all Git operations work transparently with the PAT:

```bash
# Open shell in agent
make shell

# Clone repository (HTTPS)
git clone https://github.com/user/repo.git

# Clone with SSH URL (automatically converted to HTTPS)
git clone git@github.com:user/repo.git

# Navigate and make changes
cd repo
echo "update from agent" > file.txt
git add file.txt
git commit -m "Update from SLAPENIR agent"

# Push changes (uses PAT automatically - no password prompt!)
git push origin main

# Pull latest changes
git pull origin main

# Check status
git status

# All Git operations use the PAT transparently!
```

### Security Best Practices for Git Tokens

1. **Use Fine-Grained PATs** - Never use classic tokens (they have broader permissions)
2. **Minimum Permissions** - Only grant repository-specific access needed for the task
3. **Set Expiration** - Maximum 90 days, rotate tokens regularly (quarterly recommended)
4. **Monitor Usage** - Regularly check token activity at [GitHub Settings → Tokens](https://github.com/settings/tokens)
5. **Revoke if Compromised** - Instant revocation via GitHub UI, then generate new token
6. **Never Commit Tokens** - Always use `.env` file (already in `.gitignore`)
7. **Audit Access** - Review "Recent Activity" for each token on GitHub

### Token Rotation Procedure

When your token expires or needs rotation:

```bash
# 1. Generate new token on GitHub (follow Step 1 above)

# 2. Update .env file with new token
GITHUB_TOKEN=ghp_new_token_here

# 3. Restart agent container (no rebuild needed!)
docker-compose restart agent

# 4. Verify new token works
make logs-agent | grep "GitHub token valid"
# Expected: ✅ GitHub token valid (authenticated as: username)
```

**Pro tip:** Set a calendar reminder 1 week before token expiration!

### Troubleshooting Git Operations

**Problem: Token not working / Authentication failed**
```bash
# Symptoms: 
# - "remote: Support for password authentication was removed"
# - "fatal: Authentication failed for 'https://github.com/...'"

# Solutions:
# 1. Verify token is set in environment
make shell
env | grep GITHUB_TOKEN

# 2. Check token hasn't expired on GitHub
# Visit: https://github.com/settings/tokens

# 3. Ensure token has correct permissions
# Required: Contents (Read & Write), Metadata (Read)

# 4. Check token format
# Should start with: ghp_, gho_, ghu_, ghs_, or ghr_
```

**Problem: Token validation fails at startup**
```bash
# Symptoms:
# - "❌ GitHub token validation failed (HTTP 401)"
# - Agent starts but Git operations fail

# Solutions:
# 1. Verify token format is correct (starts with ghp_)
# 2. Check token not expired: https://github.com/settings/tokens
# 3. Regenerate token if necessary
# 4. Temporarily disable validation (troubleshooting only):
#    VALIDATE_GITHUB_TOKEN=false in .env
```

**Problem: Wrong git user appears in commits**
```bash
# Symptoms:
# - Commits showing "root <root@localhost>"
# - Commits not attributed to correct user

# Solution: Set Git identity in .env
GIT_USER_NAME=Your Name
GIT_USER_EMAIL=your.email@example.com

# Then restart agent:
docker-compose restart agent
```

**Problem: SSH URLs not converting to HTTPS**
```bash
# Symptoms:
# - "git@github.com: Permission denied (publickey)"
# - SSH clone attempts fail

# Solution: Ensure SSH to HTTPS conversion is enabled
# In .env:
GIT_CONVERT_SSH_TO_HTTPS=true

# Verify in container:
make shell
git config --get url."https://github.com/".insteadOf
# Expected output: git@github.com:
```

---
## 📦 Components

### Proxy (Rust)
- **Location**: `proxy/`
- **Ports**: 3000 (HTTP), /metrics endpoint
- **Features**:
  - Aho-Corasick streaming sanitization
  - Secret injection/replacement
  - mTLS support with certificate management
  - Prometheus metrics instrumentation
  - Health check endpoint
  - 57/57 tests passing (82% coverage)
  - Memory-safe with Zeroize

### Agent (Python)
- **Location**: `agent/`
- **Environment**: Wolfi Linux + Python 3.11
- **Features**:
  - s6-overlay process supervision
  - Graceful shutdown handling
  - mTLS client implementation
  - Proxy health checks
  - 32/32 tests passing (85% coverage)
  - glibc compatibility for ML libraries

### Certificate Authority (Step-CA)
- **Location**: `step-ca` container
- **Port**: 9000 (internal)
- **Status**: ✅ Fully operational
- **Features**:
  - Automated certificate generation
  - Certificate rotation support
  - Read-only certificate mounts

### Monitoring Stack
- **Prometheus**: `:9090` - Metrics collection and storage
- **Grafana**: `:3001` - Visualization dashboards (admin/admin)
- **Features**: 13 metric types, system overview dashboard, auto-provisioned

## 🧪 Testing

### Test Coverage: 82% (105 Tests Passing)

**Comprehensive test suite with 105 tests covering:**
- ✅ 57 Proxy tests (Rust)
- ✅ 32 Agent tests (Python)
- ✅ 16 mTLS end-to-end tests
- ✅ 800+ property-based test cases
- ✅ Performance benchmarks validated
- ✅ Security threats tested
- ✅ Thread safety proven

See [TEST_REPORT.md](docs/TEST_REPORT.md) for detailed coverage analysis.

### Quick Test Commands

```bash
# Run all tests
./test-system.sh

# Proxy tests (Rust)
cd proxy
cargo test                              # All tests (57)
cargo test --test integration_test      # Integration tests (6)
cargo test --test property_test         # Property tests (14 + 800 cases)
cargo test -- --nocapture               # With output
cargo test metrics                      # Metrics tests (5)

# Agent tests (Python)
python3 agent/tests/test_agent.py       # Basic tests (7)
python3 agent/tests/test_agent_advanced.py  # Advanced tests (25)

# Validate system
docker compose config                   # Validate compose file

# mTLS tests (requires running system)
./scripts/test-mtls.sh                  # 16 E2E tests
```

### Test Categories

| Category | Tests | Coverage | Status |
|----------|-------|----------|--------|
| Unit Tests | 57 | 82% | ✅ |
| Integration Tests | 6 | 100% | ✅ |
| Property Tests | 14 (800+ cases) | N/A | ✅ |
| Agent Tests | 32 | 85% | ✅ |
| mTLS E2E Tests | 16 | 100% | ✅ |
| **Total** | **105** | **82%** | **✅** |

### Performance Benchmarks

```bash
# Tested and validated:
✅ Injection: <10ms for 10,000 tokens
✅ Sanitization: <10ms for 10,000 tokens  
✅ Thread safety: 10 concurrent operations
✅ Large inputs: <100ms for 10,000 tokens
✅ Test execution: <1 second total
```

## 📊 Project Status

- **Overall Progress**: 90% Complete ✅
- **Core Functionality**: FULLY OPERATIONAL
- **Phase 0** (Prerequisites): ✅ 100% Complete
- **Phase 1** (Identity/Network): ✅ 100% Complete
- **Phase 2** (Proxy Core): ✅ 100% Complete
- **Phase 3** (Agent Environment): ✅ 100% Complete
- **Phase 4** (mTLS Security): ✅ 100% Complete
- **Phase 5** (Chaos Testing): ✅ 100% Complete
- **Phase 6** (Monitoring): ✅ 100% Complete
- **Phase 7** (Strategy Pattern): ✅ 100% Complete
- **Phase 8** (Code Quality): ✅ 100% Complete
- **Phase 9** (Strategy Integration): ✅ 100% Complete ← NEW!

### 🎯 Recent Achievements
- ✅ **Phase 9**: Strategy pattern integrated into main application
- ✅ YAML configuration system operational
- ✅ AWS SigV4 strategy ready for use
- ✅ Config file loading with graceful fallback
- ✅ 7 new integration tests (56 total proxy tests)
- ✅ Gap analysis completed and documented
- ✅ Full mTLS implementation (Rust + Python)
- ✅ Automated certificate management
- ✅ Chaos testing framework (5 scenarios)
- ✅ Prometheus + Grafana monitoring
- ✅ Metrics fully instrumented (49/49 tests passing)

See [PROGRESS.md](docs/PROGRESS.md), [GAP_ANALYSIS.md](docs/GAP_ANALYSIS.md), and [NEXT_STEPS.md](docs/NEXT_STEPS.md) for detailed status.

## 🔧 Development

### Running Proxy Locally

```bash
cd proxy
cargo run
```

### Running Tests

```bash
cd proxy
cargo test
cargo clippy  # linting
cargo fmt     # formatting
```

### Environment Variables

For the proxy service:
```bash
export OPENAI_API_KEY="your-key"
export ANTHROPIC_API_KEY="your-key"
```

## 📚 Documentation

- [Architecture](docs/SLAPENIR_Architecture.md) - System design and components
- [Specifications](docs/SLAPENIR_Specifications.md) - Technical requirements
- [Roadmap](docs/SLAPENIR_Roadmap.md) - Development phases
- [TDD Strategy](docs/SLAPENIR_TDD_Strategy.md) - Testing approach
- [Git Strategy](docs/SLAPENIR_Git_Strategy.md) - Commit conventions
- [Risk Analysis](docs/SLAPENIR_Risks.md) - Security considerations
- [mTLS Setup Guide](docs/mTLS_Setup.md) - Certificate management
- [Chaos Testing Guide](docs/CHAOS_TESTING.md) - Resilience testing
- [Monitoring Setup](monitoring/README.md) - Prometheus & Grafana
- [Test Report](docs/TEST_REPORT.md) - Detailed test coverage

## 🔒 Security Features

- **Zero-Knowledge**: Agents never see real credentials
- **Network Isolation**: Internal Docker network only
- **Memory Safety**: Rust's ownership model + Zeroize trait
- **Process Supervision**: Automatic restart on failure
- **mTLS Authentication**: Mutual TLS between all services
- **Certificate Automation**: Automated generation and rotation
- **Non-root Execution**: Both proxy and agent run as unprivileged users
- **Read-only Mounts**: Certificates mounted read-only
- **Secret Sanitization**: Aho-Corasick O(N) pattern matching

## 📈 Monitoring & Observability

- **Prometheus Metrics**: 13 metric types tracking HTTP requests, secret operations, connections
- **Grafana Dashboards**: Pre-configured system overview dashboard
- **Health Checks**: All services have health endpoints
- **Chaos Testing**: 5 scenarios validating resilience
- **Metrics Instrumentation**: Real-time data collection in proxy and sanitizer

## 🛣️ Roadmap

- [x] Phase 0: Prerequisites & Environment Setup
- [x] Phase 1: Network Foundation & Certificate Authority
- [x] Phase 2: Rust Proxy Core
- [x] Phase 3: Agent Environment
- [x] Phase 4: mTLS Security Implementation
- [x] Phase 5: Chaos & Resilience Testing
- [x] Phase 6: Monitoring & Observability
- [ ] Phase 7: Production Hardening (optional)

## 🤝 Contributing

This is a development project. Follow the Git strategy in [docs/SLAPENIR_Git_Strategy.md](docs/SLAPENIR_Git_Strategy.md).

### Commit Format

```
type(scope): subject

body

footer
```

Types: `feat`, `fix`, `docs`, `test`, `refactor`, `chore`

## 📝 License

MIT License - See LICENSE file for details

## 👤 Author

Andrew Gibson (andrew.gibson-cic@ibm.com)

---

**Status**: Active Development  
**Last Updated**: 2026-01-31  
**Version**: 0.9.0 (90% Complete - Strategy Pattern Integrated)
