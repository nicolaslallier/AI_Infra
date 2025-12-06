"""
Integration Test: Keycloak Integration

Tests Keycloak integration with infrastructure.
"""

import pytest
import requests


@pytest.mark.integration
class TestKeycloakBasicFunctionality:
    """Test basic Keycloak functionality."""
    
    def test_keycloak_master_realm_accessible(self, docker_services_running, base_url):
        """Test that master realm is accessible."""
        response = requests.get(
            f"{base_url}/auth/realms/master",
            timeout=10
        )
        assert response.status_code == 200
        data = response.json()
        assert data["realm"] == "master"
        assert "public_key" in data
    
    def test_keycloak_openid_configuration(self, docker_services_running, base_url):
        """Test OpenID Connect configuration."""
        response = requests.get(
            f"{base_url}/auth/realms/master/.well-known/openid-configuration",
            timeout=10
        )
        assert response.status_code == 200
        data = response.json()
        
        required_endpoints = [
            "issuer",
            "authorization_endpoint",
            "token_endpoint",
            "userinfo_endpoint",
            "jwks_uri",
        ]
        
        for endpoint in required_endpoints:
            assert endpoint in data
            assert data[endpoint]
    
    def test_keycloak_token_endpoint_exists(self, docker_services_running, base_url):
        """Test that token endpoint is accessible."""
        response = requests.post(
            f"{base_url}/auth/realms/master/protocol/openid-connect/token",
            data={"grant_type": "invalid"},  # Invalid to test endpoint exists
            timeout=10
        )
        # Should return 400/401, not 404
        assert response.status_code in [400, 401]


@pytest.mark.integration
class TestKeycloakNginxIntegration:
    """Test Keycloak integration through Nginx."""
    
    def test_keycloak_accessible_through_nginx(self, docker_services_running, base_url):
        """Test that Keycloak is accessible through Nginx reverse proxy."""
        response = requests.get(
            f"{base_url}/auth/",
            timeout=10,
            allow_redirects=True
        )
        assert response.status_code == 200
        assert "keycloak" in response.text.lower() or "auth" in response.text.lower()
    
    def test_keycloak_admin_console_accessible(self, docker_services_running, base_url):
        """Test that admin console is accessible through Nginx."""
        response = requests.get(
            f"{base_url}/auth/admin/",
            timeout=10,
            allow_redirects=True
        )
        assert response.status_code == 200


@pytest.mark.integration
class TestKeycloakDatabaseIntegration:
    """Test Keycloak database integration."""
    
    def test_keycloak_persists_data(self, docker_services_running, base_url):
        """Test that Keycloak can persist data (implies DB works)."""
        # If Keycloak returns realm data, it's reading from database
        response = requests.get(
            f"{base_url}/auth/realms/master",
            timeout=10
        )
        assert response.status_code == 200
        data = response.json()
        assert "realm" in data
        assert "public_key" in data
        # Keycloak loads this from database

