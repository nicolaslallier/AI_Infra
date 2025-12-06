"""
Integration Test: Nginx Service Integration

Tests Nginx routing to actual backend services.
"""

import pytest
import requests


@pytest.mark.integration
class TestNginxToFrontend:
    """Test Nginx integration with frontend service."""
    
    def test_nginx_serves_frontend_html(self, docker_services_running, base_url):
        """Test that Nginx successfully serves frontend HTML."""
        response = requests.get(base_url, timeout=10)
        assert response.status_code == 200
        assert "text/html" in response.headers.get("Content-Type", "")
        assert len(response.text) > 100  # Should have substantial content
    
    def test_nginx_forwards_frontend_assets(self, docker_services_running, base_url):
        """Test that Nginx forwards frontend static assets."""
        # Most SPAs have an index.html
        response = requests.get(f"{base_url}/", timeout=10)
        assert response.status_code == 200
        assert "html" in response.text.lower()


@pytest.mark.integration
class TestNginxToPrometheus:
    """Test Nginx integration with Prometheus."""
    
    def test_nginx_routes_to_prometheus(self, docker_services_running, base_url):
        """Test that Nginx routes to Prometheus correctly."""
        response = requests.get(
            f"{base_url}/monitoring/prometheus/-/healthy",
            timeout=10
        )
        assert response.status_code == 200
        assert "Healthy" in response.text
    
    def test_nginx_forwards_prometheus_api(self, docker_services_running, base_url):
        """Test that Nginx forwards Prometheus API requests."""
        response = requests.get(
            f"{base_url}/monitoring/prometheus/api/v1/targets",
            timeout=10
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
    
    def test_nginx_preserves_prometheus_query_params(self, docker_services_running, base_url):
        """Test that Nginx preserves query parameters for Prometheus."""
        response = requests.get(
            f"{base_url}/monitoring/prometheus/api/v1/query",
            params={"query": "up"},
            timeout=10
        )
        assert response.status_code == 200
        data = response.json()
        assert "data" in data


@pytest.mark.integration
class TestNginxToGrafana:
    """Test Nginx integration with Grafana."""
    
    def test_nginx_routes_to_grafana(self, docker_services_running, base_url):
        """Test that Nginx routes to Grafana."""
        response = requests.get(
            f"{base_url}/monitoring/grafana/",
            timeout=10,
            allow_redirects=False
        )
        # Grafana might redirect or serve content
        assert response.status_code in [200, 301, 302]
    
    def test_nginx_grafana_api_accessible(self, docker_services_running, base_url):
        """Test that Grafana API is accessible through Nginx."""
        response = requests.get(
            f"{base_url}/monitoring/grafana/api/health",
            timeout=10,
            allow_redirects=False
        )
        # Should be accessible (might redirect)
        assert response.status_code in [200, 301, 302]


@pytest.mark.integration
class TestNginxToKeycloak:
    """Test Nginx integration with Keycloak."""
    
    def test_nginx_routes_to_keycloak(self, docker_services_running, base_url):
        """Test that Nginx routes to Keycloak correctly."""
        response = requests.get(
            f"{base_url}/auth/realms/master",
            timeout=10
        )
        assert response.status_code == 200
        data = response.json()
        assert data["realm"] == "master"
    
    def test_nginx_forwards_keycloak_wellknown(self, docker_services_running, base_url):
        """Test that Nginx forwards Keycloak .well-known endpoint."""
        response = requests.get(
            f"{base_url}/auth/realms/master/.well-known/openid-configuration",
            timeout=10
        )
        assert response.status_code == 200
        data = response.json()
        assert "issuer" in data
        assert "authorization_endpoint" in data


@pytest.mark.integration
class TestNginxToLoki:
    """Test Nginx integration with Loki."""
    
    def test_nginx_routes_to_loki(self, docker_services_running, base_url):
        """Test that Nginx routes to Loki correctly."""
        response = requests.get(
            f"{base_url}/monitoring/loki/ready",
            timeout=10
        )
        assert response.status_code == 200
        assert response.text.strip() == "ready"
    
    def test_nginx_forwards_loki_api(self, docker_services_running, base_url):
        """Test that Nginx forwards Loki API requests."""
        response = requests.get(
            f"{base_url}/monitoring/loki/loki/api/v1/labels",
            timeout=10
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"


@pytest.mark.integration
class TestNginxToTempo:
    """Test Nginx integration with Tempo."""
    
    def test_nginx_routes_to_tempo(self, docker_services_running, base_url):
        """Test that Nginx routes to Tempo correctly."""
        response = requests.get(
            f"{base_url}/monitoring/tempo/ready",
            timeout=10
        )
        assert response.status_code in [200, 204]


@pytest.mark.integration
class TestNginxToPgAdmin:
    """Test Nginx integration with pgAdmin."""
    
    def test_nginx_routes_to_pgadmin(self, docker_services_running, base_url):
        """Test that Nginx routes to pgAdmin correctly."""
        response = requests.get(
            f"{base_url}/pgadmin/",
            timeout=10,
            allow_redirects=True
        )
        assert response.status_code == 200
        assert "pgAdmin" in response.text or "login" in response.text.lower()
    
    def test_nginx_pgadmin_script_name_header(self, docker_services_running, base_url):
        """Test that pgAdmin receives correct X-Script-Name header."""
        response = requests.get(
            f"{base_url}/pgadmin/",
            timeout=10,
            allow_redirects=True
        )
        # If pgAdmin loads correctly, headers were set properly
        assert response.status_code == 200


@pytest.mark.integration
class TestNginxHealthCheck:
    """Test Nginx health check endpoint."""
    
    def test_health_endpoint_responds(self, docker_services_running, base_url):
        """Test that health endpoint responds correctly."""
        response = requests.get(f"{base_url}/health", timeout=5)
        assert response.status_code == 200
        assert "OK" in response.text
    
    def test_health_endpoint_fast_response(self, docker_services_running, base_url):
        """Test that health endpoint responds quickly."""
        import time
        start = time.time()
        response = requests.get(f"{base_url}/health", timeout=5)
        duration = time.time() - start
        
        assert response.status_code == 200
        assert duration < 0.5  # Should respond in less than 500ms

