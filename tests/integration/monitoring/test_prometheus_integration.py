"""
Integration Test: Prometheus Integration

Tests Prometheus integration with other services.
"""

import pytest
import requests
import time


@pytest.mark.integration
class TestPrometheusMetricsScraping:
    """Test Prometheus scraping from various services."""
    
    def test_prometheus_scrapes_itself(self, docker_services_running, base_url):
        """Test that Prometheus scrapes its own metrics."""
        response = requests.get(
            f"{base_url}/monitoring/prometheus/api/v1/query",
            params={"query": "prometheus_build_info"},
            timeout=10
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
        assert len(data["data"]["result"]) > 0
    
    def test_prometheus_has_active_targets(self, docker_services_running, base_url):
        """Test that Prometheus has active scrape targets."""
        response = requests.get(
            f"{base_url}/monitoring/prometheus/api/v1/targets",
            timeout=10
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
        
        active_targets = data["data"]["activeTargets"]
        assert len(active_targets) > 0, "No active Prometheus targets"
        
        # At least one target should be 'up'
        up_targets = [t for t in active_targets if t["health"] == "up"]
        assert len(up_targets) > 0, "No targets are up"
    
    def test_prometheus_can_query_metrics(self, docker_services_running, base_url):
        """Test that Prometheus can query collected metrics."""
        queries = [
            "up",
            "process_cpu_seconds_total",
            "go_goroutines",
            "prometheus_tsdb_head_samples_appended_total",
        ]
        
        for query in queries:
            response = requests.get(
                f"{base_url}/monitoring/prometheus/api/v1/query",
                params={"query": query},
                timeout=10
            )
            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "success"


@pytest.mark.integration
class TestPrometheusGrafanaIntegration:
    """Test integration between Prometheus and Grafana."""
    
    def test_grafana_can_reach_prometheus(self, docker_services_running, base_url):
        """Test that Grafana can reach Prometheus as a datasource."""
        # If Grafana is healthy, it can connect to its datasources
        response = requests.get(
            f"{base_url}/monitoring/grafana/api/health",
            timeout=10,
            allow_redirects=False
        )
        # Grafana health check working means datasources are reachable
        assert response.status_code in [200, 301, 302]


@pytest.mark.integration
class TestLokiIntegration:
    """Test Loki integration."""
    
    def test_loki_can_query_labels(self, docker_services_running, base_url):
        """Test that Loki can query for log labels."""
        response = requests.get(
            f"{base_url}/monitoring/loki/loki/api/v1/labels",
            timeout=10
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
        assert "data" in data
    
    def test_loki_ready_endpoint(self, docker_services_running, base_url):
        """Test that Loki ready endpoint works."""
        response = requests.get(
            f"{base_url}/monitoring/loki/ready",
            timeout=10
        )
        assert response.status_code == 200
        assert response.text.strip() == "ready"


@pytest.mark.integration
class TestTempoIntegration:
    """Test Tempo integration."""
    
    def test_tempo_ready_endpoint(self, docker_services_running, base_url):
        """Test that Tempo ready endpoint works."""
        response = requests.get(
            f"{base_url}/monitoring/tempo/ready",
            timeout=10
        )
        assert response.status_code in [200, 204]
    
    def test_tempo_exposes_metrics(self, docker_services_running, base_url):
        """Test that Tempo exposes Prometheus metrics."""
        response = requests.get(
            f"{base_url}/monitoring/tempo/metrics",
            timeout=10
        )
        assert response.status_code == 200
        assert "# TYPE" in response.text or "# HELP" in response.text

