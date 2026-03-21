#!/bin/bash
# MCP Knowledge Server Verification Script
# Tests that the mcp-local-rag server can start and respond to requests
# Run during container startup to catch configuration issues early

set -e

echo "=== MCP Knowledge Server Verification ==="
echo ""

PASSED=0
FAILED=0

pass() {
    echo "  ✓ $1"
    ((PASSED++))
}

fail() {
    echo "  ✗ $1"
    ((FAILED++))
}

# Environment variables for MCP server
export DB_PATH="/home/agent/.local/share/mcp-knowledge/lancedb"
export CACHE_DIR="/home/agent/.cache/huggingface"
export BASE_DIR="/home/agent/workspace"
export HF_HUB_OFFLINE=1

echo "1. Checking prerequisites..."

# Check model cache exists
if [ -d "/home/agent/.cache/huggingface/models--Xenova--all-MiniLM-L6-v2" ]; then
    pass "Embedding model cached"
else
    fail "Embedding model not cached (will download at runtime)"
fi

# Check knowledge directory exists
if [ -d "/home/agent/.local/share/mcp-knowledge" ]; then
    pass "Knowledge storage directory exists"
else
    fail "Knowledge storage directory missing"
fi

# Check mcp-local-rag is installed
if command -v mcp-local-rag &>/dev/null || [ -d "/usr/local/lib/node_modules/mcp-local-rag" ]; then
    pass "mcp-local-rag installed"
else
    fail "mcp-local-rag not installed"
fi

echo ""
echo "2. Testing MCP server initialization..."

# Create a test file (needs >50 chars for chunking)
TEST_DIR="/home/agent/.local/share/mcp-knowledge-test"
mkdir -p "$TEST_DIR"
cat > "$TEST_DIR/test.md" << 'EOF'
# MCP Knowledge Test Document

This is a test document for verifying the MCP knowledge server functionality.

## Features Tested

- Document ingestion and chunking
- Semantic search with embeddings
- LanceDB vector storage
- Hybrid search (keyword + semantic)

## Expected Results

The server should:
1. Parse this markdown file
2. Create vector embeddings
3. Store chunks in LanceDB
4. Return relevant search results
EOF

# Test MCP initialize
cd /usr/local/lib/node_modules/mcp-local-rag

INIT_RESPONSE=$(timeout 30 node dist/index.js 2>&1 <<'MCP_REQUEST'
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"verify-script","version":"1.0.0"}}}
MCP_REQUEST
)

if echo "$INIT_RESPONSE" | grep -q '"result"'; then
    pass "MCP server initializes successfully"
else
    fail "MCP server initialization failed"
    echo "    Response: $(echo "$INIT_RESPONSE" | tail -5)"
fi

echo ""
echo "3. Testing document ingestion..."

INGEST_RESPONSE=$(timeout 60 node dist/index.js 2>&1 <<MCP_REQUEST
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"ingest_file","arguments":{"filePath":"$TEST_DIR/test.md"}}}
MCP_REQUEST
)

if echo "$INGEST_RESPONSE" | grep -q '"chunkCount"'; then
    CHUNKS=$(echo "$INGEST_RESPONSE" | grep -o '"chunkCount":[0-9]*' | grep -o '[0-9]*')
    pass "Document ingested successfully ($CHUNKS chunks)"
else
    fail "Document ingestion failed"
    echo "    Response: $(echo "$INGEST_RESPONSE" | tail -5)"
fi

echo ""
echo "4. Testing semantic search..."

SEARCH_RESPONSE=$(timeout 30 node dist/index.js 2>&1 <<'MCP_REQUEST'
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"query_documents","arguments":{"query":"semantic search embeddings","limit":3}}}
MCP_REQUEST
)

if echo "$SEARCH_RESPONSE" | grep -q '"score"'; then
    pass "Semantic search returns results"
else
    fail "Semantic search failed"
    echo "    Response: $(echo "$SEARCH_RESPONSE" | tail -5)"
fi

echo ""
echo "5. Testing server status..."

STATUS_RESPONSE=$(timeout 10 node dist/index.js 2>&1 <<'MCP_REQUEST'
{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"status","arguments":{}}}
MCP_REQUEST
)

if echo "$STATUS_RESPONSE" | grep -q '"chunkCount"'; then
    pass "Status endpoint working"
else
    fail "Status endpoint failed"
fi

# Cleanup test data
rm -rf "$TEST_DIR"

echo ""
echo "=== Verification Summary ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "✅ MCP Knowledge Server is fully operational"
    exit 0
else
    echo "⚠️  Some checks failed - review configuration"
    exit 1
fi
