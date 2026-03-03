# SLAPENIR

**Secure LLM Agent Proxy Environment** - A zero-knowledge credential sanitization proxy for AI agents.

## Overview

SLAPENIR sits between AI agents and external APIs, ensuring agents never see real credentials:

- **Injects** real credentials into outbound requests
- **Sanitizes** secrets from inbound responses
- **Isolates** agents in a controlled network environment
- **Supervises** agent processes with automatic restart

## Architecture

```
┌──────────────┐
│   Step-CA    │ Certificate Authority
└──────────────┘
       │ mTLS
       ↓
┌──────────────┐     ┌──────────────┐
│  Prometheus  │────▶│   Grafana    │
└──────────────┘     └──────────────┘
       ↑
       │ metrics
┌──────┴───────┐
│    Proxy     │ Rust Sanitizing Gateway
│   :3000      │ • Aho-Corasick O(N) pattern matching
│              │ • Zero-knowledge credential handling
│              │ • Memory-safe with Zeroize
└──────┬───────┘
       │ mTLS
       ↓
┌──────────────┐
│    Agent     │ Wolfi Python Environment
│  Python 3.11 │ • s6-overlay supervision
│              │ • Network-isolated workspace
│              │ • Local LLM support (Ollama/llama-server)
└──────────────┘
```

## Quick Start

### Prerequisites

- Docker Desktop v27+
- Docker Compose v2.24+

### 1. Configure Environment

```bash
cp .env.example .env
# Edit .env with your API keys
```

Required variables:
- `GITHUB_TOKEN` - GitHub Personal Access Token
- `GIT_USER_NAME` / `GIT_USER_EMAIL` - Git identity

### 2. Start Services

```bash
./slapenir start
```

This automatically:
- Generates mTLS certificates
- Builds and starts all services
- Verifies health checks
- Displays access URLs

### 3. Access Services

| Service | URL | Purpose |
|---------|-----|---------|
| Proxy | http://localhost:3000 | API gateway |
| Prometheus | http://localhost:9090 | Metrics |
| Grafana | http://localhost:3001 | Dashboards (admin/admin) |

## Common Operations

```bash
./slapenir status          # Check service health
./slapenir shell           # Open shell in agent (as agent user)
./slapenir logs [service]  # View logs
./slapenir restart         # Restart all services
./slapenir stop            # Stop services
./slapenir clean           # Remove containers and volumes

# Or use make
make help
make shell
make test
```

## Local LLM Support

SLAPENIR supports local LLMs (Ollama, llama-server) for air-gapped operation:

```bash
# Start llama-server on host (bind to 0.0.0.0 for Docker access)
llama-server --host 0.0.0.0 --port 8080 --model ~/models/YourModel.gguf

# Or use Ollama
ollama serve
ollama pull qwen2.5-coder:7b
```

The agent connects via `host.docker.internal` - traffic stays local and never reaches the internet.

## Components

### Proxy (Rust)
- Aho-Corasick streaming sanitization
- Secret injection/replacement
- mTLS with Step-CA
- Prometheus metrics
- 82% test coverage

### Agent (Wolfi OS)
- Python 3.11 + build tools
- s6-overlay process supervision
- mTLS client
- Git credential management
- glibc for ML libraries

### Monitoring
- Prometheus metrics collection
- Grafana dashboards
- Health endpoints

## Security Features

- **Zero-Knowledge**: Agents never see real credentials
- **Network Isolation**: Internal Docker network only
- **Memory Safety**: Rust + Zeroize trait
- **mTLS**: Mutual TLS between all services
- **Process Supervision**: Automatic restart on failure

## Testing

```bash
make test          # All tests (105 tests, 82% coverage)
cd proxy && cargo test
python3 agent/tests/test_agent.py
```

## Documentation

- [Architecture](docs/SLAPENIR_Architecture.md) - System design
- [Local LLM Setup](docs/LOCAL_LLM_QUICKSTART.md) - Air-gapped operation
- [mTLS Setup](docs/mTLS_Setup.md) - Certificate management

## Status

**Production Ready** - All 6 development phases complete.

- 105 tests passing (82% coverage)
- Zero compiler warnings
- Chaos testing validated

## License

MIT
