# SLAPENIR Agent Environment

**Secure Python execution environment with process supervision and mTLS**

## Overview

The SLAPENIR Agent is a Wolfi-based minimal container designed for secure AI agent execution. It provides:

- **glibc compatibility** for PyTorch and other AI/ML libraries
- **Process supervision** via s6-overlay for automatic restarts
- **mTLS authentication** with Step-CA integration
- **Proxy enforcement** - all HTTP traffic routes through SLAPENIR proxy
- **Non-root execution** for enhanced security
- **Java 21 + Gradle support** for building JVM projects
- **GPG commit signing** using host GPG agent

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
- Memory-safe Python 3.12
- Certificate-based authentication

### 5. Zero-Leak Local AI (OpenCode)

Air-gapped AI code analysis with complete privacy:
- **OpenCode CLI** installed and hardened
- **Local LLM inference** via llama-server on host
- **Network isolation** - all external traffic blocked
- **Default-deny permissions** - only read access allowed

See [Zero-Leak Local AI Setup](#zero-leak-local-ai-setup) section below.

### 6. Java 21 + Gradle Support

Full JVM development environment:
- **OpenJDK 21** - Latest LTS release
- **Gradle** - Build automation tool
- **JAVA_HOME** - Pre-configured environment variable
- **Memory optimization** - Default 2GB max heap

### 7. GPG Commit Signing

**⚠️ Limited Support on macOS Docker**

GPG commit signing using the host's GPG agent is **not supported** on macOS with Docker Desktop or Colima due to socket mounting limitations.

**Alternatives:**
- Use HTTPS git URLs with GitHub PAT tokens (already configured)
- Disable GPG signing for this repo: `git config commit.gpgsign false`
- Use SSH-based git URLs (no signing needed)

### 8. MCP Memory & Knowledge Tools

AI agents can maintain context and query documentation in a **completely air-gapped environment**.

#### Memory Server (`@modelcontextprotocol/server-memory`)
- **Storage**: SQLite-based knowledge graph
- **Tools**: create_entities, search_nodes, read_graph, delete_nodes
- **Persistence**: Docker volume `slapenir-mcp-memory`
- **Use Case**: Remember facts, decisions, preferences across sessions

#### Knowledge Server (`mcp-local-rag`)
- **Storage**: LanceDB vector database
- **Model**: `jina-embeddings-v2-base-code` (pre-downloaded, 8K context)
- **Supports**: PDF, MD, TXT files (⚠️ DOCX has bugs in v0.10.0)
- **Tools**: index_directory, search_documents, list_indexed, clear_index
- **Persistence**: Docker volume `slapenir-mcp-knowledge`
- **Air-Gapped**: ✅ No internet required - model cached during Docker build

**Why jina-embeddings-v2-base-code?**
- Trained on 150M+ code-question-answer pairs
- Optimized for technical documentation and code
- Supports 30 programming languages
- 8192 token context (handles full architecture documents)

#### Usage

**Starting with a new project:**
```bash
make shell
cd ~/workspace
git clone <your-repo> myproject
cd myproject
mkdir -p docs
# Add markdown files to docs/
# (Avoid DOCX files due to mcp-local-rag bug)
opencode
```

**Indexing documents:**
```
User: "Index the docs directory"
Agent: [uses knowledge_index_directory tool]
       "Indexed 15 markdown files (47 chunks created)"
```

**Searching documents:**
```
User: "What does the documentation say about authentication?"
Agent: [searches indexed docs with embeddings]
       "Based on docs/api/auth.md, authentication uses JWT tokens..."
```

**Resetting memory:**
```bash
# Clear both memory and knowledge databases
~/scripts/reset-memory.sh
```

**Memory example:**
```
User: "Remember that this project uses FastAPI with PostgreSQL"
Agent: [stores in memory graph]

User: "What database are we using?"
Agent: [recalls from memory] "You mentioned using PostgreSQL with FastAPI"
```

#### Supported File Types

| Format | Support | Notes |
|--------|---------|-------|
| Markdown (.md) | ✅ Perfect | Best for technical docs |
| Text (.txt) | ✅ Perfect | Simple text files |
| PDF (.pdf) | ✅ Good | Extracted and chunked |
| DOCX (.docx) | ⚠️ Buggy | Has file size check bug in v0.10.0 |
| HTML | ✅ Via tool | Use ingest_data tool |

#### Model Cache

The embedding model is **pre-downloaded during Docker build** and cached at:
- **Location**: `/home/agent/.cache/huggingface/`
- **Size**: ~640MB
- **Volume**: `slapenir-huggingface-cache`
- **Air-Gapped**: No internet required at runtime

#### Troubleshooting

**"failed to initialize embedder"**
```bash
# Check model is cached
docker exec slapenir-agent ls -la ~/.cache/huggingface/models--Xenova--jina-embeddings-v2-base-code/

# If missing, rebuild container
docker-compose build --no-cache agent
```

**"failed to check file size of a docx"**
- This is a known bug in mcp-local-rag v0.10.0
- **Workaround**: Convert DOCX to Markdown or use PDF/text instead
- Track issue: https://github.com/shinpr/mcp-local-rag/issues

**Slow indexing**
- Large documents (8K+ tokens) take longer
- Model uses ~650MB memory
- Check: `docker stats slapenir-agent`

### 9. Build Tool Security

Build tool execution is controlled by security wrappers that block execution by default. These wrappers intercept build commands and require explicit override.

**Blocked tools:**
- gradle / ./gradlew
- mvn
- npm
- yarn
- pnpm
- cargo
- pip / pip3

**Security model:**
- **Default**: Block execution (requires explicit override)
- **Override methods**:
  1. `ALLOW_BUILD=1 <command>` - Allow all builds
  2. `<TOOL>_ALLOW_BUILD=1 <command>` - Allow specific tool (e.g., `NPM_ALLOW_BUILD=1 npm install`)
- **Audit trail**: All build attempts logged to `/var/log/slapenir/build-control.log`

**Usage examples:**
```bash
# Allow all builds in this command
ALLOW_BUILD=1 gradle build

# Allow only npm builds
NPM_ALLOW_BUILD=1 npm install

```

**Alternative approaches:**
- **Analyze build files**: You CAN read `build.gradle`, `pom.xml`, `package.json`
- **Explain build process**: Describe what the build would do
- **Suggest improvements**: Recommend build configuration changes

## Building

```bash
docker build -t slapenir-agent:latest ./agent
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `MTLS_ENABLED` | Enable mTLS for proxy communication | `true` |
| `MTLS_CA_CERT` | Path to CA certificate | `/certs/root_ca.crt` |
| `MTLS_CLIENT_CERT` | Path to client certificate | `/certs/agent.crt` |
| `MTLS_CLIENT_KEY` | Path to client key | `/certs/agent.key` |
| `MTLS_VERIFY_HOSTNAME` | Verify hostname in certificates | `true` |

## Java 21 + Gradle Support

The agent includes a complete Java 21 development environment for building JVM projects.

### Installed Components

- **OpenJDK 21** (LTS release)
- **Gradle** (latest version from Wolfi)
- **JAVA_HOME**: `/usr/lib/jvm/java-21-openjdk`
- **Default JVM opts**: `-Xmx2g -Xms512m` (configurable via `JAVA_OPTS`)

### Usage

```bash
# Enter container
docker exec -it slapenir-agent bash

# Verify Java version
java --version
# openjdk 21.x.x

# Verify Gradle
gradle --version

# Build a Gradle project
cd /home/agent/workspace/my-project
gradle build

# Run tests
gradle test

# Create JAR
gradle jar
```

### Memory Configuration

Adjust JVM memory for large projects:

```bash
# In container
export JAVA_OPTS="-Xmx4g -Xms1g"

# Or in .env file
JAVA_OPTS=-Xmx4g -Xms1g
```

### Gradle Wrapper Support

Projects with Gradle wrapper work automatically:

```bash
cd project-with-wrapper
./gradlew build  # Uses wrapper, not system Gradle
```

---

## GPG Commit Signing

The agent supports GPG commit signing using the **host's GPG agent**. This ensures the same GPG key used on the host is used inside the container.

### Architecture

```
┌──────────────────────────────────────────────────────┐
│              HOST MACHINE                             │
│                                                      │
│  GPG Agent (gpg-agent)                               │
│     ↓                                                │
│  Socket: ~/.gnupg/S.gpg-agent                        │
└──────────────────────────────────────────────────────┘
                    ↓ (mounted)
┌──────────────────────────────────────────────────────┐
│              AGENT CONTAINER                          │
│                                                      │
│  Git ──► GPG (container) ──► Socket ──► Host Agent   │
│         (signing)                  (forwarded)        │
└──────────────────────────────────────────────────────┘
```

### Prerequisites

1. **GPG agent running on host**:
   ```bash
   # Check if running
   gpg-agent --version
   
   # Start if not running
   gpg-agent --daemon
   ```

2. **GPG key configured on host**:
   ```bash
   # List keys
   gpg --list-secret-keys --keyid-format=long
   
   # Should show your signing key
   ```

3. **GPG key ID in .env**:
   ```bash
   # Add to .env
   GPG_KEY=164DA43B214F0144  # Your key ID (last 16 chars)
   ```

### Usage with dev.sh

The `dev.sh` script automatically mounts the GPG agent socket:

```bash
# Start with GPG support
./dev.sh bash

# Verify GPG works
gpg --version
gpg-connect-agent /bye  # Should succeed

# Make a signed commit
git commit -S -m "Signed commit"
# Or if commit.gpgsign=true (default):
git commit -m "Automatically signed commit"
```

### Verification

```bash
# In container, check git config
git config --get user.signingkey
# Should show: 164DA43B214F0144

git config --get commit.gpgsign
# Should show: true

# Test signing
echo "test" | gpg --clearsign
# Should prompt on host for passphrase (if needed)
```

### Troubleshooting

**GPG agent socket not mounted:**
```bash
# Check socket exists on host
ls -la ~/.gnupg/S.gpg-agent

# Verify dev.sh is mounting it
./dev.sh bash
ls -la /home/agent/.gnupg/S.gpg-agent
```

**Commits not signed:**
```bash
# Verify GPG_KEY is set
echo $GPG_KEY

# Check git config
git config --list | grep gpg
```

**Passphrase prompt not appearing:**
```bash
# On host, ensure GPG agent is running
gpg-agent --daemon

# Test agent connection
gpg-connect-agent /bye
```

### Security Notes

- ✅ Private keys **never** leave the host
- ✅ GPG agent socket is **read-only** from container
- ✅ Passphrase prompts appear on **host** (via pinentry)
- ✅ Same security model as SSH agent forwarding

---

## Directory Structure

```
/home/agent/
├── certs/              # mTLS certificates
├── workspace/          # Agent working directory
├── .config/opencode/   # OpenCode configuration
│   └── opencode.json   # Hardened permissions config
├── .claude/            # Host ~/.claude (read-only mount)
└── scripts/
    ├── bootstrap-certs.sh
    ├── traffic-enforcement.sh
    ├── verify-network-isolation.sh
    ├── agent.py
    ├── cgr-index
    ├── cgr-query
    ├── setup-bashrc.sh
    ├── setup-git-credentials.sh
    ├── setup-gpg.sh
    ├── setup-ssh-config.sh
    ├── startup-validation.sh
    ├── runtime-monitor.sh
    ├── *-wrapper         # Build tool wrappers (gradle, npm, cargo, etc.)
    └── ... (40+ scripts total)
```

---

## Zero-Leak Local AI Setup

**Complete air-gapped AI development with zero data exfiltration risk**

### Overview

This setup provides three-layer security for using OpenCode with local LLMs:

1. **Application Layer**: Hardened OpenCode config (default-deny all tools)
2. **Infrastructure Layer**: iptables network isolation (block all external traffic)
3. **Runtime Layer**: Container security (non-root, read-only mounts)

### Prerequisites

- **Hardware**: 16GB+ RAM (32GB recommended)
- **Software**: Docker Desktop/Engine 20.10+
- **Model**: Qwen 2.5 Coder (7B for 16GB, 14B for 32GB)

### Quick Start

**1. Install and start llama-server on host:**

```bash
# Using Ollama (recommended)
brew install ollama
ollama serve &
ollama pull qwen2.5-coder:7b

# Verify
curl http://localhost:11434/api/tags
```

**2. Build and start SLAPENIR:**

```bash
# Build container with OpenCode
docker compose build agent

# Start all services
docker compose up -d

# Verify
docker logs slapenir-agent
```

**3. Test zero-leak setup:**

```bash
# Enter container
docker exec -it slapenir-agent bash

# Run verification tests
/home/agent/scripts/verify-network-isolation.sh
python3 /home/agent/tests/test_opencode_permissions.py

# Test OpenCode
opencode --version
```

### Configuration

**Environment Variables** (`.env`):

```bash
OPENCODE_DISABLE_CLAUDE_CODE=1
LLAMA_SERVER_HOST=host.docker.internal
LLAMA_SERVER_PORT=6666
```

**Hardened OpenCode Config** (`/home/agent/.config/opencode/opencode.json`):

```json
{
  "permission": {
    "*": "deny",        // Default deny all
    "read": "allow",    // Allow reading files
    "edit": "ask",      // Require approval
    "bash": "deny",     // Block shell commands
    "webfetch": "deny", // Block network requests
    "mcp_*": "deny"     // Block MCP servers
  },
  "tools": { "websearch": false },
  "autoupdate": false,
  "share": "disabled",
  "experimental": { "openTelemetry": false },
  "provider": {
    "local-llama": {
      "npm": "@ai-sdk/openai-compatible",
      "options": { "baseURL": "http://host.docker.internal:11434/v1" },
      "models": {
        "qwen2.5-coder:7b": {
          "name": "Qwen 2.5 Coder 7B (Local)",
          "limit": { "context": 16384, "output": 8192 }
        }
      }
    }
  }
}
```

### Security Verification

**Test network isolation:**

```bash
# Should fail (external traffic blocked)
docker exec slapenir-agent curl -s --connect-timeout 5 https://www.google.com

# Should succeed (llama server accessible)
docker exec slapenir-agent curl -s http://host.docker.internal:11434/api/tags

# Should succeed (internal proxy accessible)
docker exec slapenir-agent curl -s http://proxy:3000/health
```

**Verify iptables rules:**

```bash
docker exec slapenir-agent iptables -L TRAFFIC_ENFORCE -n -v

# Should show:
# - ALLOW host.docker.internal:11434
# - ALLOW proxy:3000
# - DROP all other outbound
```

### Usage

```bash
# Enter container
docker exec -it slapenir-agent bash

# Navigate to workspace
cd /home/agent/workspace

# Use OpenCode
opencode

# Example commands:
# > Analyze the authentication module
# > Suggest improvements for error handling
# > Explain this database schema
```

### Troubleshooting

**Llama server not responding:**
```bash
curl http://localhost:11434/api/tags
docker logs slapenir-agent | grep llama
```

**External traffic not blocked:**
```bash
docker exec slapenir-agent /home/agent/scripts/verify-network-isolation.sh
docker exec slapenir-agent iptables -L TRAFFIC_ENFORCE -n
```

**OpenCode permission errors:**
```bash
docker exec slapenir-agent cat /home/agent/.config/opencode/opencode.json
```

### Model Selection

| Hardware | Model | RAM Usage | Speed | Quality |
|----------|-------|-----------|-------|---------|
| M1 Pro 16GB | `qwen2.5-coder:7b` | ~6GB | Fast (25-40 t/s) | Good |
| M1 Max 32GB | `qwen2.5-coder:14b` | ~12GB | Medium (10-20 t/s) | Excellent |
| 64GB+ RAM | `qwen2.5-coder:32b` | ~24GB | Slow (5-10 t/s) | Outstanding |

### Security Guarantees

✅ **Zero internet access** - iptables blocks all external traffic
✅ **No cloud APIs** - All inference happens locally
✅ **No telemetry** - Disabled in OpenCode config
✅ **No credential exposure** - Container has no real API keys
✅ **Audit logging** - All bypass attempts logged by iptables
✅ **Defense-in-depth** - Three independent security layers

---

## Testing

The placeholder agent (`agent.py`) logs heartbeats every 30 seconds and demonstrates:
- Environment verification
- Graceful shutdown handling
- Logging configuration

Replace this with your actual AI agent logic.
## Logging Configuration

The agent container includes structured logging with automatic rotation.

### Features

- **Structured JSON logging** to `/var/log/slapenir/` (machine-parseable)
- **Human-readable stdout logging** (for debugging)
- **Automatic log rotation** (10MB per file, 5 backups)
- **Three-tier fallback** (file → stdout → stderr)
- **Zero external dependencies** (stdlib only)
- **Environment-based configuration**

### Environment Variables

```bash
LOG_ENABLED=true                    # Enable/disable logging (default: true)
LOG_DIR=/var/log/slapenir          # Log directory path (default: /var/log/slapenir)
LOG_LEVEL=INFO                    # Log level: DEBUG, INFO, WARNING, ERROR, CRITICAL (default: INFO)
LOG_MAX_BYTES=10485760             # Max bytes per file before rotation (default: 10MB)
LOG_BACKUP_COUNT=5                # Number of backup files (default: 5)
SERVICE_NAME=agent-svc              # Service name for logs (default: agent-svc)
```

### Usage in Python Code

```python
from logging_config import LoggingConfig

# Setup logging
logger = LoggingConfig.get_logger(
    service_name='my-service',
    log_dir='/var/log/slapenir',
    log_level='INFO'
)

# Use like standard Python logger
logger.info("Service started")
logger.error("Something went wrong", exc_info=True)
```

### Log Format

**File logs (JSON)**:
```json
{"timestamp":"2026-03-04T12:30:45.123456","level":"INFO","service":"agent-svc","message":"Service started"}
```

**Stdout logs (text)**:
```
[2026-03-04 12:30:45] [INFO] Service started
```

### Log Rotation

Logs are automatically rotated when they reach 10MB:
- `agent-svc.log` (current log)
- `agent-svc.log.1` (first backup)
- `agent-svc.log.2` (second backup)
- `agent-svc.log.3` (third backup)
- `agent-svc.log.4` (fourth backup)

**Total disk usage**: 50MB maximum (10MB × 5 files)

### Viewing Logs

```bash
# View current log
tail -f /var/log/slapenir/agent-svc.log

# View JSON logs in structured format
jq '.' /var/log/slapenir/agent-svc.log | less

# View all logs
cat /var/log/slapenir/agent-svc.log*
```

### Troubleshooting

**Log directory permission denied**:
```bash
# Check permissions
ls -ld /var/log/slapenir

# Fix permissions
sudo chown agent:agent /var/log/slapenir
sudo chmod 755 /var/log/slapenir
```

**Logging not working**:
```bash
# Check if logging is enabled
echo $LOG_ENABLED

# Check log level
echo $LOG_LEVEL

# Check if directory is writable
touch /var/log/slapenir/test.log
```

---

## Code-Graph-RAG Integration

Air-gapped knowledge graph-based code analysis using the existing llama-server on the host machine.

### Components

- **Memgraph**: Graph database (port 7687)
- **Memgraph Lab**: Visualization UI (http://localhost:7688)
- **Code-Graph-RAG**: AST parsing and graph queries
- **MCP Server**: IDE integration with OpenCode

### Usage

#### Index a Repository

```bash
cgr-index /home/agent/workspace/my-project
```

#### Query the Graph

```bash
cgr-query "What functions call the database?"
```

#### Visualize in Memgraph Lab

Open http://localhost:7688 in browser.

### Example Workflow

```bash
# 1. Index a repository
cgr-index /home/agent/workspace/my-project

# 2. Query the graph
cgr-query "What functions call the database?"

# 3. Visualize in Memgraph Lab
# Open http://localhost:7688
```

### MCP Integration

Code-Graph-RAG is available as an MCP server for IDE integration:

- `query_code_graph` - Query code graph semantically
- `index_repository` - Index a repository
- `get_code_snippet` - Get code snippet by AST node
- `surgical_replace_code` - Apply code changes surgically

### Configuration

Code-Graph-RAG is configured via environment variables:

```bash
ORCHESTRATOR_PROVIDER=openai
ORCHESTRATOR_ENDPOINT=http://host.docker.internal:6666/v1
ORCHESTRATOR_API_KEY=sk-local
CYPHER_PROVIDER=openai
CYPHER_ENDPOINT=http://host.docker.internal:6666/v1
CYPHER_API_KEY=sk-local
MEMGRAPH_HOST=memgraph
MEMGRAPH_PORT=7687
```

### Prerequisites

- llama-server running on host (default port 6666)
- Memgraph container running (auto-starts with docker compose)
- Memgraph Lab accessible (auto-starts with docker compose)

### Troubleshooting

**"Cannot connect to Memgraph"**:
```bash
docker logs slapenir-agent 2>&1 | grep memgraph-verify
docker compose ps memgraph
```

**"Code-Graph-RAG not installed"**:
```bash
docker exec slapenir-agent cgr --version
docker exec slapenir-agent which cmake
docker exec slapenir-agent which rg
```

**"Indexing fails"**:
```bash
docker logs slapenir-agent 2>&1 | grep "cgr start"
# Check if repository exists
# Check if Memgraph is running
```

### Model Recommendations

| Hardware | Model | RAM Usage | Speed | Quality |
|----------|-------|-----------|-------|---------|
| M1 Pro 16GB | `qwen2.5-coder:7b` | ~6GB | Fast (25-40 t/s) | Good |
| M1 Max 32GB | `qwen2.5-coder:14b` | ~12GB | Medium (10-20 t/s) | Excellent |
| 64GB+ RAM | `qwen2.5-coder:32b` | ~24GB | Slow (5-10 t/s) | Outstanding |

---

