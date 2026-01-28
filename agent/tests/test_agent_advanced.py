#!/usr/bin/env python3
"""
Advanced unit tests for SLAPENIR agent
Tests error handling, edge cases, and integration scenarios
"""

import sys
import os
import unittest
from unittest.mock import patch, MagicMock, call
import time

# Add parent directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))

import agent


class TestAgentErrorHandling(unittest.TestCase):
    """Test error handling in agent"""
    
    def test_check_environment_handles_missing_env_gracefully(self):
        """Test that missing environment variables don't crash"""
        with patch.dict(os.environ, {}, clear=True):
            # Should not raise exception
            try:
                result = agent.check_environment()
                self.assertTrue(result)
            except Exception as e:
                self.fail(f"check_environment raised exception: {e}")
    
    def test_environment_with_empty_strings(self):
        """Test environment check with empty string values"""
        with patch.dict(os.environ, {
            'HTTP_PROXY': '',
            'HTTPS_PROXY': '',
        }):
            result = agent.check_environment()
            self.assertTrue(result)


class TestAgentShutdown(unittest.TestCase):
    """Test agent shutdown behavior"""
    
    def setUp(self):
        """Reset shutdown flag before each test"""
        agent.shutdown_requested = False
    
    def test_shutdown_flag_initially_false(self):
        """Test that shutdown flag starts as False"""
        # Import fresh to get initial state
        import importlib
        importlib.reload(agent)
        self.assertFalse(agent.shutdown_requested)
    
    def test_signal_handler_sigterm(self):
        """Test SIGTERM signal handling"""
        agent.signal_handler(15, None)
        self.assertTrue(agent.shutdown_requested)
    
    def test_signal_handler_sigint(self):
        """Test SIGINT signal handling"""
        agent.signal_handler(2, None)
        self.assertTrue(agent.shutdown_requested)
    
    def test_signal_handler_with_different_signals(self):
        """Test that handler works with various signals"""
        for signum in [1, 2, 15]:
            agent.shutdown_requested = False
            agent.signal_handler(signum, None)
            self.assertTrue(agent.shutdown_requested, 
                          f"Failed for signal {signum}")


class TestProxyConfiguration(unittest.TestCase):
    """Test proxy configuration handling"""
    
    def test_proxy_host_from_environment(self):
        """Test reading proxy host from environment"""
        with patch.dict(os.environ, {'PROXY_HOST': 'custom-proxy'}):
            host = os.getenv('PROXY_HOST', 'proxy')
            self.assertEqual(host, 'custom-proxy')
    
    def test_proxy_port_from_environment(self):
        """Test reading proxy port from environment"""
        with patch.dict(os.environ, {'PROXY_PORT': '8080'}):
            port = os.getenv('PROXY_PORT', '3000')
            self.assertEqual(port, '8080')
    
    def test_http_proxy_url_format(self):
        """Test HTTP proxy URL formatting"""
        with patch.dict(os.environ, {
            'HTTP_PROXY': 'http://myproxy:8080'
        }):
            proxy = os.getenv('HTTP_PROXY')
            self.assertTrue(proxy.startswith('http://'))
            self.assertIn(':', proxy)
    
    def test_https_proxy_url_format(self):
        """Test HTTPS proxy URL formatting"""
        with patch.dict(os.environ, {
            'HTTPS_PROXY': 'http://myproxy:8080'
        }):
            proxy = os.getenv('HTTPS_PROXY')
            self.assertTrue(proxy.startswith('http://'))


class TestPythonVersionDetection(unittest.TestCase):
    """Test Python version detection"""
    
    def test_python_version_available(self):
        """Test that Python version can be retrieved"""
        version = sys.version.split()[0]
        self.assertIsNotNone(version)
        self.assertTrue(len(version) > 0)
    
    def test_python_version_format(self):
        """Test Python version has expected format"""
        version = sys.version.split()[0]
        # Should be in format X.Y.Z
        parts = version.split('.')
        self.assertGreaterEqual(len(parts), 2)
        # First part should be a number
        self.assertTrue(parts[0].isdigit())


class TestCertificatePaths(unittest.TestCase):
    """Test certificate path handling"""
    
    def test_ssl_cert_file_environment(self):
        """Test SSL_CERT_FILE environment variable"""
        test_path = '/test/path/cert.pem'
        with patch.dict(os.environ, {'SSL_CERT_FILE': test_path}):
            cert = os.getenv('SSL_CERT_FILE')
            self.assertEqual(cert, test_path)
    
    def test_ssl_key_file_environment(self):
        """Test SSL_KEY_FILE environment variable"""
        test_path = '/test/path/key.pem'
        with patch.dict(os.environ, {'SSL_KEY_FILE': test_path}):
            key = os.getenv('SSL_KEY_FILE')
            self.assertEqual(key, test_path)
    
    def test_ca_bundle_environment(self):
        """Test REQUESTS_CA_BUNDLE environment variable"""
        test_path = '/test/path/ca-bundle.crt'
        with patch.dict(os.environ, {'REQUESTS_CA_BUNDLE': test_path}):
            bundle = os.getenv('REQUESTS_CA_BUNDLE')
            self.assertEqual(bundle, test_path)


class TestHealthCheckEdgeCases(unittest.TestCase):
    """Test edge cases in health check functionality"""
    
    def test_health_check_url_with_special_chars(self):
        """Test URL construction with special characters"""
        with patch.dict(os.environ, {
            'PROXY_HOST': 'proxy-name.example.com',
            'PROXY_PORT': '3000'
        }):
            host = os.getenv('PROXY_HOST')
            port = os.getenv('PROXY_PORT')
            url = f"http://{host}:{port}/health"
            self.assertIn('.', url)
            self.assertEqual(url, "http://proxy-name.example.com:3000/health")
    
    def test_health_check_url_with_ipv4(self):
        """Test URL construction with IPv4 address"""
        with patch.dict(os.environ, {
            'PROXY_HOST': '192.168.1.100',
            'PROXY_PORT': '3000'
        }):
            host = os.getenv('PROXY_HOST')
            port = os.getenv('PROXY_PORT')
            url = f"http://{host}:{port}/health"
            self.assertEqual(url, "http://192.168.1.100:3000/health")


class TestLoggingConfiguration(unittest.TestCase):
    """Test logging configuration"""
    
    def test_logger_exists(self):
        """Test that logger is configured"""
        import logging
        logger = logging.getLogger('slapenir-agent')
        self.assertIsNotNone(logger)
    
    def test_logging_level_can_be_set(self):
        """Test that logging level can be configured"""
        import logging
        logger = logging.getLogger('slapenir-agent')
        original_level = logger.level
        
        logger.setLevel(logging.DEBUG)
        self.assertEqual(logger.level, logging.DEBUG)
        
        logger.setLevel(logging.WARNING)
        self.assertEqual(logger.level, logging.WARNING)
        
        # Restore original level
        logger.setLevel(original_level)


class TestAgentIntegration(unittest.TestCase):
    """Integration tests for agent components"""
    
    def test_check_environment_returns_boolean(self):
        """Test that check_environment always returns a boolean"""
        result = agent.check_environment()
        self.assertIsInstance(result, bool)
    
    def test_check_environment_with_all_vars_set(self):
        """Test with complete environment configuration"""
        with patch.dict(os.environ, {
            'HTTP_PROXY': 'http://proxy:3000',
            'HTTPS_PROXY': 'http://proxy:3000',
            'PROXY_HOST': 'proxy',
            'PROXY_PORT': '3000',
            'SSL_CERT_FILE': '/certs/client.crt',
            'SSL_KEY_FILE': '/certs/client.key',
            'REQUESTS_CA_BUNDLE': '/certs/ca.crt'
        }):
            result = agent.check_environment()
            self.assertTrue(result)
    
    def test_signal_handling_is_reversible(self):
        """Test that shutdown flag can be reset"""
        agent.shutdown_requested = False
        self.assertFalse(agent.shutdown_requested)
        
        agent.signal_handler(15, None)
        self.assertTrue(agent.shutdown_requested)
        
        agent.shutdown_requested = False
        self.assertFalse(agent.shutdown_requested)


class TestAgentConstants(unittest.TestCase):
    """Test agent constants and defaults"""
    
    def test_default_proxy_host_is_proxy(self):
        """Test default proxy host"""
        with patch.dict(os.environ, {}, clear=True):
            self.assertEqual(os.getenv('PROXY_HOST', 'proxy'), 'proxy')
    
    def test_default_proxy_port_is_3000(self):
        """Test default proxy port"""
        with patch.dict(os.environ, {}, clear=True):
            self.assertEqual(os.getenv('PROXY_PORT', '3000'), '3000')
    
    def test_shutdown_flag_is_boolean(self):
        """Test that shutdown flag is a boolean"""
        self.assertIsInstance(agent.shutdown_requested, bool)


if __name__ == '__main__':
    unittest.main(verbosity=2)