#!/usr/bin/env python3
"""
SLAPENIR Agent mTLS Client
Implements mutual TLS for secure proxy communication
"""

import ssl
import logging
from pathlib import Path
from typing import Optional, Dict, Any
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.ssl_ import create_urllib3_context

logger = logging.getLogger(__name__)


class MtlsAdapter(HTTPAdapter):
    """Custom HTTP adapter with mTLS support"""
    
    def __init__(self, ssl_context: ssl.SSLContext, *args, **kwargs):
        self.ssl_context = ssl_context
        super().__init__(*args, **kwargs)
    
    def init_poolmanager(self, *args, **kwargs):
        kwargs['ssl_context'] = self.ssl_context
        return super().init_poolmanager(*args, **kwargs)


class MtlsClient:
    """
    HTTP client with mutual TLS authentication support.
    
    Provides secure communication with the SLAPENIR proxy using
    client certificates for mutual authentication.
    
    Example:
        >>> client = MtlsClient(
        ...     ca_cert="certs/root_ca.crt",
        ...     client_cert="certs/agent-01.crt",
        ...     client_key="certs/agent-01.key"
        ... )
        >>> response = client.post(
        ...     "https://proxy:3000/v1/chat/completions",
        ...     json={"model": "gpt-4", "messages": [...]}
        ... )
    """
    
    def __init__(
        self,
        ca_cert: str,
        client_cert: str,
        client_key: str,
        verify_hostname: bool = True,
        timeout: int = 30
    ):
        """
        Initialize mTLS client with certificates.
        
        Args:
            ca_cert: Path to CA certificate file
            client_cert: Path to client certificate file
            client_key: Path to client private key file
            verify_hostname: Whether to verify server hostname (default: True)
            timeout: Default request timeout in seconds (default: 30)
        
        Raises:
            FileNotFoundError: If any certificate file is missing
            ssl.SSLError: If certificates are invalid
        """
        self.ca_cert = Path(ca_cert)
        self.client_cert = Path(client_cert)
        self.client_key = Path(client_key)
        self.verify_hostname = verify_hostname
        self.timeout = timeout
        
        # Validate certificate files exist
        self._validate_cert_files()
        
        # Create SSL context
        self.ssl_context = self._create_ssl_context()
        
        # Create session with mTLS adapter
        self.session = self._create_session()
        
        logger.info(
            f"mTLS client initialized with CA: {self.ca_cert}, "
            f"Client cert: {self.client_cert}"
        )
    
    def _validate_cert_files(self) -> None:
        """Validate that all required certificate files exist."""
        for cert_file, name in [
            (self.ca_cert, "CA certificate"),
            (self.client_cert, "Client certificate"),
            (self.client_key, "Client private key")
        ]:
            if not cert_file.exists():
                raise FileNotFoundError(
                    f"{name} not found: {cert_file}"
                )
            logger.debug(f"Found {name}: {cert_file}")
    
    def _create_ssl_context(self) -> ssl.SSLContext:
        """
        Create SSL context with client certificates.
        
        Returns:
            Configured SSL context
        
        Raises:
            ssl.SSLError: If certificate loading fails
        """
        # Create SSL context for client authentication
        context = ssl.create_default_context(
            purpose=ssl.Purpose.SERVER_AUTH,
            cafile=str(self.ca_cert)
        )
        
        # Load client certificate and private key
        try:
            context.load_cert_chain(
                certfile=str(self.client_cert),
                keyfile=str(self.client_key)
            )
            logger.debug("Client certificate loaded successfully")
        except ssl.SSLError as e:
            logger.error(f"Failed to load client certificate: {e}")
            raise
        
        # Configure hostname verification
        if not self.verify_hostname:
            logger.warning("Hostname verification disabled - use only for development!")
            context.check_hostname = False
            context.verify_mode = ssl.CERT_NONE
        else:
            context.check_hostname = True
            context.verify_mode = ssl.CERT_REQUIRED
        
        # Use strong ciphers only
        context.set_ciphers('ECDHE+AESGCM:ECDHE+CHACHA20:DHE+AESGCM:DHE+CHACHA20:!aNULL:!MD5:!DSS')
        
        # Prefer TLS 1.3, minimum TLS 1.2
        context.minimum_version = ssl.TLSVersion.TLSv1_2
        
        logger.debug("SSL context created with TLS 1.2+ and strong ciphers")
        return context
    
    def _create_session(self) -> requests.Session:
        """
        Create requests session with mTLS adapter.
        
        Returns:
            Configured requests session
        """
        session = requests.Session()
        
        # Mount mTLS adapter for HTTPS
        adapter = MtlsAdapter(self.ssl_context)
        session.mount('https://', adapter)
        
        # Set default headers
        session.headers.update({
            'User-Agent': 'SLAPENIR-Agent/1.0',
            'Accept': 'application/json',
        })
        
        logger.debug("Requests session created with mTLS adapter")
        return session
    
    def get(
        self,
        url: str,
        headers: Optional[Dict[str, str]] = None,
        timeout: Optional[int] = None,
        **kwargs
    ) -> requests.Response:
        """
        Make GET request with mTLS.
        
        Args:
            url: Request URL
            headers: Additional headers
            timeout: Request timeout (uses default if not specified)
            **kwargs: Additional arguments passed to requests
        
        Returns:
            Response object
        
        Raises:
            requests.RequestException: On request failure
        """
        timeout = timeout or self.timeout
        logger.debug(f"GET {url}")
        
        try:
            response = self.session.get(
                url,
                headers=headers,
                timeout=timeout,
                **kwargs
            )
            logger.debug(f"GET {url} -> {response.status_code}")
            return response
        except requests.RequestException as e:
            logger.error(f"GET {url} failed: {e}")
            raise
    
    def post(
        self,
        url: str,
        json: Optional[Dict[str, Any]] = None,
        data: Optional[Any] = None,
        headers: Optional[Dict[str, str]] = None,
        timeout: Optional[int] = None,
        **kwargs
    ) -> requests.Response:
        """
        Make POST request with mTLS.
        
        Args:
            url: Request URL
            json: JSON data to send
             Raw data to send
            headers: Additional headers
            timeout: Request timeout (uses default if not specified)
            **kwargs: Additional arguments passed to requests
        
        Returns:
            Response object
        
        Raises:
            requests.RequestException: On request failure
        """
        timeout = timeout or self.timeout
        logger.debug(f"POST {url}")
        
        try:
            response = self.session.post(
                url,
                json=json,
                data=data,
                headers=headers,
                timeout=timeout,
                **kwargs
            )
            logger.debug(f"POST {url} -> {response.status_code}")
            return response
        except requests.RequestException as e:
            logger.error(f"POST {url} failed: {e}")
            raise
    
    def put(
        self,
        url: str,
        json: Optional[Dict[str, Any]] = None,
        data: Optional[Any] = None,
        headers: Optional[Dict[str, str]] = None,
        timeout: Optional[int] = None,
        **kwargs
    ) -> requests.Response:
        """Make PUT request with mTLS."""
        timeout = timeout or self.timeout
        logger.debug(f"PUT {url}")
        
        try:
            response = self.session.put(
                url,
                json=json,
                data=data,
                headers=headers,
                timeout=timeout,
                **kwargs
            )
            logger.debug(f"PUT {url} -> {response.status_code}")
            return response
        except requests.RequestException as e:
            logger.error(f"PUT {url} failed: {e}")
            raise
    
    def delete(
        self,
        url: str,
        headers: Optional[Dict[str, str]] = None,
        timeout: Optional[int] = None,
        **kwargs
    ) -> requests.Response:
        """Make DELETE request with mTLS."""
        timeout = timeout or self.timeout
        logger.debug(f"DELETE {url}")
        
        try:
            response = self.session.delete(
                url,
                headers=headers,
                timeout=timeout,
                **kwargs
            )
            logger.debug(f"DELETE {url} -> {response.status_code}")
            return response
        except requests.RequestException as e:
            logger.error(f"DELETE {url} failed: {e}")
            raise
    
    def close(self) -> None:
        """Close the underlying session."""
        self.session.close()
        logger.debug("mTLS client session closed")
    
    def __enter__(self):
        """Context manager entry."""
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit."""
        self.close()


def create_mtls_client_from_env() -> MtlsClient:
    """
    Create mTLS client from environment variables.
    
    Environment variables:
        MTLS_CA_CERT: Path to CA certificate
        MTLS_CLIENT_CERT: Path to client certificate
        MTLS_CLIENT_KEY: Path to client private key
        MTLS_VERIFY_HOSTNAME: Whether to verify hostname (default: true)
        MTLS_TIMEOUT: Request timeout in seconds (default: 30)
    
    Returns:
        Configured MtlsClient instance
    
    Raises:
        ValueError: If required environment variables are missing
    """
    import os
    
    ca_cert = os.getenv('MTLS_CA_CERT')
    client_cert = os.getenv('MTLS_CLIENT_CERT')
    client_key = os.getenv('MTLS_CLIENT_KEY')
    
    if not all([ca_cert, client_cert, client_key]):
        raise ValueError(
            "Missing required environment variables: "
            "MTLS_CA_CERT, MTLS_CLIENT_CERT, MTLS_CLIENT_KEY"
        )
    
    verify_hostname = os.getenv('MTLS_VERIFY_HOSTNAME', 'true').lower() == 'true'
    timeout = int(os.getenv('MTLS_TIMEOUT', '30'))
    
    return MtlsClient(
        ca_cert=ca_cert,
        client_cert=client_cert,
        client_key=client_key,
        verify_hostname=verify_hostname,
        timeout=timeout
    )


if __name__ == '__main__':
    # Example usage
    import sys
    
    logging.basicConfig(
        level=logging.DEBUG,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    if len(sys.argv) != 4:
        print("Usage: mtls_client.py <ca_cert> <client_cert> <client_key>")
        sys.exit(1)
    
    ca_cert, client_cert, client_key = sys.argv[1:4]
    
    try:
        with MtlsClient(ca_cert, client_cert, client_key) as client:
            # Test connection
            response = client.get("https://localhost:3000/health")
            print(f"Health check: {response.status_code}")
            print(response.text)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)