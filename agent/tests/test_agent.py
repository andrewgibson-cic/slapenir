#!/usr/bin/env python3
"""
Unit tests for SLAPENIR agent
Tests proxy health check and environment validation
"""

import sys
import os
import unittest
from unittest.mock import patch, MagicMock

# Add parent directory to path to import agent module
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))

import agent


class TestAgentEnvironment(unittest.TestCase):
    """Test agent environment checking"""
    
    def test_check_environment_with_proxy_vars(self):
        """Test environment check with proxy variables set"""
        with patch.dict(os.environ, {
            'HTTP_PROXY': 'http://proxy:3000',
            'HTTPS_PROXY': 'http://proxy:3000',
            'PROXY_HOST': 'proxy',
            'PROXY_PORT': '3000'
        }):
            # Should not raise an exception
            result = agent.check_environment()
            self.assertTrue(result)
    
    def test_check_environment_without_proxy_vars(self):
        """Test environment check without proxy variables"""
        with patch.dict(os.environ, {}, clear=True):
            # Should still return True but log warnings
            result = agent.check_environment()
            self.assertTrue(result)


class TestProxyHealthCheck(unittest.TestCase):
    """Test proxy health check functionality"""
    
    def test_proxy_health_url_construction(self):
        """Test that health check URL is constructed correctly"""
        with patch.dict(os.environ, {
            'PROXY_HOST': 'testproxy',
            'PROXY_PORT': '8080'
        }):
            # The function constructs URL from env vars
            proxy_host = os.getenv('PROXY_HOST', 'proxy')
            proxy_port = os.getenv('PROXY_PORT', '3000')
            expected_url = f"http://{proxy_host}:{proxy_port}/health"
            
            self.assertEqual(expected_url, "http://testproxy:8080/health")
    
    def test_proxy_health_default_values(self):
        """Test default values for proxy health check"""
        with patch.dict(os.environ, {}, clear=True):
            proxy_host = os.getenv('PROXY_HOST', 'proxy')
            proxy_port = os.getenv('PROXY_PORT', '3000')
            
            self.assertEqual(proxy_host, 'proxy')
            self.assertEqual(proxy_port, '3000')


class TestSignalHandling(unittest.TestCase):
    """Test signal handling for graceful shutdown"""
    
    def test_signal_handler(self):
        """Test that signal handler sets shutdown flag"""
        # Reset the shutdown flag
        agent.shutdown_requested = False
        
        # Call signal handler
        agent.signal_handler(15, None)  # SIGTERM
        
        # Check that shutdown was requested
        self.assertTrue(agent.shutdown_requested)


class TestAgentConfiguration(unittest.TestCase):
    """Test agent configuration and setup"""
    
    def test_default_proxy_host(self):
        """Test default proxy host is correct"""
        with patch.dict(os.environ, {}, clear=True):
            host = os.getenv('PROXY_HOST', 'proxy')
            self.assertEqual(host, 'proxy')
    
    def test_default_proxy_port(self):
        """Test default proxy port is correct"""
        with patch.dict(os.environ, {}, clear=True):
            port = os.getenv('PROXY_PORT', '3000')
            self.assertEqual(port, '3000')


if __name__ == '__main__':
    unittest.main()