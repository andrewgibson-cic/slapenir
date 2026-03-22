#!/bin/bash

DB_PATH="/home/agent/.local/share/mcp-knowledge/lancedb"
CACHE_DIR="/home/agent/.cache/huggingface"
export HF_HUB_OFFLINE=1

DEBUG=0
RECURSIVE=false
TARGET_DIR=""

usage() {
    echo "Usage: $0 [OPTIONS] <target_directory>"
    echo ""
    echo "Options:"
    echo "  -r, --recursive    Process directories recursively"
    echo "  -d, --debug        Enable debug output"
    echo "  -h, --help         Show this help"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--recursive)
            RECURSIVE=true
            shift
            ;;
        -d|--debug)
            DEBUG=1
            shift
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo "Unknown option: $1"
            usage
            ;;
        *)
            if [[ -z "$TARGET_DIR" ]]; then
                TARGET_DIR="$1"
            fi
            shift
            ;;
    esac
done

if [[ -z "$TARGET_DIR" ]]; then
    echo "Error: No target directory specified"
    usage
fi

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Error: Directory not found: $TARGET_DIR"
    exit 1
fi

TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

echo "=== MCP Knowledge Ingest ==="
echo "Target: $TARGET_DIR"
echo "Recursive: $RECURSIVE"
echo ""

if $RECURSIVE; then
    mapfile -t FILES < <(find "$TARGET_DIR" -name "*.md" -type f | sort)
else
    mapfile -t FILES < <(find "$TARGET_DIR" -maxdepth 1 -name "*.md" -type f | sort)
fi

TOTAL=${#FILES[@]}
echo "Found $TOTAL markdown file(s)"
echo ""

if [[ $TOTAL -eq 0 ]]; then
    echo "No markdown files to process."
    exit 0
fi

SUCCEEDED=0
FAILED=0

for file in "${FILES[@]}"; do
    filename=$(basename "$file")
    printf "  %s... " "$filename"
    
    if npx mcp-local-rag --db-path "$DB_PATH" --cache-dir "$CACHE_DIR" ingest "$file" >/dev/null 2>&1; then
        echo "OK"
        SUCCEEDED=$((SUCCEEDED + 1))
    else
        echo "FAILED"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "=== Summary ==="
echo "Total: $TOTAL"
echo "Succeeded: $SUCCEEDED"
echo "Failed: $FAILED"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
