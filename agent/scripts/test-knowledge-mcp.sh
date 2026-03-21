#!/bin/bash
# Test MCP Knowledge Server by sending actual MCP request
# This simulates what OpenCode does when you say "Index the docs directory"

set -e

echo "=== Testing MCP Knowledge Server ==="
echo ""

# Set environment variables
export MODEL_NAME="Xenova/all-MiniLM-L6-v2"
export TRANSFORMERS_CACHE="/home/agent/.cache/huggingface"
export BASE_DIR="/home/agent/workspace/docs"
export HF_HOME="/home/agent/.cache/huggingface"

echo "Environment:"
echo "  MODEL_NAME: $MODEL_NAME"
echo "  TRANSFORMERS_CACHE: $TRANSFORMERS_CACHE"
echo "  BASE_DIR: $BASE_DIR"
echo ""

# Create test directory if it doesn't exist
if [ ! -d "$BASE_DIR" ]; then
    echo "Creating test docs directory..."
    mkdir -p "$BASE_DIR"
fi

# Create test file if it doesn't exist
TEST_FILE="$BASE_DIR/test-embeddings.md"
if [ ! -f "$TEST_FILE" ]; then
    echo "Creating test file: $TEST_FILE"
    cat > "$TEST_FILE" << 'EOF'
# Test Document

This is a test document for the MCP Knowledge Server.

## Features

- Semantic search with embeddings
- Document chunking
- Vector storage in LanceDB

## Architecture

The system uses:
- Xenova/all-MiniLM-L6-v2 for embeddings
- LanceDB for vector storage
- MCP protocol for communication
EOF
fi

echo "Test file: $TEST_FILE"
echo ""

# Change to mcp-local-rag directory
cd /usr/local/lib/node_modules/mcp-local-rag

echo "Starting mcp-local-rag in test mode..."
echo ""

# Create a simple test request
# This is a minimal MCP initialize request
cat > /tmp/mcp-test-request.json << 'EOF'
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}
EOF

echo "Sending MCP initialize request..."
timeout 10 node dist/index.js < /tmp/mcp-test-request.json 2>&1 | head -20

echo ""
echo "✅ Test complete"
