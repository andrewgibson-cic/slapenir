#!/bin/bash
# Wrapper script for ingesting files into the MCP knowledge database
# Usage: ingest-knowledge.sh [--reingest] [--dry-run] [--verbose] [TARGET_DIR]
#
# Defaults to ingesting all supported files from /home/agent/workspace/docs
# Supports: .md, .pdf, .docx, .txt, .html, .htm

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INGEST_MJS="${SCRIPT_DIR}/ingest-via-mcp.mjs"

if [ ! -f "$INGEST_MJS" ]; then
    echo "Error: ingest-via-mcp.mjs not found at ${INGEST_MJS}" >&2
    exit 1
fi

export DB_PATH="${DB_PATH:-/home/agent/.local/share/mcp-knowledge/lancedb}"
export CACHE_DIR="${CACHE_DIR:-/home/agent/.cache/huggingface}"
export BASE_DIR="${BASE_DIR:-/home/agent/workspace/docs}"
export MODEL_NAME="${MODEL_NAME:-Xenova/all-MiniLM-L6-v2}"
export HF_HUB_OFFLINE="${HF_HUB_OFFLINE:-1}"
export HF_HOME="${HF_HOME:-${CACHE_DIR}}"
export TRANSFORMERS_CACHE="${TRANSFORMERS_CACHE:-${CACHE_DIR}}"

exec node --experimental-vm-modules "$INGEST_MJS" "$@"
