# SLAPENIR

**Secure LLM Agent Proxy Environment: Network Isolation & Resilience**

## Overview

SLAPENIR is a "Zero-Knowledge" execution sandbox designed to host high-privilege Autonomous Agents. The architecture enforces a strict separation of **Capability** (the Agent's ability to execute logic) and **Authority** (the credentials required to interact with external systems).

## Architecture

The system relies on a Polyglot Architecture:

- **Security Gateway (Proxy):** Written in **Rust** for deterministic memory management and high-throughput stream processing
- **Execution Environment (Agent):** Built on **Wolfi OS** for minimal attack surface with full glibc compatibility
- **Identity Plane:** Managed by **Step-CA** for automated, short-lived mutual TLS (mTLS) certificates

## Key Features

- 🔒 **Zero-Knowledge Sanitization**: Agent never sees real credentials
- 🔐 **Mutual TLS**: All connections authenticated via Step-CA certificates
- 🛡️ **Network Isolation**: Agent has no direct internet access
- 🔄 **Resilient Recovery**: Dual-layer disaster recovery with s6-overlay
- 🚀 **AI-Ready**: Full glibc compatibility for PyTorch, TensorFlow, etc.

## Project Status

🚧 **Initial Setup Phase** - Project structure being established

## Documentation

- [Architecture Specification](docs/SLAPENIR_Architecture.md)
- [System Specifications](docs/SLAPENIR_Specifications.md)
- [Implementation Roadmap](docs/SLAPENIR_Roadmap.md)
- [TDD Strategy](docs/SLAPENIR_TDD_Strategy.md)
- [Git Strategy](docs/SLAPENIR_Git_Strategy.md)
- [Risk Analysis](docs/SLAPENIR_Risks.md)

## Quick Start

> **Note:** Detailed setup instructions will be added as the project progresses through implementation phases.

### Prerequisites

- Docker Engine & Docker Compose
- Rust 1.75+ (for proxy development)
- Python 3.11+ (for agent development)

### Development Setup

```bash
# Clone repository
git clone git@github.com:andrewgibson-cic/slapenir.git
cd slapenir

# Set up git configuration
git config user.name "andrewgibson-cic"
git config user.email "andrew.gibson-cic@ibm.com"

# Install development tools (coming soon)
```

## Project Structure

```
slapenir/
├── docs/                   # Architecture & strategy documentation
├── proxy/                  # Rust proxy service (Phase 2)
├── agent/                  # Agent environment (Phase 3)
├── tests/                  # Integration & E2E tests (Phase 5)
├── docker-compose.yml      # Orchestration (Phase 4)
└── README.md              # This file
```

## Implementation Phases

- **Phase 0**: Prerequisites & Procurement ⏳
- **Phase 1**: Identity & Foundation (Days 1-2)
- **Phase 2**: Rust Proxy Core (Days 3-7)
- **Phase 3**: Agent Environment (Days 8-10)
- **Phase 4**: Security Wiring & Orchestration (Days 11-13)
- **Phase 5**: Resilience & Chaos Testing (Days 14-15)

## Contributing

This is currently a solo project. For questions or issues, please contact:

**Author:** andrewgibson-cic  
**Email:** andrew.gibson-cic@ibm.com

## License

[License information to be added]

## Security

This project handles sensitive security infrastructure. If you discover a security vulnerability, please contact the author directly rather than opening a public issue.

---

**Version:** 0.1.0 (Initial Setup)  
**Last Updated:** January 28, 2026