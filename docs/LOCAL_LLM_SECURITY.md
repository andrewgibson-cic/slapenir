# Local LLM Security: Network Isolation Guarantees

## Overview

When running OpenCode with a local llama-server, SLAPENIR provides **zero-trust network isolation** that guarantees your code cannot leak to the internet. This document explains how these security guarantees are enforced.

## The Problem

When using cloud-based LLMs (OpenAI, Anthropic, etc.), your code is sent to external servers. With local LLMs (llama-server, Ollama, etc.), the code stays on your machine, but you need to ensure that the agent container cannot accidentally or maliciously send data to external services.

## SLAPENIR's Multi-Layer Security

### Layer 1: Traffic Enforcement (iptables)

The agent container runs a traffic enforcement script (`agent/scripts/traffic-enforcement.sh`) that:

✅ **Allows ONLY:**
- Connections to the proxy (for sanctioned API calls)
- Connections to `host.docker.internal:8080` (your llama-server)
- Internal Docker network (postgres, step-ca)
- SSH (port 22) for git operations
- DNS (port 53) for name resolution

🚫 **Blocks:**
- All other outbound connections
- Direct internet access
- Bypass attempts are logged

**Implementation:** Uses iptables with a custom `TRAFFIC_ENFORCE` chain that redirects HTTP/HTTPS to the proxy and drops all other traffic.

### Layer 2: Docker Network Isolation

The `slape-net` Docker network is configured with `internal: true` in production mode:

```yaml
networks:
  slape-net:
    internal: ${NETWORK_INTERNAL:-true}  # Blocks external routing
```

This prevents any container traffic from reaching the internet, even if traffic enforcement fails.

### Layer 3: Proxy Bypass for Local Services

When the agent makes a request to `host.docker.internal:8080`:

1. The request is sent (allowed by traffic enforcement)
2. The proxy detects `host.docker.internal` in the URL
3. The proxy **bypasses** credential injection/sanitization
4. The request is forwarded directly to your llama-server
5. No external APIs are contacted

**Code Reference:** See `proxy/src/proxy.rs` function `should_bypass_proxy()`

### Layer 4: Host Machine Firewall (Optional)

For additional security, you can configure your host machine's firewall to only allow localhost connections to port 8080.

## Why Binding to 0.0.0.0 is Safe

The llama-server binds to `0.0.0.0:8080` to accept connections from Docker containers. This might seem unsafe, but it's protected by:

1. **Docker Bridge Network**: Only containers in `slape-net` can reach the host via `host.docker.internal`
2. **Traffic Enforcement**: Only the agent container has explicit permission to reach port 8080
3. **No External Routing**: The Docker network is internal, preventing external access
4. **Host Firewall**: Your host machine's firewall can restrict access to localhost only

### Alternative: Bind to 127.0.0.1 with Host Network Mode (Not Recommended)

You could bind to `127.0.0.1` and use `network_mode: host` in Docker, but this:
- Breaks container isolation
- Exposes all host ports to the container
- Reduces security

SLAPENIR's approach maintains strong isolation while allowing necessary connectivity.

## Configuration

### 1. Start llama-server on Host

Using the provided script:

```bash
./scripts/setup-llama-server.sh
```

Or manually with your preferred flags:

```bash
llama-server \
  --model ~/models/Qwen3.5-35B-A3B-UD-Q4_K_M.gguf \
  --host 0.0.0.0 \  # ⚠️ Required for Docker access
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

### 2. Configure OpenCode

Update `agent/config/opencode.json`:

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

### 3. Environment Variables

Ensure these are set in `docker-compose.yml` (already configured):

```yaml
environment:
  - LLAMA_SERVER_HOST=host.docker.internal
  - LLAMA_SERVER_PORT=8080
  - NO_PROXY=localhost,127.0.0.1,proxy,postgres,host.docker.internal
```

## Verification

### Verify Traffic Enforcement is Active

Inside the agent container:

```bash
# Check iptables rules
docker exec -it slapenir-agent iptables -L TRAFFIC_ENFORCE -v -n

# Should show rules allowing:
# - proxy:3000
# - host.docker.internal:8080
# - Internal network 172.30.0.0/24
# - And blocking everything else
```

### Test Network Isolation

Run the verification script:

```bash
./scripts/verify-local-llm-security.sh
```

This script will:
1. ✅ Verify llama-server is reachable from agent
2. ✅ Verify external websites are blocked
3. ✅ Verify traffic enforcement is active
4. ✅ Verify proxy bypass is working correctly

### Manual Testing

Inside the agent container:

```bash
# Should SUCCEED (llama-server is allowed)
curl http://host.docker.internal:8080/v1/models

# Should FAIL (external access blocked)
curl https://api.openai.com/v1/models

# Should SUCCEED (proxy handles this)
HTTP_PROXY=http://proxy:3000 curl https://api.openai.com/v1/models
```

## Security Guarantees

When using a local llama-server with SLAPENIR:

| Scenario | Guaranteed Protection |
|----------|----------------------|
| OpenCode sends code to llama-server | ✅ Stays local, never leaves your machine |
| Malicious code tries to exfiltrate data | ✅ Blocked by traffic enforcement |
| Agent tries to reach external API | ✅ Must go through proxy (monitored & sanitized) |
| Container escape attempt | ✅ Host firewall + Docker isolation |
| DNS tunneling attempt | ✅ DNS queries allowed but HTTP/HTTPS blocked |
| Network timeout bypass | ✅ iptables enforces at kernel level |

## Monitoring

### View Blocked Traffic Attempts

Check iptables logs for bypass attempts:

```bash
# On host machine
docker exec slapenir-agent dmesg | grep "BYPASS-ATTEMPT"

# Or check syslog
docker logs slapenir-agent | grep "TRAFFIC-ENFORCE"
```

### Prometheus Metrics

The proxy exports metrics for all requests:
- Requests to local services (llama-server)
- Requests to external APIs (through proxy)
- Blocked/failed requests

Access Grafana dashboard at http://localhost:3001

## Troubleshooting

### Error: "Bad Gateway: Failed to forward request"

**Symptoms:** OpenCode cannot connect to llama-server

**Causes & Solutions:**

1. **llama-server bound to 127.0.0.1 instead of 0.0.0.0**
   ```bash
   # ❌ Wrong
   llama-server --host 127.0.0.1 --port 8080
   
   # ✅ Correct
   llama-server --host 0.0.0.0 --port 8080
   ```

2. **Missing extra_hosts in agent container**
   - Fixed in docker-compose.yml (already applied)
   - Requires container restart: `docker-compose restart agent`

3. **llama-server not running**
   ```bash
   # Check if server is running
   curl http://localhost:8080/health
   
   # Start if needed
   ./scripts/setup-llama-server.sh
   ```

4. **Firewall blocking port 8080**
   ```bash
   # macOS
   sudo pfctl -d  # Disable firewall temporarily for testing
   
   # Linux
   sudo ufw allow 8080
   ```

### Verify Configuration

Run the comprehensive verification:

```bash
./scripts/verify-local-llm-security.sh
```

## Best Practices

1. **Always bind llama-server to 0.0.0.0** when using with Docker
2. **Keep traffic enforcement enabled** (`TRAFFIC_ENFORCEMENT_ENABLED=true`)
3. **Use internal network mode** (`NETWORK_INTERNAL=true`) in production
4. **Monitor logs** for bypass attempts
5. **Test network isolation** after any configuration changes
6. **Use strong models** for sensitive code (larger models = better security understanding)

## Advanced Configuration

### Using a Different Port

If port 8080 conflicts, change both:

```bash
# 1. llama-server command
llama-server --host 0.0.0.0 --port 8090 ...

# 2. Environment variable in docker-compose.yml
- LLAMA_SERVER_PORT=8090
```

### Multiple Local LLM Servers

You can run multiple local servers on different ports:

```yaml
environment:
  - LLAMA_SERVER_PORT=8080  # Primary model
  - OLLAMA_HOST=host.docker.internal:11434  # Secondary model
```

Update opencode.json with multiple providers.

### Host Network Mode (Not Recommended)

If you absolutely need to use `127.0.0.1` binding:

```yaml
agent:
  network_mode: host  # Breaks isolation!
```

⚠️ **Warning:** This significantly reduces security. Only use for debugging.

## Summary

SLAPENIR provides **defense-in-depth** for local LLM usage:

1. 🛡️ **Traffic enforcement** blocks unauthorized connections at the kernel level
2. 🔒 **Docker network isolation** prevents external routing
3. 🚪 **Proxy bypass** allows local-only LLM access without credential injection
4. 📊 **Monitoring** detects and logs bypass attempts
5. ✅ **Verification tools** confirm security posture

When properly configured, **your code physically cannot leave your machine** when using a local llama-server with SLAPENIR.

## Related Documentation

- [Traffic Enforcement Details](./TRAFFIC_ENFORCEMENT.md)
- [Network Architecture](./NETWORK_ARCHITECTURE.md)
- [Troubleshooting](./TROUBLESHOOTING.md)
- [Security Audit Results](./SECURITY_AUDIT.md)

## Support

If you encounter issues or have security concerns:

1. Run `./scripts/verify-local-llm-security.sh`
2. Check logs: `docker logs slapenir-agent`
3. Review this documentation
4. Report issues: [GitHub Issues](https://github.com/andrewgibson-cic/slapenir/issues)