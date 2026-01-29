#!/bin/bash
# SLAPENIR: mTLS Certificate Setup Script
# Generates and distributes certificates for proxy and agent

set -e

echo "🔐 SLAPENIR mTLS Certificate Setup"
echo "===================================="
echo ""

# Configuration
CA_URL="https://localhost:9000"
CA_FINGERPRINT=""
PROVISIONER="admin"
PASSWORD="slapenir-dev-password-change-in-prod"

# Check if Step-CA is running
echo "📡 Checking Step-CA availability..."
if ! docker compose ps step-ca | grep -q "Up"; then
    echo "❌ Step-CA is not running. Start it with: docker compose up -d step-ca"
    exit 1
fi

# Wait for Step-CA to be healthy
echo "⏳ Waiting for Step-CA to be healthy..."
timeout 60 bash -c 'until docker compose exec step-ca step ca health 2>/dev/null; do sleep 2; done' || {
    echo "❌ Step-CA failed to become healthy"
    exit 1
}
echo "✅ Step-CA is healthy"
echo ""

# Function to generate certificate
generate_cert() {
    local name=$1
    local output_dir=$2
    
    echo "📜 Generating certificate for: $name"
    
    docker compose exec step-ca step ca certificate \
        "$name" \
        "/home/step/certs/${name}.crt" \
        "/home/step/certs/${name}.key" \
        --provisioner="$PROVISIONER" \
        --password-file=<(echo "$PASSWORD") \
        --force
    
    echo "✅ Certificate generated for $name"
}

# Function to copy certificate from CA to volume
copy_cert_to_volume() {
    local service=$1
    local cert_name=$2
    
    echo "📦 Copying certificates to $service volume..."
    
    # Create temporary container to copy certs
    docker run --rm \
        -v "slapenir-${service}-certs:/certs" \
        -v "slapenir-ca-config:/ca-data:ro" \
        alpine sh -c "
            mkdir -p /certs && \
            cp /ca-data/certs/${cert_name}.crt /certs/${cert_name}.crt && \
            cp /ca-data/certs/${cert_name}.key /certs/${cert_name}.key && \
            cp /ca-data/certs/root_ca.crt /certs/root_ca.crt && \
            chmod 644 /certs/*.crt && \
            chmod 600 /certs/*.key && \
            ls -lh /certs/
        "
    
    echo "✅ Certificates copied to $service volume"
}

# Generate proxy certificate
echo "🔧 Setting up Proxy certificates..."
generate_cert "proxy" "proxy"
copy_cert_to_volume "proxy" "proxy"
echo ""

# Generate agent certificate
echo "🔧 Setting up Agent certificates..."
generate_cert "agent" "agent"
copy_cert_to_volume "agent" "agent"
echo ""

# Verify certificates
echo "🔍 Verifying certificates..."
echo ""

echo "Proxy certificate:"
docker run --rm -v "slapenir-proxy-certs:/certs:ro" alpine sh -c "
    ls -lh /certs/ && \
    echo '' && \
    echo 'Certificate details:' && \
    openssl x509 -in /certs/proxy.crt -noout -subject -dates 2>/dev/null || echo 'openssl not available'
"
echo ""

echo "Agent certificate:"
docker run --rm -v "slapenir-agent-certs:/certs:ro" alpine sh -c "
    ls -lh /certs/ && \
    echo '' && \
    echo 'Certificate details:' && \
    openssl x509 -in /certs/agent.crt -noout -subject -dates 2>/dev/null || echo 'openssl not available'
"
echo ""

echo "✅ Certificate setup complete!"
echo ""
echo "📋 Summary:"
echo "   - Proxy certificates: ✅ (root_ca.crt, proxy.crt, proxy.key)"
echo "   - Agent certificates: ✅ (root_ca.crt, agent.crt, agent.key)"
echo ""
echo "🚀 Next steps:"
echo "   1. Enable mTLS: export MTLS_ENABLED=true"
echo "   2. Restart services: docker compose restart proxy agent"
echo "   3. Test connection: ./scripts/test-mtls.sh"
echo ""