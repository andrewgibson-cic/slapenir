#!/usr/bin/env python3
"""
SLAPENIR Agent Security Tests - Credential Isolation
Tests that the agent NEVER has access to real credentials
"""

import os
import re
import subprocess
import unittest
from typing import List, Dict


class TestCredentialIsolation(unittest.TestCase):
    """Test that agent environment contains ONLY dummy credentials"""

    # Patterns that indicate REAL credentials (MUST NOT be present)
    REAL_CREDENTIAL_PATTERNS = {
        'openai': r'sk-proj-[A-Za-z0-9]{20,}',
        'openai_old': r'sk-[A-Za-z0-9]{48}',
        'anthropic': r'sk-ant-[A-Za-z0-9\-_]{95,}',
        'github_personal': r'ghp_[A-Za-z0-9]{36}',
        'github_oauth': r'gho_[A-Za-z0-9]{36}',
        'github_fine_grained': r'github_pat_[A-Za-z0-9]{22}_[A-Za-z0-9]{59}',
        'slack_bot': r'xoxb-[0-9]{10,13}-[0-9]{10,13}-[A-Za-z0-9]{24}',
        'slack_app': r'xapp-[0-9]-[A-Za-z0-9]+-[0-9]{10,13}-[a-f0-9]{64}',
        'aws_access_key': r'AKIA[0-9A-Z]{16}',
        'google_api': r'AIza[0-9A-Za-z\-_]{35}',
        'stripe_live': r'sk_live_[0-9a-zA-Z]{24,}',
        'stripe_test': r'sk_test_[0-9a-zA-Z]{24,}',
        'sendgrid': r'SG\.[A-Za-z0-9_-]{22}\.[A-Za-z0-9_-]{43}',
        'twilio': r'SK[a-f0-9]{32}',
        'mailgun': r'key-[a-f0-9]{32}',
    }

    # Expected DUMMY patterns (MUST be present)
    EXPECTED_DUMMY_PATTERNS = {
        'DUMMY_OPENAI',
        'DUMMY_ANTHROPIC',
        'DUMMY_GITHUB',
        'DUMMY_GEMINI',
        'DUMMY_MISTRAL',
        'xoxb-DUMMY',
        'xapp-DUMMY',
    }

    def setUp(self):
        """Set up test environment"""
        self.env_vars = dict(os.environ)

    def test_no_real_openai_keys(self):
        """Test that no real OpenAI API keys are present"""
        violations = self._check_pattern_violations(['openai', 'openai_old'])
        self.assertEqual(
            len(violations), 0,
            f"Found real OpenAI credentials in agent environment: {violations}"
        )

    def test_no_real_anthropic_keys(self):
        """Test that no real Anthropic API keys are present"""
        violations = self._check_pattern_violations(['anthropic'])
        self.assertEqual(
            len(violations), 0,
            f"Found real Anthropic credentials in agent environment: {violations}"
        )

    def test_no_real_github_tokens(self):
        """Test that no real GitHub tokens are present"""
        violations = self._check_pattern_violations([
            'github_personal', 'github_oauth', 'github_fine_grained'
        ])
        self.assertEqual(
            len(violations), 0,
            f"Found real GitHub credentials in agent environment: {violations}"
        )

    def test_no_real_slack_tokens(self):
        """Test that no real Slack tokens are present"""
        violations = self._check_pattern_violations(['slack_bot', 'slack_app'])
        self.assertEqual(
            len(violations), 0,
            f"Found real Slack credentials in agent environment: {violations}"
        )

    def test_no_real_aws_keys(self):
        """Test that no real AWS access keys are present"""
        violations = self._check_pattern_violations(['aws_access_key'])
        self.assertEqual(
            len(violations), 0,
            f"Found real AWS credentials in agent environment: {violations}"
        )

    def test_no_real_google_keys(self):
        """Test that no real Google API keys are present"""
        violations = self._check_pattern_violations(['google_api'])
        self.assertEqual(
            len(violations), 0,
            f"Found real Google credentials in agent environment: {violations}"
        )

    def test_no_real_payment_keys(self):
        """Test that no real payment service keys are present"""
        violations = self._check_pattern_violations(['stripe_live', 'stripe_test'])
        self.assertEqual(
            len(violations), 0,
            f"Found real payment credentials in agent environment: {violations}"
        )

    def test_no_real_email_service_keys(self):
        """Test that no real email service keys are present"""
        violations = self._check_pattern_violations(['sendgrid', 'mailgun'])
        self.assertEqual(
            len(violations), 0,
            f"Found real email service credentials in agent environment: {violations}"
        )

    def test_dummy_credentials_present(self):
        """Test that expected dummy credentials are present"""
        env_string = ' '.join([f"{k}={v}" for k, v in self.env_vars.items()])
        
        missing_dummies = []
        for dummy in self.EXPECTED_DUMMY_PATTERNS:
            if dummy not in env_string:
                missing_dummies.append(dummy)
        
        self.assertEqual(
            len(missing_dummies), 0,
            f"Missing expected dummy credentials: {missing_dummies}"
        )

    def test_proxy_configuration_present(self):
        """Test that proxy configuration is present"""
        self.assertIn('HTTP_PROXY', self.env_vars, "HTTP_PROXY not set")
        self.assertIn('HTTPS_PROXY', self.env_vars, "HTTPS_PROXY not set")
        
        # Verify proxy points to correct host
        http_proxy = self.env_vars.get('HTTP_PROXY', '')
        https_proxy = self.env_vars.get('HTTPS_PROXY', '')
        
        self.assertIn('proxy:3000', http_proxy, "HTTP_PROXY not pointing to proxy")
        self.assertIn('proxy:3000', https_proxy, "HTTPS_PROXY not pointing to proxy")

    def test_no_real_credentials_in_any_env_var(self):
        """Comprehensive test scanning ALL environment variables"""
        all_violations = self._check_all_patterns()
        
        self.assertEqual(
            len(all_violations), 0,
            f"Found {len(all_violations)} real credential(s) in environment:\n" +
            "\n".join([f"  - {v['service']}: {v['var']}={v['value'][:20]}..." 
                      for v in all_violations])
        )

    def test_env_file_contains_only_dummies(self):
        """Test that .env file contains only dummy credentials"""
        env_file_path = '/home/agent/.env'
        
        if not os.path.exists(env_file_path):
            self.skipTest(f"{env_file_path} does not exist")
        
        with open(env_file_path, 'r') as f:
            content = f.read()
        
        violations = []
        for service, pattern in self.REAL_CREDENTIAL_PATTERNS.items():
            matches = re.findall(pattern, content)
            if matches:
                violations.append({
                    'service': service,
                    'matches': matches
                })
        
        self.assertEqual(
            len(violations), 0,
            f"Found real credentials in .env.agent file: {violations}"
        )

    def test_validation_script_exists(self):
        """Test that security validation script exists and is executable"""
        script_path = '/home/agent/scripts/validate-env.sh'
        self.assertTrue(os.path.exists(script_path), "validate-env.sh not found")
        self.assertTrue(os.access(script_path, os.X_OK), "validate-env.sh not executable")

    def test_validation_script_passes(self):
        """Test that security validation script passes"""
        result = subprocess.run(
            ['/home/agent/scripts/validate-env.sh'],
            capture_output=True,
            text=True
        )
        
        self.assertEqual(
            result.returncode, 0,
            f"Security validation failed:\n{result.stdout}\n{result.stderr}"
        )

    def test_specific_services_use_dummies(self):
        """Test specific common services use dummy credentials"""
        test_cases = [
            ('OPENAI_API_KEY', 'DUMMY_OPENAI'),
            ('ANTHROPIC_API_KEY', 'DUMMY_ANTHROPIC'),
            ('GITHUB_TOKEN', 'DUMMY_GITHUB'),
            ('GEMINI_API_KEY', 'DUMMY_GEMINI'),
            ('SLACK_BOT_TOKEN', 'xoxb-DUMMY'),
        ]
        
        for var_name, expected_value in test_cases:
            with self.subTest(var=var_name):
                actual_value = self.env_vars.get(var_name, '')
                self.assertEqual(
                    actual_value, expected_value,
                    f"{var_name} should be {expected_value}, got: {actual_value}"
                )

    def test_no_bearer_token_patterns(self):
        """Test that no real Bearer token patterns exist"""
        bearer_patterns = [
            r'Bearer\s+sk-[A-Za-z0-9]{20,}',
            r'Bearer\s+ghp_[A-Za-z0-9]{36}',
            r'Bearer\s+xoxb-[0-9]',
        ]
        
        env_string = ' '.join([f"{k}={v}" for k, v in self.env_vars.items()])
        
        violations = []
        for pattern in bearer_patterns:
            matches = re.findall(pattern, env_string)
            if matches:
                violations.extend(matches)
        
        self.assertEqual(
            len(violations), 0,
            f"Found real Bearer token patterns: {violations}"
        )

    def test_aws_credentials_are_dummy(self):
        """Test that AWS credentials are dummy values"""
        aws_access_key = self.env_vars.get('AWS_ACCESS_KEY_ID', '')
        aws_secret_key = self.env_vars.get('AWS_SECRET_ACCESS_KEY', '')
        
        # Should be dummy, not real AKIA pattern
        self.assertIn('DUMMY', aws_access_key, "AWS_ACCESS_KEY_ID is not dummy")
        self.assertIn('DUMMY', aws_secret_key, "AWS_SECRET_ACCESS_KEY is not dummy")
        
        # Should NOT match real AWS pattern
        self.assertFalse(
            re.match(r'AKIA[0-9A-Z]{16}', aws_access_key),
            f"AWS_ACCESS_KEY_ID matches real AWS pattern: {aws_access_key}"
        )

    # Helper methods
    def _check_pattern_violations(self, pattern_keys: List[str]) -> List[Dict]:
        """Check for violations of specific credential patterns"""
        violations = []
        env_string = ' '.join([f"{k}={v}" for k, v in self.env_vars.items()])
        
        for key in pattern_keys:
            pattern = self.REAL_CREDENTIAL_PATTERNS[key]
            matches = re.findall(pattern, env_string)
            if matches:
                violations.extend([{
                    'service': key,
                    'pattern': pattern,
                    'match': match
                } for match in matches])
        
        return violations

    def _check_all_patterns(self) -> List[Dict]:
        """Check all environment variables against all patterns"""
        violations = []
        
        for var_name, var_value in self.env_vars.items():
            for service, pattern in self.REAL_CREDENTIAL_PATTERNS.items():
                if re.search(pattern, var_value):
                    violations.append({
                        'service': service,
                        'var': var_name,
                        'value': var_value,
                        'pattern': pattern
                    })
        
        return violations


class TestProxyConfiguration(unittest.TestCase):
    """Test that agent is properly configured to use proxy"""

    def test_http_proxy_set(self):
        """Test that HTTP_PROXY is set"""
        self.assertIn('HTTP_PROXY', os.environ)
        self.assertEqual(os.environ['HTTP_PROXY'], 'http://proxy:3000')

    def test_https_proxy_set(self):
        """Test that HTTPS_PROXY is set"""
        self.assertIn('HTTPS_PROXY', os.environ)
        self.assertEqual(os.environ['HTTPS_PROXY'], 'http://proxy:3000')

    def test_no_proxy_set(self):
        """Test that NO_PROXY is set to exclude local hosts"""
        no_proxy = os.environ.get('NO_PROXY', '')
        self.assertIn('localhost', no_proxy)
        self.assertIn('127.0.0.1', no_proxy)


class TestEnvironmentGeneration(unittest.TestCase):
    """Test that environment generation works correctly"""

    def test_dummy_env_generation_script_exists(self):
        """Test that generate-dummy-env.sh exists"""
        script_path = '/home/agent/scripts/generate-dummy-env.sh'
        self.assertTrue(os.path.exists(script_path))
        self.assertTrue(os.access(script_path, os.X_OK))

    def test_init_script_exists(self):
        """Test that init-agent-env.sh exists"""
        script_path = '/home/agent/scripts/init-agent-env.sh'
        self.assertTrue(os.path.exists(script_path))
        self.assertTrue(os.access(script_path, os.X_OK))

    def test_env_file_exists(self):
        """Test that .env file was generated"""
        self.assertTrue(os.path.exists('/home/agent/.env'))

    def test_env_file_permissions(self):
        """Test that .env has correct permissions (600)"""
        import stat
        env_file = '/home/agent/.env'
        if os.path.exists(env_file):
            mode = os.stat(env_file).st_mode
            # Should be readable/writable by owner only
            self.assertTrue(mode & stat.S_IRUSR)
            self.assertTrue(mode & stat.S_IWUSR)
            self.assertFalse(mode & stat.S_IRGRP)
            self.assertFalse(mode & stat.S_IROTH)


if __name__ == '__main__':
    # Run tests with verbose output
    unittest.main(verbosity=2)