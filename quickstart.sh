#!/bin/bash
set -e

echo "=========================================="
echo "  SLAPENIR Quickstart Setup"
echo "=========================================="
echo ""

# Check prerequisites
echo "📋 Checking prerequisites..."

command -v docker >/dev/null 2>&1 || { echo "❌ Docker is required but not installed. Aborting." >&2; exit 1; }
command -v docker-compose >/dev/null 2>&1 || command -v docker compose >/dev/null 2>&1 || { echo "❌ Docker Compose is required but not installed. Aborting." >&2; exit 1; }

echo "✅ Docker found"
echo "✅ Docker Compose found"
echo ""

# Initialize step-ca and generate certificates
echo "🔐 Setting up mTLS certificates..."
./scripts/init-step-ca.sh
echo "✅ Certificates generated"
echo ""

# Build and start services
echo "🚀 Building and starting SLAPENIR services..."
docker-compose up -d --build

echo ""
echo "⏳ Waiting for services to be ready..."
sleep 8

# Check service health
echo ""
echo "🏥 Checking service health..."

# Check proxy health
if curl -s http://localhost:3000/health > /dev/null 2>&1; then
    echo "✅ Proxy is healthy (http://localhost:3000)"
else
    echo "⚠️  Proxy health check failed (may still be starting)"
fi

# Check Step CA health
if curl -s -k https://localhost:9000/health > /dev/null 2>&1; then
    echo "✅ Step CA is healthy (https://localhost:9000)"
else
    echo "⚠️  Step CA health check failed (may still be starting)"
fi

# Check Prometheus
if curl -s http://localhost:9090/-/healthy > /dev/null 2>&1; then
    echo "✅ Prometheus is healthy (http://localhost:9090)"
else
    echo "⚠️  Prometheus health check failed (may still be starting)"
fi

# Check Grafana
if curl -s http://localhost:3001/api/health > /dev/null 2>&1; then
    echo "✅ Grafana is healthy (http://localhost:3001)"
else
    echo "⚠️  Grafana health check failed (may still be starting)"
fi

echo ""
echo "=========================================="
echo "  ✨ SLAPENIR is ready!"
echo "=========================================="
echo ""
echo "📊 Access Points:"
echo "  • Proxy:      http://localhost:3000"
echo "  • Metrics:    http://localhost:3000/metrics"
echo "  • Prometheus: http://localhost:9090"
echo "  • Grafana:    http://localhost:3001 (admin/admin)"
echo ""
echo "🔍 View Logs:"
echo "  docker-compose logs -f proxy"
echo "  docker-compose logs -f agent"
echo ""
echo "🛑 Stop Services:"
echo "  docker-compose down"
echo ""
echo "📚 Documentation:"
echo "  README.md - Quick reference"
echo "  docs/ - Detailed guides"
echo ""