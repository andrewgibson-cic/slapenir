# SLAPENIR

**Secure LLM Agent Proxy Environment with Network Isolation & Resilience (SLAPENIR)** - A zero-knowledge credential sanitization proxy for AI agents.

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
┌──────────────┐     ┌──────────────┐
│    Agent     │────▶│   Memgraph   │ Graph Database
│  Python 3.12 │     │     :7687    │ • Code-Graph-RAG
│              │     └──────────────┘ • Knowledge Graphs
│ • s6-overlay │            │
│ • OpenCode   │            ↓
│ • MCP Tools  │     ┌──────────────┐
│   - Memory   │     │ Memgraph Lab │ Visualization
│   - Knowledge│     │     :7688    │
└──────────────┘     └──────────────┘
```

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
   - [Step 1: Clone Repository](#step-1-clone-repository)
   - [Step 2: Install Docker](#step-2-install-docker)
   - [Step 3: Configure Environment Variables](#step-3-configure-environment-variables)
   - [Step 4: Download and Configure LLM](#step-4-download-and-configure-llm)
   - [Step 5: Start Services](#step-5-start-services)
3. [Configuration Guide](#configuration-guide)
4. [Common Operations](#common-operations)
5. [Useful Commands Reference](#useful-commands-reference)
6. [Troubleshooting](#troubleshooting)
7. [Security Features](#security-features)
8. [Testing](#testing)
9. [Documentation](#documentation)

---

## Prerequisites

### Required Software

| Software | Minimum Version | How to Check | Installation |
|----------|-----------------|--------------|--------------|
| **Docker Desktop** | v27+ | `docker --version` | [Download Docker](https://www.docker.com/products/docker-desktop/) |
| **Docker Compose** | v2.24+ | `docker compose version` | Included with Docker Desktop |
| **Git** | v2.30+ | `git --version` | [Download Git](https://git-scm.com/downloads) |

### System Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| RAM | 8 GB | 16 GB+ (for local LLM) |
| CPU | 4 cores | 8+ cores |
| Disk | 20 GB | 50 GB+ (for LLM models) |
| OS | macOS 12+, Ubuntu 20.04+, Windows 10+ with WSL2 | |

### Hardware Recommendations for Local LLM

| Model Size | RAM Required | GPU (Optional) |
|------------|--------------|----------------|
| 7B parameters | 8 GB | 6 GB VRAM |
| 14B parameters | 16 GB | 12 GB VRAM |
| 35B parameters | 32 GB | 24 GB VRAM |
| 70B+ parameters | 64 GB | 48 GB+ VRAM |

---

## Installation

### Step 1: Clone Repository

Open your terminal and clone the SLAPENIR repository:

```bash
# Navigate to your projects directory
cd ~/Projects

# Clone the repository
git clone https://github.com/andrewgibson-cic/slapenir.git

# Enter the project directory
cd slapenir
```

### Step 2: Install Docker

#### macOS

1. Download [Docker Desktop for Mac](https://www.docker.com/products/docker-desktop/)
2. Open the downloaded `.dmg` file
3. Drag Docker to your Applications folder
4. Open Docker from Applications
5. Wait for Docker to start (whale icon in menu bar should be steady)
6. Verify installation:
   ```bash
   docker --version
   docker compose version
   ```

#### Ubuntu Linux

```bash
# Update package index
sudo apt-get update

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add your user to docker group (logout/login required)
sudo usermod -aG docker $USER

# Install Docker Compose
sudo apt-get install docker-compose-plugin

# Verify installation
docker --version
docker compose version
```

#### Windows (with WSL2)

1. Install [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install)
2. Install [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/)
3. Enable WSL2 backend in Docker Desktop settings
4. Follow Ubuntu instructions above within WSL2

### Step 3: Configure Environment Variables

The `.env` file contains your real API credentials. **Never commit this file to version control.**

#### 3.1 Create Your .env File

```bash
# Copy the example file to create your .env
cp .env.example .env
```

#### 3.2 Edit the .env File

Open `.env` in your favorite editor:

```bash
# Using nano (beginner-friendly)
nano .env

# Using VS Code
code .env

# Using vim
vim .env
```

#### 3.3 Required Configuration

**Minimum required variables** (you must set these):

```bash
# Git Configuration (required for agent to make commits)
GIT_USER_NAME="Your Name"
GIT_USER_EMAIL="your.email@example.com"

# GitHub Personal Access Token (required for GitHub API access)
# Generate at: https://github.com/settings/tokens
# Required scopes: repo, read:org, read:user, read:discussion
GITHUB_TOKEN=ghp_your_token_here
```

#### 3.4 Security-Critical Variables

**IMPORTANT:** Set these passwords for production use. If not set, defaults will be used (NOT recommended for production):

```bash
# Step-CA Password (for certificate authority)
STEPCA_PASSWORD=your-strong-stepca-password-here

# PostgreSQL Password
POSTGRES_PASSWORD=your-strong-postgres-password-here

# Grafana Admin Password
GRAFANA_ADMIN_PASSWORD=your-strong-grafana-password-here
```

#### 3.5 Optional API Keys

Add any API keys your agent will use. The proxy will inject these at runtime:

```bash
# LLM APIs
OPENAI_API_KEY=sk-proj-real-key-here
ANTHROPIC_API_KEY=sk-ant-real-key-here

# Cloud Providers
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

# Other Services
STRIPE_SECRET_KEY=sk_live_realKeyHere
# ... etc
```

#### 3.6 Understanding Zero-Knowledge Architecture

**How credentials work in SLAPENIR:**

1. **In your `.env` file:** You set REAL credentials (e.g., `OPENAI_API_KEY=sk-proj-real-key-123`)
2. **In `.env.agent (auto-generated):** The agent sees DUMMY values (e.g., `OPENAI_API_KEY=DUMMY_OPENAI`)
3. **At proxy runtime:** When agent makes request with `DUMMY_OPENAI`, proxy replaces it with the real key
4. **Agent never sees real credentials!**

This is configured automatically - you don't need to create `.env.agent` manually.

### Step 4: Download and Configure LLM

SLAPENIR requires a local LLM for air-gapped operation. This section covers downloading a model and running llama-server.

#### 4.1 Choose Your Model

**Recommended models** (quantized for efficiency):

| Model | Size | Use Case | Download |
|-------|------|----------|----------|
| Qwen2.5-7B-Instruct | 4.4 GB | Fast, lightweight tasks | [HuggingFace](https://huggingface.co/Qwen/Qwen2.5-7B-Instruct-GGUF) |
| Qwen2.5-14B-Instruct | 8.6 GB | Balanced performance | [huggingFace](https://huggingface.co/Qwen/Qwen2.5-14B-Instruct-GGUF) |
| Qwen2.5-32B-Instruct | 19 GB | Complex reasoning | [HuggingFace](https://huggingface.co/Qwen/Qwen2.5-32B-Instruct-GGUF) |
| Qwen3.5-35B-A3B | 18 GB | Advanced coding + thinking | [HuggingFace](https://huggingface.co/Qwen/Qwen3-35B-A3B-UD-Q4_K_XL) |
| Llama-3.2-3B-Instruct | 2.0 GB | Very fast, simple tasks | [HuggingFace](https://huggingface.co/meta-llama/Llama-3.2-3B-Instruct-GGUF) |

#### 4.2 Download a Model

```bash
# Create models directory
mkdir -p ~/models

# Example: Download Qwen2.5-14B-Instruct (8.6 GB)
# Option A: Using huggingface-cli (recommended)
pip install huggingface-hub
huggingface-cli download Qwen/Qwen2.5-14B-Instruct-GGUF --local-dir ~/models

# Option B: Direct download with wget
cd ~/models
wget https://huggingface.co/qwen/Qwen2.5-14B-Instruct-GGUF/resolve/main/Qwen2.5-14b-instruct-q4_k_m.gguf

```

#### 4.3 Install llama-server

**Option A: Using pre-built binaries** (recommended):

```bash
# macOS (Apple Silicon)
curl -L https://github.com/ggerganov/llama.cpp/releases/download/master/llama-server-macos-arm64.zip -o llama-server.zip
unzip llama-server.zip
sudo mv llama-server /usr/local/bin/

# Ubuntu Linux
curl -L https://github.com/ggerganov/llama.cpp/releases/download/master/llama-server-ubuntu-x64.zip -o llama-server.zip
unzip llama-server.zip
sudo mv llama-server /usr/local/bin/

# Verify installation
llama-server --version
```

**Option B: Build from source:**

```bash
# Clone llama.cpp
git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp

# Build (requires cmake and C++ compiler)
mkdir build
cd build
cmake ..
cmake --build . --config Release

sudo cp llama-server /usr/local/bin/
```

#### 4.4 Start llama-server

**Basic startup** (simple):

```bash
llama-server \
  --model ~/models/qwen2.5-14b-instruct-q4_k_m.gguf \
  --host 0.0.0.0 \
  --port 8080
```

**Recommended production configuration** (with all optimizations):

```bash
llama-server \
  --model ~/models/Qwen3.5-35B-A3B-UD-Q4_K_XL.gguf \
  --ctx-size 200000 \
  --temp 0.6 \
  --top-p 0.0 \
  --top-k 20 \
  --min-p 0.00 \
  --host 0.0.0.0 \
  --port 8080 \
  --n-gpu-layers 99 \
  --threads 8 \
  --jinja \
  --cache-type-k q8_0 \
  --cache-type-v q8_0 \
  --flash-attn on \
  --batch-size 256 \
  --ubatch-size 128 \
  --alias "Qwen3.5-Coding-Thinking" \
  --presence-penalty 0.0 \
  --repeat-penalty 1.0 \
  --chat-template-kwargs '{"enable_thinking": true}' \
  --mmproj ~/models/mmproj-F16.gguf
```

**Parameter explanation:**

| Parameter | Value | Description |
|-----------|-------|-------------|
| `--model` | path | Path to your GGUF model file |
| `--ctx-size` | 200000 | Maximum context window (tokens) |
| `--temp` | 0.0-1.0 | Temperature (lower = more deterministic) |
| `--top-p` | 0.0-1.0 | Nucleus sampling probability |
| `--top-k` | 20-100 | Top-k sampling |
| `--min-p` | 0.0-0.1 | Minimum probability threshold |
| `--host` | 0.0.0.0 | Listen on all interfaces |
| `--port` | 8080 | Server port |
| `--n-gpu-layers` | 99 | GPU layers (99 = all, 0 = CPU only) |
| `--threads` | 8 | CPU threads for processing |
| `--jinja` | flag | Enable Jinja2 template engine |
| `--cache-type-k` | q8_0 | Key cache quantization |
| `--cache-type-v` | q8_0 | Value cache quantization |
| `--flash-attn` | on | Flash attention optimization |
| `--batch-size` | 256 | Maximum batch size for prompts |
| `--ubatch-size` | 128 | Micro-batch size |
| `--mmproj` | path | Multimodal projector (for vision models) |

#### 4.5 Run as Background Service

**Create a systemd service** (Linux):

```bash
# Create service file
sudo tee /etc/systemd/system/llama-server.service << EOF
[Unit]
Description=LLaMA Server
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=/home/$USER
ExecStart=/usr/local/bin/llama-server \\
  --model /home/$USER/models/qwen2.5-14b-instruct-q4_k_m.gguf \\
  --host 0.0.0.0 \\
  --port 8080 \\
  --ctx-size 32000 \\
  --threads 8
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable llama-server
sudo systemctl start llama-server

# Check status
sudo systemctl status llama-server
```

**Using launchd** (macOS):

```bash
# Create plist file
cat > ~/Library/LaunchAgents/com.llama.server.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.llama.server</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/llama-server</string>
        <string>--model</string>
        <string>/Users/$USER/models/qwen2.5-14b-instruct-q4_k_m.gguf</string>
        <string>--host</string>
        <string>0.0.0.0</string>
        <string>--port</string>
        <string>8080</string>
        <string>--ctx-size</string>
        <string>32000</string>
        <string>--threads</string>
        <string>8</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF

# Load the service
launchctl load ~/Library/LaunchAgents/com.llama.server.plist
```

#### 4.6 Verify LLM Server

```bash
# Check if server is running
curl http://localhost:8080/health

# Test a simple completion
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "local",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 50
  }'
```

### Step 5: Start Services

Now that Docker is running, your environment is configured, and LLM server is ready, start SLAPENIR:

#### 5.1 Initial Start

```bash
# Make the startup script executable (first time only)
chmod +x slapenir

# Start all services
./slapenir start
```

This command will:
1. Generate mTLS certificates (first run takes ~30 seconds)
2. Build Docker images (5-10 minutes on first run)
3. Start all services in correct order
4. Wait for health checks to pass
5. Display service URLs

#### 5.2 Verify Services Are Running

```bash
# Check service status
./slapenir status

# Or manually check each service
docker compose ps
```

Expected output:
```
NAME                STATUS              PORTS
slapenir-proxy     running (healthy)   0.2.3.4:3000->3000/tcp
slapenir-agent     running            1.2.3.4:22->22/tcp
slapenir-ca        running (healthy)   1.2.3.4:9000->9000/tcp
slapenir-postgres   running (healthy)   1.2.3.4:5432->5432/tcp
slapenir-memgraph   running (healthy)   1.2.3.4:7687->7687/tcp
```

#### 5.3 Access Services

| Service | URL | Username | Password | Purpose |
|---------|-----|----------|----------|---------|
| Proxy | http://localhost:3000 | - | - | API gateway, health checks |
| Prometheus | http://localhost:9090 | - | - | Metrics collection |
| Grafana | http://localhost:3001 | admin | admin (or your custom) | Monitoring dashboards |
| Memgraph Lab | http://localhost:7688 | - | - | Graph visualization |

---

## Configuration Guide

### Environment Variables Reference

#### System Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `ENVIRONMENT` | `development` | Environment name (development, staging, production) |
| `LOG_LEVEL` | `INFO` | Logging level (DEBUG, INFO, WARNING, ERROR) |
| `LOG_ENABLED` | `true` | Enable file logging |
| `LOG_DIR` | `/var/log/slapenir` | Log directory path |
| `LOG_MAX_BYTES` | `10485760` | Max log file size (10MB) |
| `LOG_BACKUP_COUNT` | `5` | Number of rotated log files |

#### Security Configuration

| Variable | Required | Description |
|----------|----------|-------------|
| `STEPCA_PASSWORD` | **Yes** (prod) | Step-CA root password |
| `POSTGRES_PASSWORD` | **Yes** (prod) | PostgreSQL database password |
| `GRAFANA_ADMIN_PASSWORD` | **Yes** (prod) | Grafana admin UI password |
| `MTLS_ENABLED` | `false` | Enable mTLS enforcement |
| `MTLS_ENFORCE` | `false` | Reject connections without valid certs |

#### Proxy Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `HTTP_PROXY` | `http://proxy:3000` | Proxy URL for HTTP |
| `HTTPS_PROXY` | `http://proxy:3000` | Proxy URL for HTTPS |
| `NO_PROXY` | `localhost,127.0.0.1` | Bypass proxy for these hosts |
| `AUTO_DETECT_ENABLED` | `true` | Enable automatic credential detection |
| `ALLOW_BUILD` | `false` | Allow build tools in shell |

#### LLM Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENCODE_DISABLE_CLAUDE_CODE` | `1` | Disable Claude Code (use local LLM) |
| `LLAMA_SERVER_HOST` | `host.docker.internal` | LLM server hostname |
| `LLAMA_SERVER_PORT` | `8080` | LLM server port |

#### Code-Graph-RAG Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `ORCHESTRATOR_PROVIDER` | `openai` | Provider type (openai for compatibility) |
| `ORCHESTRATOR_MODEL` | `qwen3.5-35b-a3b-ud-q4_k_xl` | Model name (ignored by llama-server) |
| `ORCHESTRATOR_ENDPOINT` | `http://host.docker.internal:8080/v1` | LLM endpoint URL |
| `ORCHESTRATOR_API_KEY` | `sk-local` | API key (dummy, ignored) |
| `CYPHER_PROVIDER` | `openai` | Cypher query provider type |
| `CYPHER_MODEL` | `qwen3.5-35b-a3b-ud-q4_k_xl` | Cypher query model name |
| `CYPHER_ENDPOINT` | `http://host.docker.internal:8080/v1` | Cypher query LLM endpoint URL |
| `CYPHER_API_KEY` | `sk-local` | Cypher query API key (dummy, ignored) |
| `MEMGRAPH_HOST` | `memgraph` | Memgraph hostname |
| `MEMGRAPH_PORT` | `7687` | Memgraph port |

### Network Configuration

SLAPENIR uses a custom Docker network (`slape-net`) with isolation:

```yaml
networks:
  slape-net:
    driver: bridge
    internal: false  # Set to true for full air-gap
    ipam:
      config:
        - subnet: 172.30.0.0/24
```

**Network isolation modes:**

| Mode | Setting | Agent Can Access |
|------|---------|-------------------|
| Development | `internal: false` | Internet via proxy, local LLM |
| Air-gapped | `internal: true` | Only internal services |

To enable full air-gap mode, edit `docker-compose.yml`:

```yaml
networks:
  slape-net:
    internal: true  # Change this line
```

### Git Configuration

The agent container mounts your host Git configuration:

```yaml
volumes:
  - ~/.gitconfig:/home/agent/.gitconfig:ro
  - ~/.ssh/config:/home/agent/.ssh/config.host:ro
  - ~/.ssh/known_hosts:/home/agent/.ssh/known_hosts
  - ~/.gnupg/pubring.kbx:/home/agent/.gnupg/pubring.kbx:ro
  - ~/.gnupg/trustdb.gpg:/home/agent/.gnupg/trustdb.gpg:ro
```

**Required Git setup on host:**

```bash
# Set your Git identity (if not already done)
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Verify SSH key exists
ls -la ~/.ssh/id_rsa  # or id_ed25519

# Test SSH connection
ssh -T git@github.com
```

---

## Common Operations

### Starting Services

```bash
# Start all services
./slapenir start

# Or using make
make up
```

### Stopping Services

```bash
# Stop all services
./slapenir stop

# Or using Docker Compose
docker compose down
```

### Viewing Logs

```bash
# View all logs
./slapenir logs

# View specific service logs
./slapenir logs proxy
./slapenir logs agent
./slapenir logs memgraph

# Follow logs in real-time
docker compose logs -f proxy
```

### Restarting Services

```bash
# Restart all services
./slapenir restart

# Restart specific service
docker compose restart proxy
```

### Checking Status

```bash
# Check all services
./slapenir status

# Check specific service
docker compose ps proxy
```

### Accessing Agent Shell

```bash
# Secure shell (builds blocked)
./slapenir shell

# Or using make
make shell
```

### Cleaning Up

```bash
# Stop and remove containers (keeps volumes)
./slapenir clean

# Remove everything including volumes (WARNING: deletes all data!)
docker compose down -v

# Remove Docker images
docker compose down --rmi all
```

---

## Useful Commands Reference

### Service Management

```bash
# Start services
./slapenir start                    # Start all services
make up                             # Alternative: start with make
docker compose up -d               # Direct Docker Compose command

# Stop services
./slapenir stop                     # Stop all services
make down                           # Alternative: stop with make
docker compose down                 # Direct Docker Compose command

# Restart services
./slapenir restart                  # Restart all services
docker compose restart              # Restart all containers
docker compose restart proxy        # Restart specific service

# View status
./slapenir status                   # Check service health
docker compose ps                   # List all containers
docker compose ps proxy             # Check specific service
```

### Logs and Debugging

```bash
# View logs
./slapenir logs                       # All service logs
./slapenir logs proxy               # Proxy logs only
./slapenir logs agent               # Agent logs only
docker compose logs                 # All container logs
docker compose logs -f proxy        # Follow proxy logs in real-time
docker compose logs --tail=100 agent  # Last 100 lines of agent logs

# View logs with timestamps
docker compose logs -t proxy

# Save logs to file
docker compose logs proxy > proxy-logs.txt
```

### Shell Access

```bash
# Secure shell (build tools blocked)
./slapenir shell
make shell

# Direct container exec
docker compose exec agent bash
docker compose exec proxy sh

# Run command in container
docker compose exec agent whoami
docker compose exec agent python3 --version
```

### Database Operations

```bash
# Connect to PostgreSQL
docker compose exec postgres psql -U slapenir -d slapenir

# Connect to Memgraph
docker compose exec memgraph mgconsole

# Run Cypher query
docker compose exec memgraph mgconsole \
  -c "MATCH (n) RETURN n LIMIT 10;"

# Backup PostgreSQL
docker compose exec postgres pg_dump -U slapenir slapenir > backup.sql

# Restore PostgreSQL
cat backup.sql | docker compose exec -T postgres psql -U slapenir slapenir
```

### Monitoring and Metrics

```bash
# View Prometheus metrics
curl http://localhost:9090/metrics

# Query specific metric
curl 'http://localhost:9090/api/v1/query?query=slapenir_requests_total'

# Access Grafana
open http://localhost:3001

# Check proxy health
curl http://localhost:3000/health

# View proxy metrics
curl http://localhost:3000/metrics
```

### Certificate Management

```bash
# View Step-CA logs
docker compose logs step-ca

# Check certificate status
docker compose exec step-ca step ca status

# List issued certificates
docker compose exec step-ca step ca certificates list

# Revoke certificate (if needed)
docker compose exec step-ca step ca revoke <serial>
```

### LLM Server Management

```bash
# Check LLM server health
curl http://localhost:8080/health

# Test completion
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"local","messages":[{"role":"user","content":"test"}],"max_tokens":10}'

# View available models
curl http://localhost:8080/v1/models

# Check GPU usage (if using GPU)
nvidia-smi

# Monitor llama-server process
ps aux | grep llama-server
```

### Development and Testing

```bash
# Run all tests
make test

# Run Rust tests only
cd proxy && cargo test

# Run Python tests only
pytest agent/tests/ -v

# Run specific test file
cargo test test_sanitizer

# Run with coverage
pytest agent/tests/ --cov=agent/scripts

# Run benchmarks
cd proxy && cargo bench

# Run load tests
cd proxy/tests/load && ./run_all_load_tests.sh
```

### Git Operations

```bash
# View recent commits
git log --oneline -10

# Check current status
git status

# Pull latest changes
git pull --rebase

# Create new branch
git checkout -b feature/my-feature

# View remote branches
git branch -r
```

### Docker Cleanup

```bash
# Remove stopped containers
docker container prune

# Remove unused images
docker image prune

# Remove unused volumes
docker volume prune

# Clean build cache
docker builder prune

# Full system cleanup (WARNING: removes everything!)
docker system prune -a --volumes
```

---

## Troubleshooting

### Common Issues and Solutions

#### Services Won't Start

**Symptom:** `docker compose up` fails

**Solutions:**
```bash
# Check Docker is running
docker info

# Check for port conflicts
lsof -i :3000  # Proxy port
lsof -i :5432  # PostgreSQL port
lsof -i :8080  # LLM server port

# View error logs
docker compose logs

# Reset everything
docker compose down -v
./slapenir start
```

#### LLM Server Not Responding

**Symptom:** Agent can't connect to LLM

**Solutions:**
```bash
# Check if llama-server is running
curl http://localhost:8080/health

# If not running, start it
llama-server --model ~/models/your-model.gguf --host 0.0.0.0 --port 8080

# Check from inside Docker
docker compose exec agent curl http://host.docker.internal:8080/health

# Check firewall (Linux)
sudo ufw allow 8080/tcp
```

#### Certificate Errors

**Symptom:** mTLS certificate errors

**Solutions:**
```bash
# Regenerate certificates
docker compose down -v
rm -rf ca-data
./slapenir start

# Check Step-CA logs
docker compose logs step-ca

# Verify certificates exist
ls -la ca-data/
```

#### Out of Memory

**Symptom:** Container killed, OOM errors

**Solutions:**
```bash
# Increase Docker memory limit (Docker Desktop)
# Settings → Resources → Memory: 16GB+

# For LLM, use smaller model or quantization
llama-server --model smaller-model.gguf

# Check memory usage
docker stats
```

#### Agent Can't Access Git

**Symptom:** Git operations fail in agent

**Solutions:**
```bash
# Verify Git config on host
git config --global user.name
git config --global user.email

# Check SSH key
ls -la ~/.ssh/id_rsa

# Test SSH
ssh -T git@github.com

# Verify mount in container
docker compose exec agent ls -la ~/.ssh
```

#### Network Isolation Issues

**Symptom:** Agent can't reach external APIs

**Solutions:**
```bash
# Check network mode
docker network inspect slape-net

# Verify proxy is running
curl http://localhost:3000/health

# Check agent's proxy settings
docker compose exec agent env | grep PROXY

# Test connection through proxy
docker compose exec agent curl http://proxy:3000/health
```

### Getting Help

```bash
# View make targets
make help

# View slapenir commands
./slapenir help

# View Docker Compose help
docker compose --help

# View service-specific help
docker compose exec proxy --help
```

---

## Security Features

### Zero-Knowledge Architecture

**How it works:**
1. Agent environment contains Dummies: `DUMMY_OPENAI`, `DUMMY_GITHUB`, etc.
2. Proxy maintains secret mapping: `DUMMY_* → real credentials`
3. Request interception: proxy replaces dummies with real values
4. response sanitization: proxy removes real credentials before agent sees them

5. **Agent NEVER sees real credentials**

### Network Isolation

- Docker network segmentation (`slape-net`)
- iptables traffic enforcement with proxy **BLOCKED by default**
- `ALLOW_BUILD=1` temporarily opens proxy for build commands only
- DNS filtering (whitelist only)
- `netctl` setuid binary for controlled iptables manipulation
- `make copy-cache` seeds host build caches for offline builds

### mTLS Authentication

- Step-CA certificate authority
- 24-hour certificate rotation
- Mutual TLS between all services
- Short-lived certificates limit exposure

### Memory Safety

- Rust ownership system prevents use-after-free
- Zeroize trait wipes secrets on memory
- No garbage collection delays
- Bounds checking prevents buffer overflows

### Audit Logging

- All requests logged
- Secret sanitization tracked
- Bypass attempts recorded
- Certificate events logged
- Structured JSON logging

For more details, see [Security Layers](docs/SECURITY_LAYERS.md)

---

## Secure Work Process

This is the recommended workflow for using SLAPENIR to do development work securely. The process ensures code never leaks to the internet, credentials are never exposed to the AI agent, and changes are fully auditable before merging.

### Phase 1: Preparation (on host)

```bash
# 1. Clone the target repository on your host
git clone https://github.com/org/repo.git ~/Projects/repo

# 2. Export tickets to markdown files
mkdir -p ~/Projects/tickets
# Place ticket markdown files in this directory

# 3. Ensure clean host state
cd ~/Projects/repo && git stash

# 4. Start llama-server on host
llama-server --host 0.0.0.0 --port 8080 --model ~/models/YourModel.gguf
```

### Phase 2: Environment Setup

```bash
# 5. Start SLAPENIR services
make up

# 6. Copy repo and tickets into container
make copy-in REPO=/path/to/repo TICKETS=/path/to/tickets

# 7. Verify connectivity
make shell
# Inside container:
ls workspace/ && curl http://host.docker.internal:8080/health

# 8. Run pre-flight security verification
make verify
```

### Phase 3: Session Isolation

Run this between tickets to prevent state leakage:

```bash
# 9. Reset workspace for a fresh session (skip on first ticket)
make session-reset
```

### Phase 4: AI Work (inside container)

```bash
# 10. Open agent shell
make shell

# 11. Start Code-Graph-RAG and wait for indexing
cgr start

# 12. Create a feature branch (handles existing branch gracefully)
git checkout -b fix/TICKET-123 2>/dev/null || git checkout fix/TICKET-123

# 13. Start OpenCode (YOLO mode disabled by default for security)
opencode
# Or enable auto-approve if desired: OPENCODE_YOLO=true opencode

# 14. Provide structured prompt with context file and specific ticket
```

### Phase 5: Extraction and Review

```bash
# 15. Exit OpenCode when done
# Review changes inside container
git diff && git log --oneline

# 16. Scan for accidentally injected secrets (inside container)
grep -rnE "(sk-|ghp_|AKIA|-----BEGIN)" --include="*.py" --include="*.ts" --include="*.js" --include="*.go" --include="*.rs" .

# 17. Copy repo back to host with backup (prevents data loss on failure)
make copy-out-safe REPO=/path/to/repo

# 18. On host: scan for secrets and review diff
cd /path/to/repo
gitleaks detect --source=. --no-git  # or: trufflehog filesystem .
git diff HEAD
git log --oneline

# 19. Push or reject
git push origin fix/TICKET-123
# If rejected, retry: make copy-in REPO=/path/to/repo and repeat from Phase 4
```

### Safety Features in This Process

| Feature | Command | Purpose |
|---------|---------|---------|
| Backup before copy-out | `make copy-out-safe` | Prevents data loss if transfer fails mid-way |
| Pre-flight security check | `make verify` | Validates zero-knowledge arch + network isolation |
| Session isolation | `make session-reset` | Clears workspace/MCP between tickets |
| YOLO mode gated | `OPENCODE_YOLO` env var | Auto-approve disabled by default; opt-in |
| Branch safety | `\|\| git checkout` fallback | Handles existing branches on retry |
| Secret scanning | `grep` + `gitleaks` | Catches credential leakage before push |

### Make Commands Reference

| Command | Description |
|---------|-------------|
| `make up` | Start all services |
| `make down` | Stop all services |
| `make status` | Show service status |
| `make shell` | Open agent shell (builds blocked, no internet) |
| `make shell-unrestricted` | Open shell with internet (flushes iptables) |
| `make shell-raw` | Open raw shell bypassing all config |
| `make copy-in REPO=... TICKETS=...` | Copy repo and tickets into container |
| `make copy-out REPO=...` | Copy repo out with integrity check |
| `make copy-out-safe REPO=...` | Same as copy-out but backs up host copy first |
| `make copy-cache TYPE=gradle\|npm\|pip\|yarn\|maven\|all` | Copy host build caches for offline builds |
| `make session-reset` | Clear workspace, MCP memory, and knowledge |
| `make verify` | Run pre-flight security verification |
| `make test` | Run all tests |
| `make rebuild` | Rebuild from scratch |
| `make clean` | Remove containers and volumes |
| `make logs [SERVICE=proxy]` | Follow service logs |

---

## Testing

### Running Tests

```bash
# All tests (381+ tests, 82% coverage)
make test

# Rust tests
cd proxy
cargo test --all
cargo test --all -- --nocapture
cargo bench

# Python tests
pytest agent/tests/ -v

# Load tests (requires running services)
cd proxy/tests/load
./run_all_load_tests.sh
```

### Test Coverage

- **Unit tests**: 381 tests (Rust)
- **Integration tests**: Comprehensive suite across all modules
- **Property tests**: Proptest for generative testing
- **Security tests**: Authorization boundary tests, bypass prevention
- **Chaos tests**: Fault injection and resilience validation
- **Benchmarks**: Criterion performance tests
- **Load tests**: k6 load testing suite
  - API Load Test (100 rps, 2min)
  - Proxy Sanitization Test (8min)
  - Stress Test (14min)
  - Soak Test (30min)
- **Mutation testing**: cargo-mutants weekly analysis

---

## Documentation

### Architecture and Design

- [Architecture Overview](docs/SLAPENIR_Architecture.md) - System design and component architecture
- [Security Layers](docs/SECURITY_LAYERS.md) - Defense-in-depth analysis (10 layers)
- [Technical Whitepaper](docs/SLAPENIR-Technical-Whitepaper.md) - Full technical specification

### Contributing

- [Contributing Guide](CONTRIBUTING.md) - Development guidelines
- [Security Policy](SECURITY.md) - Vulnerability reporting

---

## Status

**Production Ready** - All development phases complete:
- 381 tests passing (82% coverage)
- Zero compiler warnings
- Chaos testing validated
- Security review passed
- Performance benchmarks met
- Autonomous development workflow integrated
- MCP tools (Memory, Knowledge, Code-Graph-RAG) operational
- Secure work process with session isolation

**Version**: 1.10.0

**Last Updated**: 2026-04-11

---

## License

MIT License - See [LICENSE](LICENSE) file for details.

---

## Support

- **GitHub Issues**: https://github.com/andrewgibson-cic/slapenir/issues
- **Documentation**: See `docs/` directory
- **Security Issues**: security@slapenir.dev (for security vulnerabilities only)
