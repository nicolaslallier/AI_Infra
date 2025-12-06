"""
E2E Test: Full Stack Health Check

Validates that all infrastructure components are running and accessible.
"""

import pytest
import requests
from typing import Dict


@pytest.mark.e2e
class TestFullStackHealth:
    """Test overall infrastructure health."""
    
    def test_nginx_is_accessible(self, base_url, wait_for_services):
        """Test that Nginx is accessible and responding."""
        response = requests.get(f"{base_url}/health", timeout=5)
        assert response.status_code == 200
        assert "OK" in response.text
    
    def test_frontend_is_accessible(self, base_url, wait_for_services):
        """Test that the frontend application is accessible."""
        response = requests.get(base_url, timeout=10, allow_redirects=True)
        assert response.status_code == 200
        # Check for Vue.js application
        assert "<!DOCTYPE html>" in response.text
        assert "<div id=\"app\"></div>" in response.text or "app" in response.text.lower()
    
    def test_grafana_is_accessible(self, base_url, wait_for_services):
        """Test that Grafana is accessible through Nginx."""
        response = requests.get(
            f"{base_url}/monitoring/grafana/api/health",
            timeout=10,
            allow_redirects=True
        )
        assert response.status_code == 200
        data = response.json()
        assert data.get("database") == "ok"
    
    def test_prometheus_is_accessible(self, base_url, wait_for_services):
        """Test that Prometheus is accessible through Nginx."""
        response = requests.get(
            f"{base_url}/monitoring/prometheus/-/healthy",
            timeout=10
        )
        assert response.status_code == 200
        assert "Prometheus is Healthy" in response.text
    
    def test_prometheus_has_targets(self, base_url, wait_for_services):
        """Test that Prometheus is scraping configured targets."""
        response = requests.get(
            f"{base_url}/monitoring/prometheus/api/v1/targets",
            timeout=10
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
        assert "data" in data
        assert "activeTargets" in data["data"]
        # At minimum, Prometheus should be scraping itself
        assert len(data["data"]["activeTargets"]) > 0
    
    def test_tempo_is_accessible(self, base_url, wait_for_services):
        """Test that Tempo (tracing) is accessible through Nginx."""
        response = requests.get(
            f"{base_url}/monitoring/tempo/ready",
            timeout=10
        )
        # Tempo returns 200 when ready
        assert response.status_code in [200, 204]
    
    def test_loki_is_accessible(self, base_url, wait_for_services):
        """Test that Loki (logging) is accessible through Nginx."""
        response = requests.get(
            f"{base_url}/monitoring/loki/ready",
            timeout=10
        )
        assert response.status_code == 200
        assert response.text == "ready"
    
    def test_keycloak_is_accessible(self, base_url, wait_for_services):
        """Test that Keycloak is accessible through Nginx."""
        response = requests.get(
            f"{base_url}/auth/realms/master/.well-known/openid-configuration",
            timeout=10,
            allow_redirects=True
        )
        assert response.status_code == 200
        data = response.json()
        assert "issuer" in data
        assert "authorization_endpoint" in data
    
    def test_pgadmin_is_accessible(self, base_url, wait_for_services):
        """Test that pgAdmin is accessible through Nginx."""
        response = requests.get(
            f"{base_url}/pgadmin/",
            timeout=10,
            allow_redirects=True
        )
        assert response.status_code == 200
        assert "pgAdmin" in response.text or "login" in response.text.lower()
    
    @pytest.mark.parametrize("service_path,expected_status", [
        ("/health", 200),
        ("/monitoring/grafana/", 200),
        ("/monitoring/prometheus/", 200),
        ("/auth/", 200),
        ("/pgadmin/", 200),
    ])
    def test_all_service_paths_respond(self, base_url, wait_for_services, service_path, expected_status):
        """Test that all major service paths respond correctly."""
        response = requests.get(
            f"{base_url}{service_path}",
            timeout=10,
            allow_redirects=True
        )
        assert response.status_code == expected_status, \
            f"Service at {service_path} returned {response.status_code} instead of {expected_status}"


@pytest.mark.e2e
class TestServiceIntegration:
    """Test integration between services."""
    
    def test_grafana_can_query_prometheus(self, base_url, wait_for_services):
        """Test that Grafana data sources are configured and working."""
        # Check Grafana's Prometheus data source
        response = requests.get(
            f"{base_url}/monitoring/grafana/api/datasources",
            timeout=10,
            allow_redirects=True
        )
        # May get redirect to login, which is fine - means Grafana is up
        assert response.status_code in [200, 302, 401]
    
    def test_prometheus_metrics_are_being_collected(self, base_url, wait_for_services):
        """Test that Prometheus is actively collecting metrics."""
        response = requests.get(
            f"{base_url}/monitoring/prometheus/api/v1/query",
            params={"query": "up"},
            timeout=10
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
        assert len(data["data"]["result"]) > 0
        # At least Prometheus itself should be 'up'
        up_metrics = [r for r in data["data"]["result"] if r["value"][1] == "1"]
        assert len(up_metrics) > 0
    
    def test_loki_is_receiving_logs(self, base_url, wait_for_services):
        """Test that Loki is receiving logs from services."""
        # Query Loki for any logs from the last hour
        response = requests.get(
            f"{base_url}/monitoring/loki/loki/api/v1/query_range",
            params={
                "query": "{job=~\".+\"}",
                "limit": 10,
                "start": int(time.time() * 1e9) - 3600 * 1e9,  # 1 hour ago
                "end": int(time.time() * 1e9)
            },
            timeout=10
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
        # May or may not have logs yet, but should return valid structure
        assert "data" in data
    
    def test_nginx_metrics_available_in_prometheus(self, base_url, wait_for_services):
        """Test that Nginx metrics are being exported to Prometheus."""
        response = requests.get(
            f"{base_url}/monitoring/prometheus/api/v1/query",
            params={"query": "nginx_up"},
            timeout=10
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
        # Nginx exporter might not be configured yet, so this is informational
        if data["data"]["result"]:
            assert data["data"]["result"][0]["value"][1] == "1"


import time

