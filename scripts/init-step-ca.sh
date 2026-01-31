#!/bin/bash
# SLAPENIR: Step-CA Initialization Script
# This script properly initializes Step-CA with correct permissions

set -e

echo "🔐 SLAPENIR Step-CA Initialization"
echo "==================================="

CA_NAME="SLAPENIR-CA"
CA_DNS="ca,step-ca,localhost"
CA_ADDRESS=":9000"
PROVISIONER="admin"
PASSWORD="slapenir-dev-password-change-in-prod"

# Create data directory if it doesn't exist
mkdir -p ./ca-data

echo "📦 Starting Step-CA container for initialization..."

# Create a temporary password file (process substitution doesn't work in docker)
TEMP_PASS_FILE="$(pwd)/ca-data/.temp_password"
echo "${PASSWORD}" > "${TEMP_PASS_FILE}"

docker run --rm \
  -v "$(pwd)/ca-/home/step" \
  -e "DOCKER_STEPCA_INIT_NAME=${CA_NAME}" \
  -e "DOCKER_STEPCA_INIT_DNS_NAMES=${CA_DNS}" \
  -e "DOCKER_STEPCA_INIT_ADDRESS=${CA_ADDRESS}" \
  -e "DOCKER_STEPCA_INIT_PROVISIONER_NAME=${PROVISIONER}" \
  -e "DOCKER_STEPCA_INIT_PASSWORD=${PASSWORD}" \
  smallstep/step-ca:latest

# Clean up password file
rm -f "${TEMP_PASS_FILE}"

echo ""
echo "✅ Step-CA initialized successfully!"
echo ""
echo "📋 Certificate Authority Details:"
echo "   Name: ${CA_NAME}"
echo "   Address: ${CA_ADDRESS}"
echo "   DNS Names: ${CA_DNS}"
echo "   Provisioner: ${PROVISIONER}"
echo ""
echo "🔑 Root CA Certificate:"
cat ./ca-data/certs/root_ca.crt
echo ""
echo "🚀 Ready to start services with: docker compose up -d"