"""
Integration Test Fixtures

Shared fixtures for integration testing between components.
"""

import pytest
import requests
import psycopg2
import time
from typing import Generator


@pytest.fixture(scope="session")
def docker_services_running():
    """Verify Docker services are running before integration tests."""
    try:
        response = requests.get("http://localhost/health", timeout=5)
        if response.status_code == 200:
            return True
    except requests.ConnectionError:
        pytest.skip("Docker services not running. Start with: docker-compose up -d")
    return False


@pytest.fixture(scope="session")
def base_url():
    """Base URL for integration tests."""
    return "http://localhost"


@pytest.fixture
def postgres_connection(docker_services_running):
    """Provide PostgreSQL connection for integration tests."""
    conn_params = {
        "host": "localhost",
        "port": 5432,
        "database": "postgres",
        "user": "postgres",
        "password": "postgres"
    }
    
    try:
        conn = psycopg2.connect(**conn_params)
        yield conn
        conn.close()
    except psycopg2.OperationalError:
        pytest.skip("PostgreSQL not accessible")


@pytest.fixture
def keycloak_admin_token(docker_services_running, base_url):
    """Get Keycloak admin token for integration tests."""
    try:
        response = requests.post(
            f"{base_url}/auth/realms/master/protocol/openid-connect/token",
            data={
                "grant_type": "password",
                "client_id": "admin-cli",
                "username": "admin",
                "password": "admin"
            },
            timeout=10
        )
        if response.status_code == 200:
            return response.json()["access_token"]
    except (requests.ConnectionError, KeyError):
        pytest.skip("Keycloak not accessible or credentials invalid")

