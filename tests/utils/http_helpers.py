"""
HTTP Test Helpers

Utilities for making HTTP requests during tests.
"""

import time
import requests
from typing import Optional, Dict, Any
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry


def create_session_with_retries(
    retries: int = 3,
    backoff_factor: float = 0.3,
    status_forcelist: tuple = (500, 502, 503, 504)
) -> requests.Session:
    """
    Create requests session with retry logic.
    
    Args:
        retries: Number of retries
        backoff_factor: Backoff factor for retries
        status_forcelist: HTTP status codes to retry on
        
    Returns:
        Configured requests Session
    """
    session = requests.Session()
    retry = Retry(
        total=retries,
        read=retries,
        connect=retries,
        backoff_factor=backoff_factor,
        status_forcelist=status_forcelist,
    )
    adapter = HTTPAdapter(max_retries=retry)
    session.mount('http://', adapter)
    session.mount('https://', adapter)
    session.verify = False  # Disable SSL verification for tests
    return session


def make_request(
    method: str,
    url: str,
    headers: Optional[Dict[str, str]] = None,
    data: Optional[Any] = None,
    json: Optional[Dict] = None,
    params: Optional[Dict] = None,
    timeout: int = 10,
    verify_ssl: bool = False,
    allow_redirects: bool = True
) -> requests.Response:
    """
    Make HTTP request with sensible defaults for testing.
    
    Args:
        method: HTTP method (GET, POST, etc.)
        url: Target URL
        headers: Request headers
        data: Request body data
        json: JSON data to send
        params: URL parameters
        timeout: Request timeout
        verify_ssl: Whether to verify SSL certificates
        allow_redirects: Whether to follow redirects
        
    Returns:
        Response object
    """
    session = create_session_with_retries()
    try:
        response = session.request(
            method=method,
            url=url,
            headers=headers,
            data=data,
            json=json,
            params=params,
            timeout=timeout,
            verify=verify_ssl,
            allow_redirects=allow_redirects
        )
        return response
    finally:
        session.close()


def wait_for_url(
    url: str,
    timeout: int = 60,
    check_interval: int = 2,
    expected_status: int = 200
) -> bool:
    """
    Wait for URL to become accessible.
    
    Args:
        url: URL to check
        timeout: Maximum time to wait in seconds
        check_interval: Time between checks in seconds
        expected_status: Expected HTTP status code
        
    Returns:
        True if URL is accessible, False if timeout
    """
    start_time = time.time()
    
    while time.time() - start_time < timeout:
        try:
            response = make_request('GET', url, timeout=5)
            if response.status_code == expected_status or response.status_code < 500:
                return True
        except requests.exceptions.RequestException:
            pass
            
        time.sleep(check_interval)
        
    return False


def check_http_status(url: str, expected_status: int = 200, timeout: int = 10) -> bool:
    """
    Check if URL returns expected status code.
    
    Args:
        url: URL to check
        expected_status: Expected status code
        timeout: Request timeout
        
    Returns:
        True if status matches, False otherwise
    """
    try:
        response = make_request('GET', url, timeout=timeout)
        return response.status_code == expected_status
    except requests.exceptions.RequestException:
        return False


def make_authenticated_request(
    method: str,
    url: str,
    token: str,
    token_type: str = 'Bearer',
    **kwargs
) -> requests.Response:
    """
    Make authenticated HTTP request.
    
    Args:
        method: HTTP method
        url: Target URL
        token: Authentication token
        token_type: Token type (Bearer, Basic, etc.)
        **kwargs: Additional arguments for make_request
        
    Returns:
        Response object
    """
    headers = kwargs.get('headers', {})
    headers['Authorization'] = f'{token_type} {token}'
    kwargs['headers'] = headers
    
    return make_request(method, url, **kwargs)


def check_json_response(url: str, timeout: int = 10) -> Optional[Dict]:
    """
    Get JSON response from URL.
    
    Args:
        url: URL to request
        timeout: Request timeout
        
    Returns:
        Parsed JSON or None if failed
    """
    try:
        response = make_request('GET', url, timeout=timeout)
        response.raise_for_status()
        return response.json()
    except (requests.exceptions.RequestException, ValueError):
        return None


def check_health_endpoint(base_url: str, health_path: str = '/health', timeout: int = 10) -> bool:
    """
    Check service health endpoint.
    
    Args:
        base_url: Base URL of service
        health_path: Path to health endpoint
        timeout: Request timeout
        
    Returns:
        True if healthy, False otherwise
    """
    url = f"{base_url.rstrip('/')}{health_path}"
    return check_http_status(url, expected_status=200, timeout=timeout)


def wait_for_healthy(
    base_url: str,
    health_path: str = '/health',
    timeout: int = 60,
    check_interval: int = 2
) -> bool:
    """
    Wait for service to become healthy.
    
    Args:
        base_url: Base URL of service
        health_path: Path to health endpoint
        timeout: Maximum time to wait
        check_interval: Time between checks
        
    Returns:
        True if healthy, False if timeout
    """
    url = f"{base_url.rstrip('/')}{health_path}"
    return wait_for_url(url, timeout=timeout, check_interval=check_interval)


def get_response_time(url: str, method: str = 'GET', **kwargs) -> Optional[float]:
    """
    Measure response time for a request.
    
    Args:
        url: Target URL
        method: HTTP method
        **kwargs: Additional arguments for make_request
        
    Returns:
        Response time in seconds or None if failed
    """
    try:
        start_time = time.time()
        make_request(method, url, **kwargs)
        return time.time() - start_time
    except requests.exceptions.RequestException:
        return None

