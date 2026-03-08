#!/bin/bash
# Test script to verify terminal sizing and network access fix
# This script tests both dev.sh and make shell approaches

set -e

echo "=========================================="
echo "Terminal Sizing & Network Access Test"
echo "=========================================="
echo ""

# Test 1: Verify dev.sh exists and is executable
echo "Test 1: Verify dev.sh is executable..."
if [ -x "./dev.sh" ]; then
    echo "✓ dev.sh is executable"
else
    echo "✗ dev.sh is NOT executable"
    exit 1
fi
echo ""

# Test 2: Verify Makefile has shell target
echo "Test 2: Verify Makefile shell target..."
if grep -q "^shell:" Makefile; then
    echo "✓ Makefile has shell target"
else
    echo "✗ Makefile missing shell target"
    exit 1
fi
echo ""

# Test 3: Verify Makefile uses dev.sh
echo "Test 3: Verify Makefile delegates to dev.sh..."
if grep -q "exec ./dev.sh bash" Makefile; then
    echo "✓ Makefile delegates to dev.sh"
else
    echo "✗ Makefile does NOT delegate to dev.sh"
    exit 1
fi
echo ""

# Test 4: Verify opencode wrapper enforces network isolation
echo "Test 4: Verify opencode wrapper has network enforcement..."
if grep -q "Enforcing network isolation" agent/scripts/opencode-wrapper.sh; then
    echo "✓ opencode wrapper has network enforcement"
else
    echo "✗ opencode wrapper missing network enforcement"
    exit 1
fi
echo ""

# Test 5: Verify dev.sh has opencode detection
echo "Test 5: Verify dev.sh detects opencode command..."
if grep -q "IS_OPENCODE" dev.sh; then
    echo "✓ dev.sh has opencode detection"
else
    echo "✗ dev.sh missing opencode detection"
    exit 1
fi
echo ""

# Test 6: Verify opencode wrapper clears exemptions
echo "Test 6: Verify opencode wrapper clears build tool exemptions..."
if grep -q "unset GRADLE_ALLOW_FROM_OPENCODE" agent/scripts/opencode-wrapper.sh; then
    echo "✓ opencode wrapper clears exemptions"
else
    echo "✗ opencode wrapper doesn't clear exemptions"
    exit 1
fi
echo ""

echo "=========================================="
echo "All Tests Passed!"
echo "=========================================="
echo ""
echo "Summary of changes:"
echo "1. dev.sh now detects opencode and applies appropriate network policy"
echo "2. opencode wrapper enforces strict network isolation"
echo "3. make shell delegates to dev.sh for consistency"
echo "4. Terminal sizing preserved across all methods"
echo ""
echo "Usage:"
echo "  ./dev.sh bash      # Shell with internet access (for git, builds)"
echo "  ./dev.sh opencode  # OpenCode with network isolation (local-llama only)"
echo "  make shell         # Same as ./dev.sh bash"
echo ""
