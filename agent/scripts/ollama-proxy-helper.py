#!/usr/bin/env python3
"""
Ollama Proxy Helper for SLAPENIR

This script creates a local HTTP proxy that:
1. Accepts Ollama API requests from Aider
2. Adds the X-Target-URL header for the SLAPENIR proxy
3. Forwards requests through the SLAPENIR proxy to Ollama

This ensures all traffic goes through the SLAPENIR proxy for auditing.

Usage:
    python3 /home/agent/scripts/ollama-proxy-helper.py &
    export OLLAMA_API_BASE=http://localhost:8765
    aider --model ollama_chat/qwen2.5-coder:7b
"""

import http.server
import http.client
import os
import sys
import threading
import logging

# Configuration
LISTEN_PORT = 8765
SLAPENIR_PROXY_HOST = os.environ.get("HTTP_PROXY", "http://proxy:3000").replace("http://", "").split(":")
SLAPENIR_PROXY_HOST = SLAPENIR_PROXY_HOST[0] if SLAPENIR_PROXY_HOST else "proxy"
SLAPENIR_PROXY_PORT = int(os.environ.get("PROXY_PORT", "3000"))
OLLAMA_TARGET = os.environ.get("OLLAMA_HOST", "host.docker.internal:11434")

# Parse proxy host and port
if ":" in os.environ.get("HTTP_PROXY", ""):
    parts = os.environ.get("HTTP_PROXY", "http://proxy:3000").replace("http://", "").split(":")
    SLAPENIR_PROXY_HOST = parts[0]
    SLAPENIR_PROXY_PORT = int(parts[1]) if len(parts) > 1 else 3000

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class OllamaProxyHandler(http.server.BaseHTTPRequestHandler):
    """Handler that forwards Ollama requests through SLAPENIR proxy."""

    protocol_version = 'HTTP/1.1'

    def log_message(self, format, *args):
        """Log to stderr with prefix."""
        logger.info("%s - %s", self.address_string(), format % args)

    def do_GET(self):
        self._forward_request()

    def do_POST(self):
        self._forward_request()

    def do_DELETE(self):
        self._forward_request()

    def do_PUT(self):
        self._forward_request()

    def _forward_request(self):
        """Forward request to SLAPENIR proxy with X-Target-URL header."""
        try:
            # Read request body
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length) if content_length > 0 else None

            # Build target URL for Ollama
            target_url = f"http://{OLLAMA_TARGET}{self.path}"

            logger.info(f"Forwarding {self.command} {self.path} -> {target_url}")

            # Connect to SLAPENIR proxy
            conn = http.client.HTTPConnection(SLAPENIR_PROXY_HOST, SLAPENIR_PROXY_PORT)

            # Prepare headers - add X-Target-URL for the proxy
            headers = {}
            for key, value in self.headers.items():
                if key.lower() not in ('host', 'content-length'):
                    headers[key] = value

            # Critical: Add X-Target-URL header so proxy knows where to forward
            headers['X-Target-URL'] = target_url

            # Forward request
            conn.request(self.command, self.path, body=body, headers=headers)

            # Get response
            response = conn.getresponse()

            # Send response back to client
            self.send_response(response.status, response.reason)

            # Forward response headers
            for key, value in response.getheaders():
                if key.lower() not in ('transfer-encoding',):
                    self.send_header(key, value)

            self.end_headers()

            # Forward response body
            response_body = response.read()
            self.wfile.write(response_body)

            conn.close()

            logger.info(f"Response: {response.status}")

        except Exception as e:
            logger.error(f"Error forwarding request: {e}")
            self.send_error(502, f"Bad Gateway: {str(e)}")


def run_server(port=LISTEN_PORT):
    """Run the proxy server."""
    server_address = ('', port)
    httpd = http.server.HTTPServer(server_address, OllamaProxyHandler)
    logger.info(f"Ollama Proxy Helper listening on port {port}")
    logger.info(f"Forwarding to SLAPENIR proxy at {SLAPENIR_PROXY_HOST}:{SLAPENIR_PROXY_PORT}")
    logger.info(f"Target Ollama: {OLLAMA_TARGET}")
    logger.info("")
    logger.info("Configure Aider with:")
    logger.info(f"  export OLLAMA_API_BASE=http://localhost:{port}")
    logger.info(f"  aider --model ollama_chat/qwen2.5-coder:7b")

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        logger.info("Shutting down...")
        httpd.shutdown()


if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else LISTEN_PORT
    run_server(port)
