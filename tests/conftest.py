"""
Pytest Configuration and Fixtures

Global fixtures and configuration for all tests.
"""

import os
import sys
import pytest
import yaml
from pathlib import Path
from dotenv import load_dotenv

# Add project root to path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

# Load test environment variables
env_test_file = project_root / "tests" / "config" / "env.test"
if env_test_file.exists():
    load_dotenv(env_test_file)

# Load test configuration
config_file = project_root / "tests" / "config" / "test-config.yml"
with open(config_file, 'r') as f:
    TEST_CONFIG = yaml.safe_load(f)


# ============================================
# Pytest Configuration Hooks
# ============================================

def pytest_configure(config):
    """Configure pytest with custom markers and settings."""
    config.addinivalue_line(
        "markers", "unit: Unit tests - fast, isolated tests"
    )
    config.addinivalue_line(
        "markers", "integration: Integration tests - tests service interactions"
    )
    config.addinivalue_line(
        "markers", "e2e: End-to-end tests - full user workflows"
    )
    config.addinivalue_line(
        "markers", "performance: Performance tests - load and stress tests"
    )
    config.addinivalue_line(
        "markers", "regression: Regression tests - prevent breaking changes"
    )


def pytest_collection_modifyitems(config, items):
    """Modify test items based on configuration."""
    # Skip slow tests if not enabled
    if not TEST_CONFIG.get('features', {}).get('enable_slow_tests', False):
        skip_slow = pytest.mark.skip(reason="Slow tests disabled")
        for item in items:
            if "slow" in item.keywords:
                item.add_marker(skip_slow)


# ============================================
# Session-Level Fixtures
# ============================================

@pytest.fixture(scope="session")
def test_config():
    """Provide test configuration to all tests."""
    return TEST_CONFIG


@pytest.fixture(scope="session")
def base_urls(test_config):
    """Provide base URLs for all services."""
    return test_config['base_urls']


@pytest.fixture(scope="session")
def credentials(test_config):
    """Provide test credentials."""
    return test_config['credentials']


@pytest.fixture(scope="session")
def timeouts(test_config):
    """Provide timeout settings."""
    return test_config['timeouts']


# ============================================
# Function-Level Fixtures
# ============================================

@pytest.fixture
def http_client():
    """Provide HTTP client for API testing."""
    import requests
    session = requests.Session()
    session.verify = False  # Disable SSL verification for tests
    yield session
    session.close()


@pytest.fixture
async def async_http_client():
    """Provide async HTTP client for API testing."""
    import httpx
    async with httpx.AsyncClient(verify=False) as client:
        yield client


# ============================================
# Docker Fixtures
# ============================================

@pytest.fixture(scope="session")
def docker_client():
    """Provide Docker client for container management."""
    import docker
    client = docker.from_env()
    yield client
    client.close()


@pytest.fixture
def docker_compose_file():
    """Path to docker-compose test file."""
    return project_root / "docker-compose.test.yml"


# ============================================
# Database Fixtures
# ============================================

@pytest.fixture(scope="session")
def postgres_connection_params(credentials):
    """PostgreSQL connection parameters."""
    return {
        'host': os.getenv('POSTGRES_HOST', 'localhost'),
        'port': int(os.getenv('POSTGRES_PORT', 5432)),
        'database': credentials['postgres']['database'],
        'user': credentials['postgres']['username'],
        'password': credentials['postgres']['password'],
    }


@pytest.fixture
def db_connection(postgres_connection_params):
    """Provide database connection."""
    import psycopg2
    conn = psycopg2.connect(**postgres_connection_params)
    yield conn
    conn.close()


# ============================================
# Service Health Fixtures
# ============================================

@pytest.fixture
def wait_for_service():
    """Wait for a service to become healthy."""
    import time
    import requests
    
    def _wait(url: str, timeout: int = 60, check_interval: int = 2):
        """Wait for service to respond."""
        start_time = time.time()
        while time.time() - start_time < timeout:
            try:
                response = requests.get(url, timeout=5, verify=False)
                if response.status_code < 500:
                    return True
            except requests.exceptions.RequestException:
                pass
            time.sleep(check_interval)
        return False
    
    return _wait


# ============================================
# Cleanup Fixtures
# ============================================

@pytest.fixture(autouse=True)
def cleanup_after_test():
    """Cleanup after each test."""
    yield
    # Add cleanup logic here if needed


@pytest.fixture(scope="session", autouse=True)
def cleanup_session():
    """Cleanup after entire test session."""
    yield
    # Add session cleanup logic here if needed
    print("\n🧹 Cleaning up test session...")

