#!/bin/bash
# MCP Memory Reset Script
# Usage: ~/scripts/reset-memory.sh

set -e

MEMORY_DB="/home/agent/.local/share/mcp-memory/memory.db"
KNOWLEDGE_DB="/home/agent/.local/share/mcp-knowledge"

echo "Resetting MCP memory and knowledge..."

# Reset memory database
if [ -f "$MEMORY_DB" ]; then
    rm -f "$MEMORY_DB"
    echo "✓ Memory database deleted"
else
    echo "ℹ No memory database found (already clean)"
fi

# Reset knowledge database (LanceDB)
if [ -d "$KNOWLEDGE_DB" ] && [ "$(ls -A $KNOWLEDGE_DB 2>/dev/null)" ]; then
    rm -rf "$KNOWLEDGE_DB"/*
    echo "✓ Knowledge database cleared"
else
    echo "ℹ No knowledge database found (already clean)"
fi

echo ""
echo "Memory reset complete. Ready for fresh start."
