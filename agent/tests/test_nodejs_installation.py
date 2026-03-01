#!/usr/bin/env python3
"""
Test: Node.js Installation Verification
Specification: SPEC-001
Requirement: REQ-001

Tests verify that Node.js and npm are correctly installed in the container.
"""

import subprocess
import sys
import os


def test_node_binary_exists():
    """TEST-001-001: Verify node binary exists"""
    result = subprocess.run(['which', 'node'], capture_output=True)
    assert result.returncode == 0, "node binary not found in PATH"
    node_path = result.stdout.decode().strip()
    assert os.path.exists(node_path), f"node binary path {node_path} does not exist"
    print(f"✓ node binary found at {node_path}")


def test_npm_binary_exists():
    """TEST-001-002: Verify npm binary exists"""
    result = subprocess.run(['which', 'npm'], capture_output=True)
    assert result.returncode == 0, "npm binary not found in PATH"
    npm_path = result.stdout.decode().strip()
    assert os.path.exists(npm_path), f"npm binary path {npm_path} does not exist"
    print(f"✓ npm binary found at {npm_path}")


def test_node_version():
    """TEST-001-003: Verify node version >= 20"""
    result = subprocess.run(['node', '--version'], capture_output=True)
    assert result.returncode == 0, "node --version failed"

    version_str = result.stdout.decode().strip()
    # Version format: v20.11.0
    assert version_str.startswith('v'), f"Unexpected version format: {version_str}"

    major_version = int(version_str[1:].split('.')[0])
    assert major_version >= 20, f"Node version {version_str} is less than required v20"
    print(f"✓ node version {version_str} meets requirement (>= v20)")


def test_npm_version():
    """TEST-001-003b: Verify npm version works"""
    result = subprocess.run(['npm', '--version'], capture_output=True)
    assert result.returncode == 0, "npm --version failed"
    version = result.stdout.decode().strip()
    print(f"✓ npm version {version}")


def main():
    """Run all tests"""
    tests = [
        test_node_binary_exists,
        test_npm_binary_exists,
        test_node_version,
        test_npm_version,
    ]

    print("=== SPEC-001: Node.js Installation Tests ===\n")

    passed = 0
    failed = 0

    for test in tests:
        try:
            test()
            passed += 1
        except AssertionError as e:
            print(f"✗ {test.__name__}: {e}")
            failed += 1
        except Exception as e:
            print(f"✗ {test.__name__}: Unexpected error: {e}")
            failed += 1

    print(f"\n=== Results ===")
    print(f"Passed: {passed}")
    print(f"Failed: {failed}")

    if failed == 0:
        print("\n✅ All Node.js installation tests passed")
        return 0
    else:
        print("\n❌ Some Node.js installation tests failed")
        return 1


if __name__ == '__main__':
    sys.exit(main())
