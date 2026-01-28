# SLAPENIR mTLS Setup Guide

**Mutual TLS (mTLS) Implementation for Secure Agent-Proxy Communication**

---

## Overview

SLAPENIR uses mutual TLS (mTLS) to ensure that:
1. **Agents verify the proxy** (standard TLS)
2. **Proxy verifies agents** (mutual authentication)
3. **All communication is encrypted** end-to-end
4. **Only authorized agents** can connect to the proxy

This document covers the complete setup and operation of mTLS in SLAPENIR.

---

## Architecture

```
┌─────────────────┐          mTLS           ┌──────────────────┐
│                 │  ◄──────────────────►   │                  │
│  SLAPENIR Agent │    Client Cert +        │  SLAPENIR Proxy  │
│                 │    Server Cert          │                  │
└─────────────────┘                         └──────────────────┘
        │                                            │
        │                                            │
        ▼                                            ▼
  ┌──────────┐                              ┌──────────────┐
  │Agent Cert│                              │ Server Cert  │
  │& Key     │                              │ & Key        │
  └──────────┘                              └──────────────┘
        │                                            │
        └────────────────┬───────────────────────────┘
                         │
                    ┌────▼─────┐
                    │   CA     │
                    │Certificate│
                    └──────────┘
```

### Components

1. **Certificate Authority (CA)** - Issues and validates all certificates
2. **Proxy Certificate** - Server certificate for the proxy
3. **Agent Certificates** - Client certificates for each agent
4. **Root CA Certificate** - Trusted by both proxy and agents

---

## Setup Instructions

### Step 1: Initialize Step-CA

First, initialize the Certificate Authority:

```bash
# Run the initialization script
./scripts/init-step-ca.sh

# This will:
# - Create a new CA with the name "SLAPENIR-CA"
# - Generate root CA certificates
# - Configure the CA to issue certificates
# - Set up password protection
```

**Expected Output:**
```
🔐 SLAPENIR Step-CA Initialization
===================================
📦 Starting Step-CA container for initialization...
✅ Step-CA initialized successfully!
```

### Step 2: Start the CA Server

```bash
# Start the CA using Docker Compose
docker compose up -d step-ca

# Verify it's running
docker compose ps step-ca
curl http://localhost:9000/health
```

### Step 3: Generate Proxy Certificate

```bash
# Generate server certificate for the proxy
docker compose exec step-ca step ca certificate \
  "proxy" \
  /home/step/certs/proxy.crt \
  /home/step/certs/proxy.key \
  --provisioner=admin

# Copy certificates to proxy directory
docker compose cp step-ca:/home/step/certs/proxy.crt ./proxy/certs/
docker compose cp step-ca:/home/step/certs/proxy.key ./proxy/certs/
docker compose cp step-ca:/home/step/certs/root_ca.crt ./proxy/certs/
```

### Step 4: Generate Agent Certificates

```bash
# For each agent, generate a certificate
docker compose exec step-ca step ca certificate \
  "agent-01" \
  /home/step/certs/agent-01.crt \
  /home/step/certs/agent-01.key \
  --provisioner=admin

# Copy to agent directory
docker compose cp step-ca:/home/step/certs/agent-01.crt ./agent/certs/
docker compose cp step-ca:/home/step/certs/agent-01.key ./agent/certs/
docker compose cp step-ca:/home/step/certs/root_ca.crt ./agent/certs/
```

### Step 5: Configure Proxy for mTLS

Update `proxy/src/main.rs` to enable mTLS:

```rust
use slapenir_proxy::MtlsConfig;

#[tokio::main]
async fn main() {
    // ... existing setup ...

    // Configure mTLS
    let mtls_config = MtlsConfig::from_files(
        "certs/root_ca.crt",
        "certs/proxy.crt",
        "certs/proxy.key",
        true, // enforce mTLS
    ).expect("Failed to initialize mTLS");

    // Add to app state
    let app = Router::new()
        .route("/health", get(health_check))
        .route("/*path", any(proxy_handler))
        .layer(Extension(mtls_config))
        .layer(middleware::from_fn(verify_client_cert));

    // ... rest of setup ...
}
```

### Step 6: Configure Agent for mTLS

Create `agent/scripts/mtls_client.py`:

```python
import ssl
import requests
from pathlib import Path

class MtlsClient:
    """HTTP client with mTLS support"""
    
    def __init__(self, ca_cert, client_cert, client_key):
        self.ca_cert = Path(ca_cert)
        self.client_cert = Path(client_cert)
        self.client_key = Path(client_key)
        
        # Create SSL context
        self.ssl_context = ssl.create_default_context(
            purpose=ssl.Purpose.SERVER_AUTH,
            cafile=str(self.ca_cert)
        )
        
        # Load client certificate
        self.ssl_context.load_cert_chain(
            certfile=str(self.client_cert),
            keyfile=str(self.client_key)
        )
        
        # Create session with mTLS
        self.session = requests.Session()
        self.session.verify = str(self.ca_cert)
        self.session.cert = (str(self.client_cert), str(self.client_key))
    
    def post(self, url, **kwargs):
        """Make POST request with mTLS"""
        return self.session.post(url, **kwargs)
    
    def get(self, url, **kwargs):
        """Make GET request with mTLS"""
        return self.session.get(url, **kwargs)

# Usage in agent
client = MtlsClient(
    ca_cert="certs/root_ca.crt",
    client_cert="certs/agent-01.crt",
    client_key="certs/agent-01.key"
)

response = client.post(
    "https://proxy:3000/v1/chat/completions",
    json=payload
)
```

---

## Certificate Management

### Certificate Rotation

Certificates should be rotated periodically:

```bash
# Check certificate expiration
openssl x509 -in proxy/certs/proxy.crt -noout -dates

# Renew certificate (before expiration)
docker compose exec step-ca step ca renew \
  /home/step/certs/proxy.crt \
  /home/step/certs/proxy.key \
  --force

# Restart services to pick up new certificates
docker compose restart proxy
```

### Adding New Agents

```bash
# 1. Generate certificate for new agent
docker compose exec step-ca step ca certificate \
  "agent-02" \
  /home/step/certs/agent-02.crt \
  /home/step/certs/agent-02.key

# 2. Copy to agent
docker compose cp step-ca:/home/step/certs/agent-02.crt ./agent-02/certs/
docker compose cp step-ca:/home/step/certs/agent-02.key ./agent-02/certs/

# 3. Agent can now connect with its certificate
```

### Revoking Certificates

```bash
# Revoke a compromised certificate
docker compose exec step-ca step ca revoke \
  --cert-file=/home/step/certs/agent-01.crt \
  --key-file=/home/step/certs/agent-01.key

# The agent will no longer be able to connect
```

---

## Security Best Practices

### 1. Certificate Storage

```bash
# Certificates should have restricted permissions
chmod 600 proxy/certs/proxy.key
chmod 600 agent/certs/agent-01.key
chmod 644 proxy/certs/proxy.crt
chmod 644 agent/certs/agent-01.crt
chmod 644 */certs/root_ca.crt
```

### 2. Password Protection

```bash
# Change default CA password immediately
docker compose exec step-ca step ca password

# Use strong passwords (32+ characters)
# Store passwords in a secret manager (Vault, AWS Secrets Manager, etc.)
```

### 3. Certificate Validity

```bash
# Use short-lived certificates (default: 24 hours)
# Configure in step-ca/config/ca.json:
{
  "authority": {
    "provisioners": [{
      "name": "admin",
      "default": {
        "certDuration": "24h"
      }
    }]
  }
}
```

### 4. Monitoring

Monitor certificate expiration and usage:

```bash
# Check certificate validity
for cert in proxy/certs/*.crt agent/certs/*.crt; do
  echo "Certificate: $cert"
  openssl x509 -in "$cert" -noout -subject -dates
  echo "---"
done

# Set up alerts for certificates expiring in < 7 days
```

---

## Troubleshooting

### Error: "certificate signed by unknown authority"

**Cause:** Proxy doesn't have the root CA certificate

**Solution:**
```bash
# Ensure root_ca.crt is present
ls -l proxy/certs/root_ca.crt

# Copy from CA if missing
docker compose cp step-ca:/home/step/certs/root_ca.crt ./proxy/certs/
```

### Error: "tls: bad certificate"

**Cause:** Agent certificate is invalid or expired

**Solution:**
```bash
# Check certificate validity
openssl x509 -in agent/certs/agent-01.crt -noout -dates

# Renew if expired
docker compose exec step-ca step ca renew \
  /home/step/certs/agent-01.crt \
  /home/step/certs/agent-01.key
```

### Error: "connection refused"

**Cause:** Proxy not accepting TLS connections

**Solution:**
```bash
# Check proxy is running
docker compose ps proxy

# Check proxy logs
docker compose logs proxy | grep -i tls

# Verify certificate paths in configuration
```

### Error: "certificate has expired"

**Cause:** Certificate past its validity period

**Solution:**
```bash
# Generate new certificate
docker compose exec step-ca step ca certificate \
  "agent-01" \
  /home/step/certs/agent-01-new.crt \
  /home/step/certs/agent-01-new.key

# Replace old certificate
mv agent/certs/agent-01.crt agent/certs/agent-01.crt.old
docker compose cp step-ca:/home/step/certs/agent-01-new.crt ./agent/certs/agent-01.crt
```

---

## Testing mTLS

### Manual Testing

```bash
# 1. Test without client certificate (should fail)
curl -k https://localhost:3000/health

# 2. Test with client certificate (should succeed)
curl --cacert proxy/certs/root_ca.crt \
     --cert agent/certs/agent-01.crt \
     --key agent/certs/agent-01.key \
     https://localhost:3000/health

# 3. Test with invalid certificate (should fail)
curl --cacert proxy/certs/root_ca.crt \
     --cert invalid.crt \
     --key invalid.key \
     https://localhost:3000/health
```

### Automated Testing

Create `tests/test_mtls.sh`:

```bash
#!/bin/bash
set -e

echo "Testing mTLS implementation..."

# Test 1: Valid certificate
echo "✓ Test 1: Valid client certificate"
response=$(curl -s -o /dev/null -w "%{http_code}" \
  --cacert proxy/certs/root_ca.crt \
  --cert agent/certs/agent-01.crt \
  --key agent/certs/agent-01.key \
  https://localhost:3000/health)

if [ "$response" = "200" ]; then
  echo "  ✅ PASS"
else
  echo "  ❌ FAIL (got $response)"
  exit 1
fi

# Test 2: No client certificate
echo "✓ Test 2: No client certificate"
response=$(curl -s -o /dev/null -w "%{http_code}" -k \
  https://localhost:3000/health 2>&1 || true)

if [ "$response" != "200" ]; then
  echo "  ✅ PASS (rejected as expected)"
else
  echo "  ❌ FAIL (should have been rejected)"
  exit 1
fi

echo "✅ All mTLS tests passed"
```

---

## Production Deployment

### Certificate Management in Production

1. **Use Hardware Security Modules (HSM)** for CA key storage
2. **Implement automated certificate rotation**
3. **Use separate CAs for different environments**
4. **Monitor certificate expiration** with alerts
5. **Maintain certificate revocation lists (CRL)**

### Example Production Setup

```yaml
# docker-compose.prod.yml
services:
  step-ca:
    environment:
      - DOCKER_STEPCA_INIT_NAME=SLAPENIR-CA-PROD
      - DOCKER_STEPCA_INIT_DNS_NAMES=ca.slapenir.com
      - DOCKER_STEPCA_INIT_PROVISIONER_NAME=prod-provisioner
    volumes:
      - /secure/ca-data:/home/step
    networks:
      - prod-internal
    restart: always

  proxy:
    environment:
      - MTLS_ENFORCE=true
      - MTLS_CA_CERT=/run/secrets/root_ca
      - MTLS_SERVER_CERT=/run/secrets/proxy_cert
      - MTLS_SERVER_KEY=/run/secrets/proxy_key
    secrets:
      - root_ca
      - proxy_cert
      - proxy_key

secrets:
  root_ca:
    external: true
  proxy_cert:
    external: true
  proxy_key:
    external: true
```

---

## Reference

### Certificate Files

| File | Purpose | Location |
|------|---------|----------|
| `root_ca.crt` | Root CA certificate | Both proxy and agent |
| `proxy.crt` | Proxy server certificate | Proxy only |
| `proxy.key` | Proxy private key | Proxy only (secret) |
| `agent-XX.crt` | Agent client certificate | Specific agent |
| `agent-XX.key` | Agent private key | Specific agent (secret) |

### Ports

| Port | Service | Protocol |
|------|---------|----------|
| 9000 | Step-CA | HTTPS |
| 3000 | Proxy | HTTPS (mTLS) |

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `MTLS_ENFORCE` | Enforce mTLS verification | `false` |
| `MTLS_CA_CERT` | Path to CA certificate | `certs/root_ca.crt` |
| `MTLS_SERVER_CERT` | Path to server certificate | `certs/proxy.crt` |
| `MTLS_SERVER_KEY` | Path to server private key | `c