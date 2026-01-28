#!/bin/bash
# SLAPENIR System Test Script
# Quick validation of the complete system setup

set -e

echo "🔍 SLAPENIR System Validation"
echo "================================"
echo ""

# Check Docker
echo "✓ Checking Docker..."
if ! docker --version > /dev/null 2>&1; then
    echo "❌ Docker not found"
    exit 1
fi
echo "  $(docker --version)"

# Check Docker Compose
echo "✓ Checking Docker Compose..."
if ! docker compose version > /dev/null 2>&1; then
    echo "❌ Docker Compose not found"
    exit 1
fi
echo "  $(docker compose version)"

# Validate docker-compose.yml
echo "✓ Validating docker-compose.yml..."
docker compose config > /dev/null
echo "  Configuration valid"

# Check Rust
echo "✓ Checking Rust..."
if ! rustc --version > /dev/null 2>&1; then
    echo "❌ Rust not found"
    exit 1
fi
echo "  $(rustc --version)"

# Check required files
echo "✓ Checking required files..."
files=(
    "proxy/Cargo.toml"
    "proxy/Dockerfile"
    "proxy/src/main.rs"
    "proxy/src/sanitizer.rs"
    "proxy/src/middleware.rs"
    "agent/Dockerfile"
    "agent/scripts/agent.py"
    "docker-compose.yml"
    "PROGRESS.md"
)

for file in "${files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "  ❌ Missing: $file"
        exit 1
    fi
done
echo "  All required files present"

# Run proxy tests
echo "✓ Running proxy tests..."
cd proxy
cargo test --quiet 2>&1 | tail -3
cd ..

echo ""
echo "================================"
echo "✅ System validation complete!"
echo ""
echo "Next steps:"
echo "  1. Build and start: docker compose up --build"
echo "  2. Test proxy health: curl http://localhost:3000/health"
echo "  3. View logs: docker compose logs -f"
echo ""