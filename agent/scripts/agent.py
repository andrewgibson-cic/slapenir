#!/usr/bin/env python3
"""
SLAPENIR Agent - Placeholder
A simple Python agent that demonstrates the proxy connection and stays running.
This will be replaced with actual AI agent logic.
"""

import os
import sys
import time
import signal
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger('slapenir-agent')

# Global flag for graceful shutdown
shutdown_requested = False

def signal_handler(signum, frame):
    """Handle shutdown signals gracefully"""
    global shutdown_requested
    logger.info(f"Received signal {signum}, initiating graceful shutdown...")
    shutdown_requested = True

def check_environment():
    """Verify the agent environment is properly configured"""
    logger.info("Checking agent environment...")
    
    # Check proxy configuration
    http_proxy = os.getenv('HTTP_PROXY')
    https_proxy = os.getenv('HTTPS_PROXY')
    
    if http_proxy:
        logger.info(f"HTTP Proxy: {http_proxy}")
    else:
        logger.warning("HTTP_PROXY not set")
    
    if https_proxy:
        logger.info(f"HTTPS Proxy: {https_proxy}")
    else:
        logger.warning("HTTPS_PROXY not set")
    
    # Check certificate files
    cert_file = os.getenv('SSL_CERT_FILE')
    key_file = os.getenv('SSL_KEY_FILE')
    ca_bundle = os.getenv('REQUESTS_CA_BUNDLE')
    
    if cert_file and os.path.exists(cert_file):
        logger.info(f"Client certificate found: {cert_file}")
    else:
        logger.warning(f"Client certificate not found: {cert_file}")
    
    if key_file and os.path.exists(key_file):
        logger.info(f"Client key found: {key_file}")
    else:
        logger.warning(f"Client key not found: {key_file}")
    
    if ca_bundle and os.path.exists(ca_bundle):
        logger.info(f"CA bundle found: {ca_bundle}")
    else:
        logger.warning(f"CA bundle not found: {ca_bundle}")
    
    # Check Python version
    python_version = sys.version.split()[0]
    logger.info(f"Python version: {python_version}")
    
    return True

def main():
    """Main agent loop"""
    global shutdown_requested
    
    # Register signal handlers
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)
    
    logger.info("=" * 60)
    logger.info("SLAPENIR Agent Starting")
    logger.info("=" * 60)
    
    # Check environment
    if not check_environment():
        logger.error("Environment check failed")
        return 1
    
    logger.info("Agent initialization complete")
    logger.info("Entering main loop (heartbeat every 30 seconds)...")
    
    # Main loop - just stay alive and log heartbeats
    heartbeat_count = 0
    while not shutdown_requested:
        heartbeat_count += 1
        logger.info(f"Heartbeat #{heartbeat_count} - Agent is running")
        
        # Sleep for 30 seconds (checking shutdown flag every second)
        for _ in range(30):
            if shutdown_requested:
                break
            time.sleep(1)
    
    logger.info("=" * 60)
    logger.info("SLAPENIR Agent Shutting Down")
    logger.info(f"Total heartbeats: {heartbeat_count}")
    logger.info("=" * 60)
    
    return 0

if __name__ == '__main__':
    try:
        exit_code = main()
        sys.exit(exit_code)
    except Exception as e:
        logger.exception(f"Fatal error: {e}")
        sys.exit(1)