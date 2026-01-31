#!/bin/sh
# SLAPENIR Certificate Bootstrap Script
# Obtains client certificates from Step-CA for mTLS authentication

set -e

CERT_DIR="/home/agent/certs"
CA_URL="${STEP_CA_URL:-https://ca:9000}"
PROVISIONER="${STEP_PROVISIONER:-agent-provisioner}"

echo "[bootstrap] Starting certificate bootstrap process..."
echo "[bootstrap] CA URL: $CA_URL"
echo "[bootstrap] Provisioner: $PROVISIONER"

# Check if we have an enrollment token
if [ -z "$STEP_TOKEN" ]; then
    echo "[bootstrap] ERROR: STEP_TOKEN environment variable not set"
    echo "[bootstrap] Cannot obtain certificates without enrollment token"
    exit 1
fi

# Create cert directory if it doesn't exist
mkdir -p "$CERT_DIR"

# Bootstrap step-cli to trust the CA
echo "[bootstrap] Bootstrapping step-cli with CA..."
step ca bootstrap \
    --ca-url "$CA_URL" \
    --fingerprint "${STEP_FINGERPRINT:-auto}" \
    --install \
    || {
        echo "[bootstrap] WARNING: Failed to bootstrap CA, will try direct certificate request"
    }

# Request certificate from CA
echo "[bootstrap] Requesting client certificate..."
step ca certificate \
    "agent.slapenir.local" \
    "$CERT_DIR/cert.pem" \
    "$CERT_DIR/key.pem" \
    --provisioner "$PROVISIONER" \
    --token "$STEP_TOKEN" \
    --ca-url "$CA_URL" \
    --not-after "720h" \
    || {
        echo "[bootstrap] ERROR: Failed to obtain certificate from CA"
        exit 1
    }

# Download root CA certificate
echo "[bootstrap] Downloading root CA certificate..."
step ca root "$CERT_DIR/root_ca.pem" \
    --ca-url "$CA_URL" \
    || {
        echo "[bootstrap] ERROR: Failed to download root CA"
        exit 1
    }

# Set proper permissions
chmod 600 "$CERT_DIR/key.pem"
chmod 644 "$CERT_DIR/cert.pem" "$CERT_DIR/root_ca.pem"

echo "[bootstrap] Certificate bootstrap complete!"
echo "[bootstrap] Certificates stored in: $CERT_DIR"
echo "[bootstrap] Certificate valid until: $(step certificate inspect --short $CERT_DIR/cert.pem | grep 'Not After')"

exit 0