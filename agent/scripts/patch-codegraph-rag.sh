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

CLI_FILE="/usr/lib/python3.13/site-packages/codebase_rag/cli.py"
if [ -f "$CLI_FILE" ] && grep -q "from .services.protobuf_service import" "$CLI_FILE" 2>/dev/null; then
    PROTO_FILE="/usr/lib/python3.13/site-packages/codebase_rag/services/protobuf_service.py"
    if ! python3.13 -c "import sys; sys.path.insert(0, '/usr/lib/python3.13/site-packages'); import codec" 2>/dev/null; then
        sed -i 's/^import codec.schema_pb2 as pb$/try:\n    import codec.schema_pb2 as pb\nexcept ImportError:\n    pb = None/' "$PROTO_FILE"
        sed -i 's/^from .services.protobuf_service import ProtobufFileIngestor$/try:\n    from .services.protobuf_service import ProtobufFileIngestor\nexcept ImportError:\n    ProtobufFileIngestor = None/' "$CLI_FILE"
        echo "Patched protobuf imports (codec module not available)"
    fi
fi

echo "Patched code-graph-rag tool descriptions"
