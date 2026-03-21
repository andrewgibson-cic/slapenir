#!/bin/bash
# MCP Integration Test Suite
# Run after deployment to verify installation

set -e

echo "=== MCP Integration Test Suite ==="
echo ""

PASSED=0
FAILED=0

test_command() {
    local name="$1"
    local cmd="$2"
    echo -n "Testing $name... "
    if eval "$cmd" >/dev/null 2>&1; then
        echo "✓ PASS"
        ((PASSED++))
    else
        echo "✗ FAIL"
        ((FAILED++))
    fi
}

# Build verification
echo "--- Build Verification ---"
test_command "Memory server installed" "docker exec slapenir-agent which mcp-server-memory"
test_command "Knowledge server installed" "docker exec slapenir-agent which mcp-local-rag"
test_command "Memory directory exists" "docker exec slapenir-agent test -d /home/agent/.local/share/mcp-memory"
test_command "Knowledge directory exists" "docker exec slapenir-agent test -d /home/agent/.local/share/mcp-knowledge"
test_command "Reset script executable" "docker exec slapenir-agent test -x /home/agent/scripts/reset-memory.sh"

# Configuration verification
echo ""
echo "--- Configuration Verification ---"
test_command "Memory config present" "docker exec slapenir-agent jq -e '.mcp.memory' /home/agent/.config/opencode/opencode.json"
test_command "Knowledge config present" "docker exec slapenir-agent jq -e '.mcp.knowledge' /home/agent/.config/opencode/opencode.json"
test_command "Memory permissions allow" "docker exec slapenir-agent jq -e '.permission."memory_*" == "allow"' /home/agent/.config/opencode/opencode.json"
test_command "Knowledge permissions allow" "docker exec slapenir-agent jq -e '.permission."knowledge_*" == "allow"' /home/agent/.config/opencode/opencode.json"

# Infrastructure verification
echo ""
echo "--- Infrastructure Verification ---"
test_command "Memory volume exists" "docker volume inspect slapenir-mcp-memory"
test_command "Knowledge volume exists" "docker volume inspect slapenir-mcp-knowledge"

# Summary
echo ""
echo "=== Test Summary ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "✓ All tests passed!"
    exit 0
else
    echo "✗ Some tests failed"
    exit 1
fi
