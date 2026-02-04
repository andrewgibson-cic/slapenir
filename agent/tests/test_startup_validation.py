#!/usr/bin/env python3
"""
Startup Validation Tests for SLAPENIR
Tests mTLS, proxy routing, and credential injection on startup
"""

import os
import sys
import requests
import subprocess
from typing import Tuple

# Colors for output
GREEN = '\033[0;32m'
RED = '\033[0;31m'
BLUE = '\033[0;34m'
YELLOW = '\033[1;33m'
NC = '\033[0m'


def print_test(name: str):
    """Print test name"""
    print(f"\n{BLUE}🧪 {name}{NC}")


def print_success(message: str):
    """Print success message"""
    print(f"{GREEN}✅ {message}{NC}")


def print_error(message: str):
    """Print error message"""
    print(f"{RED}❌ {message}{NC}")


def print_warning(message: str):
    """Print warning message"""
    print(f"{YELLOW}⚠️  {message}{NC}")


def test_container_to_proxy() -> bool:
    """Test connectivity from agent to proxy container"""
    print_test("Container-to-Container: Agent → Proxy")
    
    try:
        # Test direct connection to proxy health endpoint
        response = requests.get('http://proxy:3000/health', timeout=5)
        if response.status_code == 200:
            print_success("Agent can reach proxy container directly")
            return True
        else:
            print_error(f"Proxy health check failed with status: {response.status_code}")
            return False
    except requests.exceptions.ConnectionError as e:
        print_error(f"Cannot connect to proxy container: {e}")
        return False
    except Exception as e:
        print_error(f"Unexpected error connecting to proxy: {e}")
        return False


def test_dns_resolution() -> bool:
    """Test DNS resolution works"""
    print_test("DNS Resolution Test")
    
    import socket
    
    domains_to_test = [
        ('proxy', 'Internal proxy service'),
        ('google.com', 'External internet'),
        ('github.com', 'GitHub API'),
    ]
    
    all_resolved = True
    for domain, description in domains_to_test:
        try:
            ip = socket.gethostbyname(domain)
            print_success(f"{description} ({domain}) resolves to: {ip}")
        except socket.gaierror as e:
            print_error(f"Cannot resolve {domain}: {e}")
            all_resolved = False
    
    return all_resolved


def test_internet_connectivity() -> bool:
    """Test internet connectivity through proxy"""
    print_test("Internet Connectivity Test")
    
    test_urls = [
        ('https://www.google.com', 'Google'),
        ('https://api.github.com', 'GitHub API'),
        ('https://pypi.org/simple/', 'PyPI'),
    ]
    
    all_passed = True
    for url, name in test_urls:
        try:
            response = requests.get(url, timeout=10)
            if response.status_code in [200, 301, 302]:
                print_success(f"Can reach {name}: {url}")
            else:
                print_warning(f"{name} returned status {response.status_code}")
                all_passed = False
        except requests.exceptions.Timeout:
            print_error(f"Timeout connecting to {name}")
            all_passed = False
        except requests.exceptions.ConnectionError as e:
            print_error(f"Cannot connect to {name}: {e}")
            all_passed = False
        except Exception as e:
            print_error(f"Error connecting to {name}: {e}")
            all_passed = False
    
    return all_passed


def test_network_external() -> bool:
    """Test that network is external (can reach internet via proxy)"""
    print_test("Network External Test (Legacy)")
    
    try:
        response = requests.get('https://www.google.com', timeout=10)
        if response.status_code == 200:
            print_success("Network is external - can reach internet via proxy")
            return True
        else:
            print_error(f"Unexpected status code: {response.status_code}")
            return False
    except Exception as e:
        print_error(f"Cannot reach internet: {e}")
        return False


def test_proxy_routing() -> bool:
    """Test that requests are routed through proxy"""
    print_test("Proxy Routing Test")
    
    http_proxy = os.getenv('HTTP_PROXY')
    https_proxy = os.getenv('HTTPS_PROXY')
    
    if not http_proxy or not https_proxy:
        print_error("HTTP_PROXY or HTTPS_PROXY not set")
        return False
    
    if 'proxy:3000' not in http_proxy or 'proxy:3000' not in https_proxy:
        print_error(f"Proxy not configured correctly: HTTP_PROXY={http_proxy}, HTTPS_PROXY={https_proxy}")
        return False
    
    print_success(f"Proxy configured: {http_proxy}")
    
    try:
        response = requests.get('http://proxy:3000/health', timeout=5)
        if response.status_code == 200:
            print_success("Proxy is reachable and healthy")
            return True
        else:
            print_warning(f"Proxy returned status: {response.status_code}")
            return False
    except Exception as e:
        print_error(f"Cannot reach proxy: {e}")
        return False


def test_mtls_enabled() -> bool:
    """Test that mTLS is enabled"""
    print_test("mTLS Configuration Test")
    
    mtls_enabled = os.getenv('MTLS_ENABLED')
    mtls_ca_cert = os.getenv('MTLS_CA_CERT')
    mtls_client_cert = os.getenv('MTLS_CLIENT_CERT')
    mtls_client_key = os.getenv('MTLS_CLIENT_KEY')
    mtls_verify_hostname = os.getenv('MTLS_VERIFY_HOSTNAME')
    
    if mtls_enabled != 'true':
        print_error(f"mTLS not enabled: MTLS_ENABLED={mtls_enabled}")
        return False
    
    print_success("mTLS is enabled")
    
    certs_to_check = [
        ('CA Cert', mtls_ca_cert),
        ('Client Cert', mtls_client_cert),
        ('Client Key', mtls_client_key)
    ]
    
    all_exist = True
    for name, path in certs_to_check:
        if path and os.path.exists(path):
            print_success(f"{name} exists: {path}")
        else:
            print_warning(f"{name} not found: {path}")
            all_exist = False
    
    if mtls_verify_hostname == 'true':
        print_success("Hostname verification enabled")
    else:
        print_warning(f"Hostname verification: {mtls_verify_hostname}")
    
    return all_exist


def test_dummy_credentials() -> bool:
    """Test that agent has dummy credentials only"""
    print_test("Dummy Credentials Test")
    
    openai_key = os.getenv('OPENAI_API_KEY', '')
    anthropic_key = os.getenv('ANTHROPIC_API_KEY', '')
    github_token = os.getenv('GITHUB_TOKEN', '')
    
    all_dummy = True
    
    if openai_key.startswith('DUMMY'):
        print_success(f"OpenAI key is dummy: {openai_key}")
    elif openai_key:
        print_error(f"OpenAI key might be real: {openai_key[:10]}...")
        all_dummy = False
    else:
        print_warning("OpenAI key not set")
    
    if anthropic_key.startswith('DUMMY'):
        print_success(f"Anthropic key is dummy: {anthropic_key}")
    elif anthropic_key:
        print_error(f"Anthropic key might be real: {anthropic_key[:10]}...")
        all_dummy = False
    else:
        print_warning("Anthropic key not set")
    
    if github_token.startswith('DUMMY'):
        print_success(f"GitHub token is dummy: {github_token}")
    elif github_token:
        print_error(f"GitHub token might be real: {github_token[:10]}...")
        all_dummy = False
    else:
        print_warning("GitHub token not set")
    
    return all_dummy


def test_env_source_readonly() -> bool:
    """Test that .env.source is read-only"""
    print_test("Source Env File Protection Test")
    
    source_path = '/tmp/.env.source'
    
    if not os.path.exists(source_path):
        print_warning(f"Source file not found: {source_path}")
        return True
    
    try:
        with open(source_path, 'a') as f:
            f.write('\n# test\n')
        print_error("Source file is writable! Should be read-only")
        return False
    except (IOError, PermissionError):
        print_success("Source file is read-only (as expected)")
        return True


def test_credential_injection() -> bool:
    """Test that proxy injection setup is correct"""
    print_test("Credential Injection Setup Test")
    
    http_proxy = os.getenv('HTTP_PROXY')
    if not http_proxy:
        print_error("HTTP_PROXY not set - injection won't work")
        return False
    
    if not os.getenv('OPENAI_API_KEY', '').startswith('DUMMY'):
        print_warning("No dummy credentials - injection test cannot verify")
        return True
    
    print_success("Setup correct for credential injection")
    print_warning("Full injection test requires making actual API call")
    return True


def run_all_tests() -> Tuple[int, int]:
    """Run all tests and return (passed, total)"""
    tests = [
        ("DNS Resolution", test_dns_resolution),
        ("Container-to-Container", test_container_to_proxy),
        ("Internet Connectivity", test_internet_connectivity),
        ("Network External", test_network_external),
        ("Proxy Routing", test_proxy_routing),
        ("mTLS Enabled", test_mtls_enabled),
        ("Dummy Credentials", test_dummy_credentials),
        ("Env Source Read-Only", test_env_source_readonly),
        ("Credential Injection", test_credential_injection),
    ]
    
    print(f"\n{BLUE}{'='*60}{NC}")
    print(f"{BLUE}SLAPENIR Startup Validation Tests{NC}")
    print(f"{BLUE}{'='*60}{NC}")
    
    passed = 0
    total = len(tests)
    
    for name, test_func in tests:
        try:
            if test_func():
                passed += 1
        except Exception as e:
            print_error(f"Test '{name}' failed with exception: {e}")
    
    return passed, total


def main():
    """Main entry point"""
    passed, total = run_all_tests()
    
    print(f"\n{BLUE}{'='*60}{NC}")
    if passed == total:
        print(f"{GREEN}✅ All tests passed: {passed}/{total}{NC}")
        sys.exit(0)
    else:
        print(f"{YELLOW}⚠️  Some tests failed: {passed}/{total} passed{NC}")
        sys.exit(1)


if __name__ == '__main__':
    main()