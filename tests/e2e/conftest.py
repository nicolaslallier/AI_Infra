"""
E2E Test Fixtures

Shared fixtures for end-to-end testing across the full stack.
"""

import pytest
import requests
import time
from typing import Dict, Any

@pytest.fixture(scope="session")
def base_url():
    """Base URL for the application."""
    return "http://localhost"

@pytest.fixture(scope="session")
def wait_for_services(base_url):
    """Wait for all services to be ready before running E2E tests."""
    services = {
        "nginx": f"{base_url}/health",
        "prometheus": f"{base_url}/monitoring/prometheus/-/healthy",
        "keycloak": f"{base_url}/auth/realms/master/.well-known/openid-configuration",
    }
    
    max_retries = 30
    retry_delay = 2
    
    print("\n⏳ Waiting for services to be ready...")
    
    for service_name, health_url in services.items():
        for attempt in range(max_retries):
            try:
                response = requests.get(health_url, timeout=5, allow_redirects=False)
                if response.status_code in [200, 302, 301]:
                    print(f"✅ {service_name} is ready")
                    break
            except (requests.ConnectionError, requests.Timeout, requests.exceptions.TooManyRedirects):
                if attempt < max_retries - 1:
                    print(f"⏳ Waiting for {service_name}... (attempt {attempt + 1}/{max_retries})")
                    time.sleep(retry_delay)
                else:
                    pytest.skip(f"{service_name} not available after {max_retries} attempts")
    
    print("✅ All critical services are ready\n")
    yield
    
@pytest.fixture
def auth_headers() -> Dict[str, str]:
    """Basic authentication headers for API requests."""
    return {
        "Content-Type": "application/json",
        "Accept": "application/json"
    }

