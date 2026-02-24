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
| `OLLAMA_HOST` | Ollama host for proxy forwarding | `host.docker.internal:11434` |
| `OLLAMA_MODEL` | Ollama model to use | `qwen2.5-coder:7b` |

## Local LLM Support (Ollama + Aider through Proxy)

The agent container includes support for local LLM inference via Ollama and the Aider AI pair programming tool. **All traffic routes through the SLAPENIR proxy for auditing.**

### Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        AGENT CONTAINER                               │
│                                                                     │
│  Aider ──► Ollama Proxy Helper ──► SLAPENIR Proxy ──► Host Ollama  │
│            (adds X-Target-URL)      (audits/logs)     (localhost)   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

All requests are logged by the SLAPENIR proxy for security auditing.

### Step 1: Install Ollama on Host Machine

**macOS:**
```bash
brew install ollama
```

**Linux:**
```bash
curl -fsSL https://ollama.com/install.sh | sh
```

### Step 2: Start Ollama Server

```bash
# Start Ollama server (keeps running in foreground)
ollama serve

# In another terminal, verify it's running
curl http://localhost:11434/api/tags
```

### Step 3: Pull the Recommended Model

For **M1 Pro 16GB** (recommended configuration):
```bash
# Pull the 7B model (optimal for 16GB RAM)
ollama pull qwen2.5-coder:7b

# Verify model is available
ollama list
```

**Model recommendations by hardware:**

| Hardware | Model | VRAM/RAM | Speed |
|----------|-------|----------|-------|
| M1 Pro 16GB | `qwen2.5-coder:7b` | ~6GB | Fast (25-40 t/s) |
| M1 Pro 16GB | `qwen2.5-coder:3b` | ~3GB | Very Fast (40-60 t/s) |
| M1 Max 32GB+ | `qwen2.5-coder:14b` | ~12GB | Moderate (10-20 t/s) |

### Step 4: Configure Environment Variables

Add to your `.env` file in the SLAPENIR root:
```bash
# Ollama Configuration
OLLAMA_HOST=host.docker.internal:11434
OLLAMA_MODEL=qwen2.5-coder:7b
```

### Step 5: Start SLAPENIR

```bash
# Build and start containers
docker compose build
docker compose up -d

# Check agent logs for Ollama verification
docker logs slapenir-agent 2>&1 | grep ollama-verify
```

You should see:
```
[ollama-verify] Ollama is reachable through proxy!
[ollama-verify] Model qwen2.5-coder:7b is available
```

### Step 6: Use Aider

**Option A: Using the helper script (recommended)**
```bash
# Enter the agent container
docker exec -it slapenir-agent bash

# Use the wrapper script (routes through proxy)
aider-ollama

# With specific arguments
aider-ollama --message "Add error handling to this function"
```

**Option B: Using Aider directly with custom context**
```bash
# In agent container, start aider with optimized settings
OLLAMA_API_BASE=http://localhost:8765 \
aider --model ollama_chat/qwen2.5-coder:7b \
      --map-tokens 2048 \
      --max-chat-history-tokens 4096
```

### Apple Silicon Optimization for Aider

The `aider-ollama` wrapper script automatically applies these optimizations:

1. **Metal GPU**: Requests go through proxy to Ollama on host (Metal enabled)
2. **Context window**: Limited to 16K for 16GB RAM
3. **Model**: Uses Q4_K_M quantization (default)

To further optimize for your M1 Pro, create a model settings file:

```bash
# In the agent container
cat > ~/.aider.model.settings.yml << 'EOF'
- name: ollama/qwen2.5-coder:7b
  extra_params:
    num_ctx: 16384    # 16K context (optimal for 16GB)
    num_gpu: 99       # All layers on GPU
    temperature: 0.7  # Balanced creativity
EOF
```

**Option C: Manual proxy configuration**
```bash
# Start the proxy helper manually
python3 /home/agent/scripts/ollama-proxy-helper.py &

# Configure Aider to use the helper
export OLLAMA_API_BASE=http://localhost:8765
aider --model ollama_chat/qwen2.5-coder:7b
```

### How It Works

1. **Aider** connects to `localhost:8765` (Ollama Proxy Helper)
2. **Proxy Helper** adds `X-Target-URL: http://host.docker.internal:11434` header
3. **SLAPENIR Proxy** receives the request, logs it, forwards to Ollama
4. **Ollama** processes the request, returns response
5. **SLAPENIR Proxy** logs the response, returns to helper
6. **Aider** receives the response

All requests are logged in the proxy for security auditing.

### Testing Connectivity

```bash
# Test 1: Direct Ollama on host
curl http://localhost:11434/api/tags

# Test 2: Through SLAPENIR proxy (from agent container)
docker exec -it slapenir-agent bash
curl -H "X-Target-URL: http://host.docker.internal:11434" http://proxy:3000/api/tags

# Test 3: Using the proxy helper
python3 /home/agent/scripts/ollama-proxy-helper.py &
curl http://localhost:8765/api/tags
```

### Troubleshooting

| Issue | Solution |
|-------|----------|
| "Connection refused" | Ensure Ollama is running: `ollama serve` |
| "Model not found" | Pull the model: `ollama pull qwen2.5-coder:7b` |
| Proxy returns 502 | Check proxy can reach host: `docker exec slapenir-proxy curl http://host.docker.internal:11434/api/tags` |
| Slow responses | Normal for local inference; try `qwen2.5-coder:3b` |
| Out of memory | Use smaller model or close other apps |

### Context Window Configuration

For better performance on 16GB RAM, configure a smaller context window:

```bash
# In agent container, create aider config
cat > ~/.aider.model.settings.yml << 'EOF'
- name: ollama/qwen2.5-coder:7b
  extra_params:
    num_ctx: 16384  # 16K context (saves memory)
EOF
```

---

## Apple Silicon M1 Pro Optimization

Ollama is **automatically optimized** for Apple Silicon using Metal GPU acceleration. Here's how to get the best performance:

### Metal GPU Acceleration (Automatic)

✅ **Metal is enabled by default** on Apple Silicon - no manual configuration needed.

The Metal API uses your Mac's GPU for inference, which is significantly faster than CPU-only. Apple Silicon's **Unified Memory Architecture** allows the GPU to access all system RAM without copying data.

### Verify Metal is Working

```bash
# Check if Ollama is using ARM64 (native Apple Silicon)
file $(which ollama)
# Should show: Mach-O 64-bit executable arm64

# Monitor GPU usage while running
# Open Activity Monitor → GPU tab
# You should see GPU activity when Ollama is generating
```

### Optimize GPU Layers

Ollama automatically offloads model layers to the GPU. For maximum performance on M1 Pro 16GB:

```bash
# Create a custom model with maximum GPU offload
ollama create qwen2.5-coder-7b-optimized -f - << 'EOF'
FROM qwen2.5-coder:7b
PARAMETER num_gpu 99
PARAMETER num_ctx 16384
PARAMETER temperature 0.7
EOF

# Run the optimized model
ollama run qwen2.5-coder-7b-optimized
```

**`num_gpu` explained:**
- `99` = offload all layers to GPU (recommended for Apple Silicon)
- Apple Silicon has unified memory, so no VRAM limit like discrete GPUs
- M1 Pro 16GB can handle full GPU offload for 7B models

### Performance Expectations

| Metric | M1 Pro 16GB (7B Q4) |
|--------|---------------------|
| **Tokens/sec** | 25-40 t/s |
| **Time to first token** | ~0.5-1s |
| **Memory usage** | ~6GB |
| **GPU utilization** | 80-100% |

### Memory Optimization

For 16GB M1 Pro, optimize memory usage:

```bash
# Limit context window to save memory
OLLAMA_CONTEXT_LENGTH=16384 ollama run qwen2.5-coder:7b

# Or set environment variable permanently
echo 'export OLLAMA_CONTEXT_LENGTH=16384' >> ~/.zshrc
```

### M1 Pro Specific Settings

```bash
# Environment variables for M1 Pro optimization
export OLLAMA_NUM_GPU=99           # Max GPU layers
export OLLAMA_CONTEXT_LENGTH=16384 # 16K context (fits in 16GB)
export OLLAMA_FLASH_ATTENTION=1    # Faster attention (if supported)
```

### Performance Tuning Checklist

| Setting | M1 Pro 16GB Recommended |
|---------|------------------------|
| Model | `qwen2.5-coder:7b` |
| `num_gpu` | 99 (all layers) |
| `num_ctx` | 16384 (16K) |
| Quantization | Q4_K_M (default) |

### Troubleshooting Slow Performance

| Issue | Solution |
|-------|----------|
| Only 2-5 t/s | Check Metal is enabled (Activity Monitor → GPU) |
| High fan noise | Normal for sustained inference; ensure good ventilation |
| Battery drain | Plug in power adapter for best performance |
| Slow first token | Model loading; subsequent calls are faster |
| Out of memory | Use smaller context or 3B model |

### Check Metal Status

```bash
# Check Metal support
system_profiler SPDisplaysDataType | grep -i metal

# Should show: Metal: Supported, Metal GPUFamily...
```

### Recommended Ollama Version

```bash
# Update to latest version for best Apple Silicon support
brew upgrade ollama

# Verify version (v0.1.30+ has best Metal support)
ollama --version
```

---

### Available Aider Commands

Inside Aider, you can use:
- `/add <file>` - Add files to the session
- `/ask <question>` - Ask questions without editing
- `/code <request>` - Request code modifications
- `/diff` - Show changes since last message
- `/commit` - Commit changes
- `/clear` - Clear chat history
- `/help` - Show all commands

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