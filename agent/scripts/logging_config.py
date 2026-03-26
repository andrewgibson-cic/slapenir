#!/usr/bin/env python3
"""
Logging Configuration for SLAPENIR Agent

Provides structured JSON logging with rotation and fallback handling.
Implements SPEC-001 through SPEC-010.

Features:
- RotatingFileHandler (JSON format)
- StreamHandler (text format for stdout)
- Three-tier fallback (file -> stdout -> stderr)
- Environment-based configuration

Example:
    >>> from logging_config import LoggingConfig
    >>> logger = LoggingConfig.get_logger('agent-svc', '/var/log/slapenir', 'INFO')
    >>> logger.info("Agent started")
"""

import logging
import logging.handlers
import os
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional
import json


class LoggingConfig:
    """
    Centralized logging configuration with dual handlers and rotation.

    Features:
    - RotatingFileHandler (JSON format, 10MB, 5 backups)
    - StreamHandler (text format for stdout)
    - Three-tier fallback (file -> stdout -> stderr)
    - Environment-based configuration

    Example:
        >>> logger = LoggingConfig.get_logger('agent-svc', '/var/log/slapenir', 'INFO')
        >>> logger.info("Agent started")
    """

    _instance: Optional["LoggingConfig"] = None
    _initialized: bool = False

    def __new__(cls):
        """Create singleton instance with lazy initialization."""
        if cls._instance is None:
            instance = super().__new__(cls)
            instance._initialized = False
            cls._instance = instance
        return cls._instance

    def __init__(self) -> None:
        """Initialize configuration from environment variables."""
        if self._initialized:
            return

        # Configuration from environment (SPEC-005)
        self.enabled = self._get_bool("LOG_ENABLED", True)
        self.log_dir = os.environ.get("LOG_DIR", "/var/log/slapenir")
        self.log_level = os.environ.get("LOG_LEVEL", "INFO") or "INFO"
        self.max_bytes = self._get_int("LOG_MAX_BYTES", 10 * 1024 * 1024)  # 10MB
        self.backup_count = self._get_int("LOG_BACKUP_COUNT", 5)
        self.service_name = os.environ.get("SERVICE_NAME", "agent-svc")

        self._initialized = True

    @staticmethod
    def _get_bool(key: str, default: bool) -> bool:
        """Parse boolean from environment variable."""
        value = os.environ.get(key, str(default))
        return value.lower() in ("true", "1", "yes")

    @staticmethod
    def _get_int(key: str, default: int) -> int:
        """Parse integer from environment variable."""
        try:
            return int(os.environ.get(key, str(default)))
        except ValueError:
            return default

    def _ensure_log_directory(self, log_dir: Path) -> bool:
        """
        Ensure log directory exists with proper permissions.

        Args:
            log_dir: Path to log directory

        Returns:
            True if directory exists and is writable, False otherwise

        Implements: SPEC-001 (Directory Management)
        """
        try:
            log_dir.mkdir(parents=True, exist_ok=True)
            log_dir.chmod(0o755)
            return True
        except (OSError, PermissionError) as e:
            logging.error(f"Cannot create log directory {log_dir}: {e}")
            return False

    @classmethod
    def get_logger(
        cls,
        service_name: str = "agent-svc",
        log_dir: str = "/var/log/slapenir",
        log_level: str = "INFO",
    ) -> logging.Logger:
        """
        Get configured logger instance.

        Args:
            service_name: Service identifier for logs
            log_dir: Directory for log files
            log_level: Log level (DEBUG, INFO, WARNING, ERROR, CRITICAL)

        Returns:
            Configured logger instance

        Implements: SPEC-003, SPEC-005, SPEC-007
        """
        instance = cls()
        instance._setup_logging(service_name, log_dir, log_level)
        return logging.getLogger(service_name)

    def _setup_logging(self, service_name: str, log_dir: str, log_level: str) -> None:
        """Setup logging with dual handlers and fallback."""
        # Get root logger
        logger = logging.getLogger()
        logger.setLevel(getattr(logging, log_level.upper(), logging.INFO))

        # Clear existing handlers
        logger.handlers.clear()

        # Tier 1: File logging (primary) - SPEC-001, SPEC-003, SPEC-006
        file_logging_enabled = False
        if self.enabled:
            try:
                log_dir_path = Path(log_dir)
                if self._ensure_log_directory(log_dir_path):
                    if os.access(log_dir_path, os.W_OK):
                        file_handler = self._create_file_handler(
                            log_dir_path, service_name
                        )
                        logger.addHandler(file_handler)
                        file_logging_enabled = True
            except (OSError, PermissionError) as e:
                print(f"WARNING: File logging failed: {e}", file=sys.stderr)

        # Tier 2: stdout logging (secondary, always enabled) - SPEC-003
        stdout_handler = logging.StreamHandler(sys.stdout)
        stdout_handler.setFormatter(
            logging.Formatter(
                "[%(asctime)s] [%(levelname)s] %(message)s", datefmt="%Y-%m-%d %H:%M:%S"
            )
        )
        logger.addHandler(stdout_handler)

        # Log configuration status
        logger_instance = logging.getLogger(service_name)
        if file_logging_enabled:
            logger_instance.info(f"Logging to {log_dir} (file + stdout)")
        else:
            logger_instance.warning(f"File logging disabled, using stdout only")

        self._logger_instance = logger_instance

    def _create_file_handler(self, log_dir: Path, service_name: str) -> logging.Handler:
        """
        Create rotating file handler with JSON format.

        Implements: SPEC-006 (Log Retention)
        """
        log_file = log_dir / f"{service_name}.log"

        handler = logging.handlers.RotatingFileHandler(
            filename=str(log_file),
            maxBytes=self.max_bytes,
            backupCount=self.backup_count,
            encoding="utf-8",
        )

        # JSON formatter (SPEC-010)
        handler.setFormatter(JSONFormatter())

        return handler


class JSONFormatter(logging.Formatter):
    """
    JSON formatter for structured logging.

    Implements: SPEC-010 (Log Format)

    Format:
        {"timestamp":"2026-03-04T12:30:45.123456","level":"INFO","service":"agent-svc","message":"..."}
    """

    def format(self, record: logging.LogRecord) -> str:
        """Format log record as JSON."""
        log_entry = {
            "timestamp": datetime.fromtimestamp(record.created).isoformat(),
            "level": record.levelname,
            "service": record.name,
            "message": record.getMessage(),
        }

        if record.exc_info:
            log_entry["exception"] = self.formatException(record.exc_info)

        return json.dumps(log_entry)


# Convenience function for quick setup
def setup_logging(
    service_name: str = "agent-svc",
    log_dir: str = "/var/log/slapenir",
    log_level: str = "INFO",
) -> logging.Logger:
    """
    Convenience function to setup logging.

    Args:
        service_name: Service identifier
        log_dir: Log directory path
        log_level: Log level

    Returns:
        Configured logger instance
    """
    return LoggingConfig.get_logger(service_name, log_dir, log_level)
