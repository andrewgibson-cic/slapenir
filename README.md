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
│              │ • OpenCode AI assistant integration
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

SLAPENIR supports local LLMs (llama-server) for air-gapped operation:

```bash
# Start llama-server on host (bind to 0.0.0.0 for Docker access)
llama-server --host 0.0.0.0 --port 8080 --model ~/models/YourModel.gguf
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
- [mTLS Setup](docs/mTLS_Setup.md) - Certificate management
- [Agent Environment](agent/README.md) - Agent configuration
- [Contributing](CONTRIBUTING.md) - Development guidelines
- [Security Policy](SECURITY.md) - Vulnerability reporting

---

## Stack Startup Sequence

### Quick Start (All Services)

```bash
./slapenir start
```

### Sequential Startup (Debugging)

| Step | Command | Wait For | Port |
|------|---------|----------|------|
| 1. Infrastructure | `docker compose up -d step-ca postgres memgraph` | `healthy` status | 9000, 5432, 7687 |
| 2. Proxy | `docker compose up -d proxy` | Port 3000 responding | 3000 |
| 3. Local LLM (optional) | `llama-server --host 0.0.0.0 --port 8080 --model model.gguf` | Server ready | 8080 |
| 4. Agent | `docker compose up -d agent` | Container running | - |
| 5. Monitoring (optional) | `docker compose --profile monitoring up -d` | Services healthy | 9090, 3001 |

### Verify Stack

```bash
./slapenir status
```

### Service Ports

| Service | Port | URL | Purpose |
|---------|------|-----|---------|
| Proxy | 3000 | http://localhost:3000 | API gateway, health, metrics |
| Prometheus | 9090 | http://localhost:9090 | Metrics collection |
| Grafana | 3001 | http://localhost:3001 | Dashboards (admin/admin) |
| Memgraph | 7687 | bolt://localhost:7687 | Graph database |
| Memgraph Lab | 7688 | http://localhost:7688 | Graph visualization |
| Step-CA | 9000 | https://localhost:9000 | Certificate authority |

### Dependency Graph

```
step-ca ─────┐
             ├──> proxy ──> agent
postgres ───┘

memgraph ───> memgraph-lab (optional)
```

## Status

**Production Ready** - All 6 development phases complete.

- 105 tests passing (82% coverage)
- Zero compiler warnings
- Chaos testing validated

## License

MIT
