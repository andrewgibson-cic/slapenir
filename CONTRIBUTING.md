# Contributing to SLAPENIR

Thank you for your interest in contributing to SLAPENIR!

## Development Setup

### Prerequisites

- Docker Desktop v27+
- Docker Compose v2.24+
- Rust 1.93+ (for proxy development)
- Python 3.12+ (for agent development)

### Quick Start

```bash
# Clone the repository
git clone https://github.com/andrewgibson-cic/slapenir.git
cd slapenir

# Copy environment template
cp .env.example .env
# Edit .env with your API keys

# Start the stack
./slapenir start

# Open a shell in the agent container
./slapenir shell
```

## Development Workflow

### Proxy (Rust)

```bash
cd proxy

# Build
cargo build

# Run tests
cargo test

# Run with hot reload
cargo watch -x run

# Lint
cargo clippy -- -D warnings
cargo fmt --check
```

### Agent (Python/Shell)

```bash
# Run agent tests
python3 agent/tests/test_agent.py

# Run shell script tests
bash agent/tests/run_all_tests.sh
```

## Code Style

### Rust

- Follow standard Rust formatting (`cargo fmt`)
- No warnings from clippy (`cargo clippy -- -D warnings`)
- Document public APIs with doc comments
- Use `#[cfg(test)]` for test modules

### Python

- Follow PEP 8
- Use type hints for function signatures
- Maximum line length: 100 characters
- Use `ruff` for linting

### Shell Scripts

- Use `#!/usr/bin/env bash` shebang
- Enable strict mode: `set -euo pipefail`
- Use `[[ ]]` for conditions
- Quote all variables

## Commit Guidelines

We follow [Conventional Commits](https://www.conventionalcommits.org/):

| Type | Description |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `refactor` | Code refactoring |
| `test` | Adding/updating tests |
| `chore` | Maintenance tasks |

**Examples:**
```
feat(proxy): add AWS SigV4 signature injection
fix(agent): correct workspace permissions for git operations
docs(readme): update startup sequence documentation
```

## Pull Request Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feat/my-feature`)
3. Make your changes
4. Run tests and linting
5. Commit with conventional commit messages
6. Push and create a pull request

### PR Checklist

- [ ] Tests pass locally
- [ ] Linting passes
- [ ] Documentation updated (if applicable)
- [ ] Commit messages follow conventional commits

## Testing

### Run All Tests

```bash
make test
```

### Proxy Tests (Rust)

```bash
cd proxy

# Unit tests
cargo test

# With output
cargo test -- --nocapture

# Benchmarks
cargo bench

# Authorization boundary tests
cargo test --test authorization_tests

# Chaos/fault injection tests
cargo test --test fault_injection_tests

# Security bypass tests
cargo test --test security_bypass_tests
```

### Agent Tests

```bash
python3 agent/tests/test_agent.py
bash agent/tests/run_all_tests.sh
```

### Load Tests

```bash
cd proxy/tests/load
./run_all_load_tests.sh
```

### Mutation Tests (Weekly)

```bash
cd proxy
cargo mutants
```

## Autonomous Development Workflow

SLAPENIR supports a structured 5-phase workflow for AI-driven development:

1. **Preparation**: Clone repo, export tickets, start LLM on host
2. **Environment Setup**: `make up`, `make copy-in REPO=... TICKETS=...`, `make verify`
3. **Session Isolation**: `make session-reset` between tickets
4. **AI Work**: `make shell` → `cgr start` → `git checkout -b fix/TICKET-123` → `opencode`
5. **Extraction**: `make copy-out-safe REPO=...` → secret scan → review → push

**Key safety commands:**

| Command | Purpose |
|---------|---------|
| `make verify` | Pre-flight security validation |
| `make session-reset` | Clear workspace between tickets |
| `make copy-out-safe REPO=...` | Backup + extract with integrity check |

## Architecture

See [docs/SLAPENIR_Architecture.md](docs/SLAPENIR_Architecture.md) for system design details.

## Questions?

Open an issue for bugs, feature requests, or questions.
