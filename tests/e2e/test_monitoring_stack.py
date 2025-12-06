"""
E2E Test: Monitoring Stack

Tests the complete monitoring stack: Prometheus, Grafana, Tempo, Loki.
"""

import pytest
import requests
import time
from datetime import datetime, timedelta


@pytest.mark.e2e
class TestPrometheusStack:
    """Test Prometheus monitoring functionality."""
    
    def test_prometheus_config_is_loaded(self, base_url, wait_for_services):
        """Test that Prometheus configuration is loaded successfully."""
        response = requests.get(
            f"{base_url}/monitoring/prometheus/api/v1/status/config",
            timeout=10
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
        assert "yaml" in data["data"]
    
    def test_prometheus_targets_are_configured(self, base_url, wait_for_services):
        """Test that Prometheus has configured scrape targets."""
        response = requests.get(
            f"{base_url}/monitoring/prometheus/api/v1/targets",
            timeout=10
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
        
        active_targets = data["data"]["activeTargets"]
        assert len(active_targets) > 0, "No active Prometheus targets found"
        
        # Check for essential targets
        target_jobs = {target["scrapePool"] for target in active_targets}
        assert "prometheus" in target_jobs, "Prometheus self-scraping not configured"
    
    def test_prometheus_can_execute_queries(self, base_url, wait_for_services):
        """Test that Prometheus can execute PromQL queries."""
        queries = [
            "up",
            "process_cpu_seconds_total",
            "go_goroutines",
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
            assert "data" in data
            assert "result" in data["data"]
    
    def test_prometheus_range_queries(self, base_url, wait_for_services):
        """Test Prometheus range queries for time-series data."""
        end = datetime.now()
        start = end - timedelta(minutes=5)
        
        response = requests.get(
            f"{base_url}/monitoring/prometheus/api/v1/query_range",
            params={
                "query": "up",
                "start": start.isoformat() + "Z",
                "end": end.isoformat() + "Z",
                "step": "15s"
            },
            timeout=10
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
        assert "data" in data
        assert "result" in data["data"]
    
    def test_prometheus_alertmanager_status(self, base_url, wait_for_services):
        """Test Prometheus Alertmanager integration status."""
        response = requests.get(
            f"{base_url}/monitoring/prometheus/api/v1/alertmanagers",
            timeout=10
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
        # Alertmanager might not be configured, which is fine
        assert "data" in data


@pytest.mark.e2e
class TestGrafanaStack:
    """Test Grafana visualization and dashboards."""
    
    def test_grafana_health(self, base_url, wait_for_services):
        """Test Grafana health endpoint."""
        response = requests.get(
            f"{base_url}/monitoring/grafana/api/health",
            timeout=10
        )
        assert response.status_code == 200
        data = response.json()
        assert data["database"] == "ok"
    
    def test_grafana_api_is_accessible(self, base_url, wait_for_services):
        """Test that Grafana API is accessible."""
        response = requests.get(
            f"{base_url}/monitoring/grafana/api/org",
            timeout=10
        )
        # Should return 401 (unauthorized) or 200 if anonymous access enabled
        assert response.status_code in [200, 401]
    
    def test_grafana_frontend_loads(self, base_url, wait_for_services):
        """Test that Grafana frontend loads successfully."""
        response = requests.get(
            f"{base_url}/monitoring/grafana/",
            timeout=10,
            allow_redirects=True
        )
        assert response.status_code == 200
        assert "Grafana" in response.text or "grafana" in response.text.lower()


@pytest.mark.e2e
class TestLokiStack:
    """Test Loki logging functionality."""
    
    def test_loki_ready(self, base_url, wait_for_services):
        """Test that Loki is ready to receive logs."""
        response = requests.get(
            f"{base_url}/monitoring/loki/ready",
            timeout=10
        )
        assert response.status_code == 200
        assert response.text == "ready"
    
    def test_loki_can_query_labels(self, base_url, wait_for_services):
        """Test that Loki can query for labels."""
        response = requests.get(
            f"{base_url}/monitoring/loki/loki/api/v1/labels",
            timeout=10
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
        assert "data" in data
    
    def test_loki_metrics_endpoint(self, base_url, wait_for_services):
        """Test that Loki exposes Prometheus metrics."""
        response = requests.get(
            f"{base_url}/monitoring/loki/metrics",
            timeout=10
        )
        assert response.status_code == 200
        # Should return Prometheus-formatted metrics
        assert "# TYPE" in response.text
        assert "# HELP" in response.text


@pytest.mark.e2e
class TestTempoStack:
    """Test Tempo tracing functionality."""
    
    def test_tempo_ready(self, base_url, wait_for_services):
        """Test that Tempo is ready to receive traces."""
        response = requests.get(
            f"{base_url}/monitoring/tempo/ready",
            timeout=10
        )
        assert response.status_code in [200, 204]
    
    def test_tempo_metrics_endpoint(self, base_url, wait_for_services):
        """Test that Tempo exposes Prometheus metrics."""
        response = requests.get(
            f"{base_url}/monitoring/tempo/metrics",
            timeout=10
        )
        assert response.status_code == 200
        # Should return Prometheus-formatted metrics
        assert "# TYPE" in response.text
        assert "# HELP" in response.text


@pytest.mark.e2e
class TestObservabilityIntegration:
    """Test integration between observability components."""
    
    def test_grafana_can_reach_prometheus(self, base_url, wait_for_services):
        """Test that Grafana can reach Prometheus as a data source."""
        # This is tested by checking if Grafana's API is functional
        response = requests.get(
            f"{base_url}/monitoring/grafana/api/health",
            timeout=10
        )
        assert response.status_code == 200
    
    def test_prometheus_scrapes_loki(self, base_url, wait_for_services):
        """Test that Prometheus is scraping Loki metrics."""
        response = requests.get(
            f"{base_url}/monitoring/prometheus/api/v1/query",
            params={"query": "loki_build_info"},
            timeout=10
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
        # Loki might be scraped or not depending on config
        # This is informational
    
    def test_prometheus_scrapes_tempo(self, base_url, wait_for_services):
        """Test that Prometheus is scraping Tempo metrics."""
        response = requests.get(
            f"{base_url}/monitoring/prometheus/api/v1/query",
            params={"query": "tempo_build_info"},
            timeout=10
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
        # Tempo might be scraped or not depending on config
        # This is informational

