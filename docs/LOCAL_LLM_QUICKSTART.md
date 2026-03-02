# Local LLM Quick Start Guide

## Problem

When running OpenCode with a local llama-server, you may encounter the error:

```
Bad Gateway: Failed to forward request: client error (Connect)
```

This guide explains how to fix this issue and ensure your code stays secure (never leaks to the internet).

## Quick Fix (3 Steps)

### Step 1: Update llama-server Command

**Change your llama-server binding from `127.0.0.1` to `0.0.0.0`:**

```bash
# ❌ OLD (doesn't work with Docker)
llama-server --model ~/models/YourModel.gguf --host 127.0.0.1 --port 8080 ...

# ✅ NEW (works with Docker)
llama-server --model ~/models/YourModel.gguf --host 0.0.0.0 --port 8080 ...
```

Or use the provided script:

```bash
./scripts/setup-llama-server.sh
```

### Step 2: Restart Agent Container

The docker-compose.yml has been updated to add `extra_hosts` mapping. Restart the agent:

```bash
docker-compose restart agent
```

Or if that doesn't work, force recreate:

```bash
docker-compose up -d --force-recreate agent
```

### Step 3: Verify Security

Run the security verification script to ensure everything is working correctly:

```bash
./scripts/verify-local-llm-security.sh
```

This will test:
- ✅ llama-server is reachable from the agent
- ✅ External websites are blocked (security)
- ✅ Traffic enforcement is active
- ✅ Configuration is correct

## Your Complete Command Example

Based on your command, here's what you should run:

```bash
# Start llama-server on your host
llama-server \
  --model ~/models/Qwen3.5-35B-A3B-UD-Q4_K_M.gguf \
  --host 0.0.0.0 \
  --port 8080 \
  --ctx-size 65536 \
  --n-gpu-layers 99 \
  --threads 8 \
  --batch-size 512 \
  --jinja \
  --cache-type-k q4_0 \
  --cache-type-v q4_0 \
  --flash-attn on \
  --no-context-shift
```

Then restart the agent:

```bash
docker-compose restart agent
```

## Security Guarantee

**Your code CANNOT leak to the internet** when using this configuration because:

1. 🛡️ **Traffic Enforcement**: iptables rules block all unauthorized external connections
2. 🔒 **Network Isolation**: Docker network is `internal: true` (no external routing)
3. 🚪 **Proxy Bypass**: Local llama-server traffic bypasses the proxy (stays local)
4. 📊 **Monitoring**: All bypass attempts are logged

Even though llama-server binds to `0.0.0.0`, it's protected by Docker network isolation and iptables rules.

### What Can the Agent Access?

✅ **Allowed:**
- `host.docker.internal:8080` (your llama-server)
- Internal services (proxy, postgres, step-ca)
- SSH for git operations
- DNS for name resolution

🚫 **Blocked:**
- Direct internet access
- External APIs (unless through proxy with credentials)
- Any other external services

## Troubleshooting

### Still Getting "Bad Gateway" Error?

**Check 1: Is llama-server running?**

```bash
curl http://localhost:8080/v1/models
```

If this fails, start llama-server with `./scripts/setup-llama-server.sh`

**Check 2: Is llama-server bound to 0.0.0.0?**

```bash
lsof -i :8080
```

Should show `0.0.0.0:8080`, not `127.0.0.1:8080`

**Check 3: Did you restart the agent?**

```bash
docker-compose restart agent
```

**Check 4: Run the verification script**

```bash
./scripts/verify-local-llm-security.sh
```

This will diagnose all issues.

### Firewall Blocking Port 8080?

**macOS:**
```bash
# Check if firewall is blocking
sudo pfctl -sr | grep 8080

# Temporarily disable for testing
sudo pfctl -d
```

**Linux:**
```bash
# Allow port 8080
sudo ufw allow 8080

# Or disable firewall temporarily
sudo ufw disable
```

## Understanding the Fix

### What Changed?

1. **docker-compose.yml**: Added `extra_hosts` to agent container
   ```yaml
   agent:
     extra_hosts:
       - "host.docker.internal:host-gateway"
   ```

2. **llama-server binding**: Changed from `127.0.0.1` to `0.0.0.0`
   - `127.0.0.1`: Only accepts connections from localhost
   - `0.0.0.0`: Accepts connections from any interface (including Docker)

### Why Is This Safe?

Binding to `0.0.0.0` normally exposes a service to the entire network, but in this case:

1. **Docker Bridge Network**: Only containers in `slape-net` can reach the host
2. **Traffic Enforcement**: Agent can ONLY connect to whitelisted destinations
3. **Network Isolation**: Docker network prevents external routing
4. **Proxy Control**: Even if agent tries to reach internet, must go through proxy

See [LOCAL_LLM_SECURITY.md](./LOCAL_LLM_SECURITY.md) for detailed security analysis.

## Testing OpenCode

Once everything is configured:

1. **Start llama-server** (on host):
   ```bash
   llama-server --host 0.0.0.0 --port 8080 --model ~/models/YourModel.gguf
   ```

2. **Verify it's working**:
   ```bash
   ./scripts/verify-local-llm-security.sh
   ```

3. **Access the agent container**:
   ```bash
   docker exec -it slapenir-agent bash
   ```

4. **Run opencode**:
   ```bash
   cd /home/agent/workspace
   opencode
   ```

5. **Select your local model** from the OpenCode interface

## Configuration Reference

### OpenCode Configuration

File: `agent/config/opencode.json`

```json
{
  "provider": {
    "local-llama": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Local Llama Server",
      "options": {
        "baseURL": "http://host.docker.internal:8080/v1"
      },
      "models": {
        "qwen3.5-35b-a3b": {
          "name": "Qwen 3.5 35B A3B (Local)",
          "limit": {
            "context": 262144,
            "output": 65536
          }
        }
      }
    }
  }
}
```

### Environment Variables

Already configured in `docker-compose.yml`:

```yaml
environment:
  - LLAMA_SERVER_HOST=host.docker.internal
  - LLAMA_SERVER_PORT=8080
  - NO_PROXY=localhost,127.0.0.1,proxy,postgres,host.docker.internal
```

## Using Different Ports

If port 8080 conflicts with another service:

1. **Start llama-server on different port**:
   ```bash
   llama-server --host 0.0.0.0 --port 8090 ...
   ```

2. **Update docker-compose.yml**:
   ```yaml
   environment:
     - LLAMA_SERVER_PORT=8090
   ```

3. **Update opencode.json**:
   ```json
   {
     "baseURL": "http://host.docker.internal:8090/v1"
   }
   ```

4. **Restart agent**:
   ```bash
   docker-compose restart agent
   ```

## Alternative: Using Ollama

If you prefer Ollama instead of llama-server:

1. **Install and start Ollama**:
   ```bash
   # macOS
   brew install ollama
   ollama serve
   ```

2. **Pull your model**:
   ```bash
   ollama pull qwen2.5-coder:7b
   ```

3. **Ollama runs on port 11434 by default** (already configured in SLAPENIR)

4. **Update opencode.json**:
   ```json
   {
     "baseURL": "http://host.docker.internal:11434/v1"
   }
   ```

## Monitoring

### View Traffic Enforcement Logs

```bash
docker logs slapenir-agent | grep TRAFFIC-ENFORCE
```

### Check for Bypass Attempts

```bash
docker exec slapenir-agent dmesg | grep "BYPASS-ATTEMPT"
```

### View Proxy Metrics

Access Grafana at http://localhost:3001 (default credentials: admin/slapenir-dev-password-CHANGE-ME)

## Summary

| Action | Command |
|--------|---------|
| Start llama-server | `llama-server --host 0.0.0.0 --port 8080 --model ~/models/YourModel.gguf` |
| Restart agent | `docker-compose restart agent` |
| Verify security | `./scripts/verify-local-llm-security.sh` |
| Test from host | `curl http://localhost:8080/v1/models` |
| Test from agent | `docker exec slapenir-agent curl http://host.docker.internal:8080/v1/models` |
| Access agent | `docker exec -it slapenir-agent bash` |
| Run opencode | `opencode` (inside agent container) |

## Next Steps

1. ✅ Fix applied (extra_hosts added to docker-compose.yml)
2. ⚠️ **YOU NEED TO DO**: Restart llama-server with `--host 0.0.0.0`
3. ⚠️ **YOU NEED TO DO**: Restart agent container
4. ✅ Verify with `./scripts/verify-local-llm-security.sh`
5. 🎉 Use OpenCode with your local model!

## Support

For issues or questions:

- 📖 [Detailed Security Documentation](./LOCAL_LLM_SECURITY.md)
- 🐛 [Report Issues](https://github.com/andrewgibson-cic/slapenir/issues)
- 🔍 Run diagnostics: `./scripts/verify-local-llm-security.sh`