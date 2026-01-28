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
│  step-ca     │ Certificate Authority (future mTLS)
│  :9000       │
└──────────────┘

┌──────────────┐
│  proxy       │ Rust Sanitizing Gateway
│  :3000       │ • Aho-Corasick pattern matching O(N)
│              │ • Zero-knowledge credential handling
│              │ • Memory-safe with Zeroize trait
└──────┬───────┘
       │
       │ HTTP (future: mTLS)
       ↓
┌──────────────┐
│  agent       │ Wolfi Python Environment  
│  Python 3.11 │ • s6-overlay supervision
│              │ • glibc for PyTorch/ML libraries
│              │ • Network-isolated workspace
└──────────────┘
```

## 🚀 Quick Start

### Prerequisites

- Docker Desktop (v27+)
- Docker Compose (v2.24+)
- Rust 1.93+ (for local development)
- Git

### 1. Validate System

```bash
./test-system.sh
```

### 2. Start Services

```bash
# Build and start all services
docker compose up --build

# Or run in background
docker compose up --build -d
```

### 3. Verify Health

```bash
# Check proxy health
curl http://localhost:3000/health

# View logs
docker compose logs -f proxy
docker compose logs -f agent
```

### 4. Stop Services

```bash
docker compose down

# Remove volumes too
docker compose down -v
```

## 📦 Components

### Proxy (Rust)
- **Location**: `proxy/`
- **Port**: 3000
- **Features**:
  - Aho-Corasick streaming sanitization
  - Secret injection/replacement
  - Health check endpoint
  - 15/15 unit tests passing
  - Memory-safe with Zeroize

### Agent (Python)
- **Location**: `agent/`
- **Environment**: Wolfi Linux + Python 3.11
- **Features**:
  - s6-overlay process supervision
  - Graceful shutdown handling
  - Proxy health checks
  - glibc compatibility for ML libraries

### Certificate Authority
- **Location**: Step-CA container
- **Port**: 9000 (internal)
- **Status**: Configured (initialization deferred)

## 🧪 Testing

### Test Coverage: 82% (89 Tests Passing)

**Comprehensive test suite with 89 tests covering:**
- ✅ 57 Proxy tests (Rust)
- ✅ 32 Agent tests (Python)
- ✅ 800+ property-based test cases
- ✅ Performance benchmarks validated
- ✅ Security threats tested
- ✅ Thread safety proven

See [TEST_REPORT.md](TEST_REPORT.md) for detailed coverage analysis.

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

# Agent tests (Python)
python3 agent/tests/test_agent.py       # Basic tests (7)
python3 agent/tests/test_agent_advanced.py  # Advanced tests (25)

# Validate system
docker compose config                   # Validate compose file
```

### Test Categories

| Category | Tests | Coverage | Status |
|----------|-------|----------|--------|
| Unit Tests | 37 | 85% | ✅ |
| Integration Tests | 6 | 100% | ✅ |
| Property Tests | 14 (800+ cases) | N/A | ✅ |
| Agent Tests | 32 | 85% | ✅ |
| **Total** | **89** | **82%** | **✅** |

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

- **Overall Progress**: 55% Complete
- **Phase 0** (Prerequisites): ✅ 100% Complete
- **Phase 1** (Identity/Network): 🔄 50% Complete
- **Phase 2** (Proxy Core): ✅ 90% Complete
- **Phase 3** (Agent Environment): 🔄 80% Complete
- **Phase 4** (Orchestration): 🔄 40% Complete
- **Phase 5** (Chaos Testing): ⏳ Planned

See [PROGRESS.md](PROGRESS.md) for detailed status.

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

## 🔒 Security Features

- **Zero-Knowledge**: Agents never see real credentials
- **Network Isolation**: Internal Docker network only
- **Memory Safety**: Rust's ownership model + Zeroize trait
- **Process Supervision**: Automatic restart on failure
- **Non-root Execution**: Both proxy and agent run as unprivileged users

## 🛣️ Roadmap

- [x] Phase 0: Prerequisites & Environment Setup
- [x] Phase 1: Network Foundation (partial)
- [x] Phase 2: Rust Proxy Core
- [x] Phase 3: Agent Environment (partial)
- [ ] Phase 4: mTLS Integration
- [ ] Phase 5: Chaos & Resilience Testing

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
**Last Updated**: 2026-01-28  
**Version**: 0.1.0