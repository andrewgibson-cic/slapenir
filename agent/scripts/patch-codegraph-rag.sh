#!/bin/bash
# Patch code-graph-rag to fix missing tool descriptions
# Bug: semantic_search and get_function_source tools have null descriptions
# Upstream issue: https://github.com/vitali87/code-graph-rag (needs fix)

set -e

TOOL_FILE="/usr/lib/python3.13/site-packages/codebase_rag/tools/semantic_search.py"

if [ ! -f "$TOOL_FILE" ]; then
    echo "ERROR: $TOOL_FILE not found"
    exit 1
fi

# Fix semantic_search tool - add missing description parameter
sed -i 's/return Tool(semantic_search_functions, name=td.AgenticToolName.SEMANTIC_SEARCH)/return Tool(semantic_search_functions, name=td.AgenticToolName.SEMANTIC_SEARCH, description=td.SEMANTIC_SEARCH)/' \
    "$TOOL_FILE"

# Fix get_function_source tool - add missing description parameter
sed -i 's/return Tool(get_function_source_by_id, name=td.AgenticToolName.GET_FUNCTION_SOURCE)/return Tool(get_function_source_by_id, name=td.AgenticToolName.GET_FUNCTION_SOURCE, description=td.GET_FUNCTION_SOURCE)/' \
    "$TOOL_FILE"

echo "Patched code-graph-rag tool descriptions"
