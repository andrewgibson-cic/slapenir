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
