#!/usr/bin/env python3
"""
Tests for Logging Configuration
Specification: SPEC-001 through SPEC-010
"""

import logging
import os
import stat
import sys
from datetime import datetime
from pathlib import Path
from typing import Generator

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent / "scripts"))


class TestDirectoryManagement:
    """TEST-001: Directory Management (SPEC-001)"""

    def test_create_log_directory_if_missing(self, tmp_path: Path):
        """TEST-001-001: Create log directory when it doesn't exist."""
        from logging_config import LoggingConfig

        log_dir = tmp_path / "logs"

        config = LoggingConfig()
        # Reset singleton for clean test
        LoggingConfig._instance = None
        LoggingConfig._initialized = False

        config = LoggingConfig()
        result = config._ensure_log_directory(log_dir)

        assert result is True
        assert log_dir.exists()
        assert log_dir.is_dir()
        assert stat.S_IMODE(log_dir.stat().st_mode) == 0o755

    def test_use_existing_log_directory(self, tmp_path: Path):
        """TEST-001-002: Use existing directory without error."""
        from logging_config import LoggingConfig

        log_dir = tmp_path / "logs"
        log_dir.mkdir()

        config = LoggingConfig()
        # Reset singleton for clean test
        LoggingConfig._instance = None
        LoggingConfig._initialized = False

        config = LoggingConfig()
        result = config._ensure_log_directory(log_dir)

        assert result is True
        assert log_dir.exists()

    def test_permission_denied_fallback(self, tmp_path: Path):
        """TEST-001-003: Graceful fallback when directory creation fails."""
        from logging_config import LoggingConfig

        parent = tmp_path / "readonly"
        parent.mkdir()
        parent.chmod(0o444)

        log_dir = parent / "logs"

        config = LoggingConfig()
        # Reset singleton for clean test
        LoggingConfig._instance = None
        LoggingConfig._initialized = False

        config = LoggingConfig()
        result = config._ensure_log_directory(log_dir)

        assert result is False

    def test_log_dir_from_environment(self, monkeypatch, tmp_path: Path):
        """TEST-001-004: LOG_DIR environment variable is used."""
        from logging_config import LoggingConfig

        custom_dir = tmp_path / "custom_logs"
        monkeypatch.setenv("LOG_DIR", str(custom_dir))

        # Reset singleton for clean test
        LoggingConfig._instance = None
        LoggingConfig._initialized = False

        config = LoggingConfig()

        assert config.log_dir == str(custom_dir)

        # Clean up
        LoggingConfig._instance = None
        LoggingConfig._initialized = False


class TestConfiguration:
    """TEST-005: Configuration (SPEC-005)"""

    def test_default_configuration(self):
        """TEST-005-001: Default configuration works."""
        from logging_config import LoggingConfig

        # Reset singleton
        LoggingConfig._instance = None
        LoggingConfig._initialized = False

        config = LoggingConfig()

        assert config.enabled is True
        assert config.log_dir == "/var/log/slapenir"
        assert config.log_level == "INFO"
        assert config.max_bytes == 10 * 1024 * 1024  # 10MB
        assert config.backup_count == 5

    def test_environment_variable_override(self, monkeypatch):
        """TEST-005-002: Environment variables override defaults."""
        from logging_config import LoggingConfig

        monkeypatch.setenv("LOG_ENABLED", "false")
        monkeypatch.setenv("LOG_DIR", "/custom/path")
        monkeypatch.setenv("LOG_LEVEL", "DEBUG")
        monkeypatch.setenv("LOG_MAX_BYTES", "20971520")  # 20MB
        monkeypatch.setenv("LOG_BACKUP_COUNT", "10")

        # Reset singleton
        LoggingConfig._instance = None
        LoggingConfig._initialized = False

        config = LoggingConfig()

        assert config.enabled is False
        assert config.log_dir == "/custom/path"
        assert config.log_level == "DEBUG"
        assert config.max_bytes == 20971520
        assert config.backup_count == 10

    def test_invalid_log_level_fallback(self, monkeypatch):
        """TEST-005-003: Invalid log level falls back to INFO."""
        from logging_config import LoggingConfig

        monkeypatch.setenv("LOG_LEVEL", "INVALID")

        # Reset singleton
        LoggingConfig._instance = None
        LoggingConfig._logger_instance = None

        config = LoggingConfig()
        logger = config.get_logger(log_level="INVALID")

        # Should use INFO level (20) - check effective level
        # Root logger has NOTSET (0), but effective level should be INFO
        assert logger.getEffectiveLevel() == logging.INFO

    def test_boolean_parsing(self, monkeypatch):
        """TEST-005-004: Various boolean formats for LOG_ENABLED."""
        from logging_config import LoggingConfig

        test_cases = [
            ("true", True),
            ("True", True),
            ("TRUE", True),
            ("1", True),
            ("yes", True),
            ("false", False),
            ("False", False),
            ("0", False),
            ("no", False),
        ]

        for value, expected in test_cases:
            monkeypatch.setenv("LOG_ENABLED", value)

            # Reset singleton
            LoggingConfig._instance = None
            LoggingConfig._initialized = False

            config = LoggingConfig()
            assert config.enabled is expected, f"Failed for value: {value}"

        # Clean up
        LoggingConfig._instance = None
        LoggingConfig._initialized = False
