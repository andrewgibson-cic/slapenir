# SLAPENIR Agent Environment

**Secure Python execution environment with process supervision and mTLS**

## Overview

The SLAPENIR Agent is a Wolfi-based minimal container designed for secure AI agent execution. It provides:

- **glibc compatibility** for PyTorch and other AI/ML libraries
- **Process supervision** via s6-overlay for automatic restarts
- **mTLS authentication** with Step-CA integration
- **Proxy enforcement** - all HTTP traffic routes through SLAPENIR proxy
- **Non-root execution** for enhanced security

## Features

### 1. Process Supervision (s6-overlay)

The agent uses s6-overlay as an init system:
- Automatic restarts on crashes (exit codes 1-99)
- Graceful shutdown handling
- Process monitoring and logging
- Fatal error detection (exit codes 100+)

### 2. Certificate Management

Automatic mTLS certificate enrollment from Step-CA

### 3. Proxy Enforcement

All HTTP/HTTPS traffic routed through SLAPENIR proxy

### 4. Security

- Non-root execution (user: agent, uid: 1000)
- Minimal attack surface (Wolfi base)
- Memory-safe Python 3.11
- Certificate-based authentication

## Building

```bash
docker build -t slapenir-agent:latest ./agent
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `STEP_CA_URL` | Step-CA server URL | `https://ca:9000` |
| `STEP_TOKEN` | Certificate enrollment token | (required) |
| `STEP_PROVISIONER` | CA provisioner name | `agent-provisioner` |

## Directory Structure

```
/home/agent/
├── certs/              # mTLS certificates
├── workspace/          # Agent working directory
└── scripts/
    ├── bootstrap-certs.sh
    └── agent.py
```

## Testing

The placeholder agent (`agent.py`) logs heartbeats every 30 seconds and demonstrates:
- Environment verification
- Graceful shutdown handling
- Logging configuration

Replace this with your actual AI agent logic.