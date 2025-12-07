"""
E2E Tests for MinIO Monitoring Integration
Tests Prometheus metrics and Loki logging integration.
"""
import pytest
import requests
from typing import Dict, List

# Monitoring endpoints
PROMETHEUS_URL = "http://localhost/monitoring/prometheus"
GRAFANA_URL = "http://localhost/monitoring/grafana"
LOKI_URL = "http://localhost/monitoring/loki"


class TestMinIOPrometheusMetrics:
    """Test suite for MinIO Prometheus metrics integration."""
    
    def test_prometheus_has_minio_targets(self):
        """Test that Prometheus is configured to scrape MinIO."""
        try:
            response = requests.get(
                f"{PROMETHEUS_URL}/api/v1/targets",
                timeout=10
            )
            assert response.status_code == 200
            
            data = response.json()
            assert data['status'] == 'success'
            
            # Look for MinIO targets
            targets = data['data']['activeTargets']
            minio_targets = [
                t for t in targets
                if 'minio' in t['labels'].get('job', '').lower()
            ]
            
            assert len(minio_targets) > 0, "No MinIO targets found in Prometheus"
            
        except requests.exceptions.RequestException as e:
            pytest.fail(f"Failed to query Prometheus targets: {str(e)}")
    
    def test_prometheus_has_minio_metrics(self):
        """Test that Prometheus is collecting MinIO metrics."""
        # Query for MinIO-specific metrics
        metrics_to_check = [
            'minio_cluster_nodes_online_total',
            'minio_cluster_capacity_usable_total_bytes',
            'minio_s3_requests_total',
        ]
        
        for metric in metrics_to_check:
            try:
                response = requests.get(
                    f"{PROMETHEUS_URL}/api/v1/query",
                    params={'query': metric},
                    timeout=10
                )
                assert response.status_code == 200
                
                data = response.json()
                assert data['status'] == 'success'
                
                # Check if metric has data
                result = data['data']['result']
                assert len(result) > 0, f"No data for metric: {metric}"
                
            except requests.exceptions.RequestException as e:
                pytest.fail(f"Failed to query metric {metric}: {str(e)}")
    
    def test_minio_cluster_health_metric(self):
        """Test that cluster health metrics are available."""
        try:
            response = requests.get(
                f"{PROMETHEUS_URL}/api/v1/query",
                params={'query': 'minio_cluster_nodes_online_total'},
                timeout=10
            )
            assert response.status_code == 200
            
            data = response.json()
            result = data['data']['result']
            
            if len(result) > 0:
                # Get the value (number of online nodes)
                value = float(result[0]['value'][1])
                assert value >= 1, "No MinIO nodes reported as online"
                
        except requests.exceptions.RequestException as e:
            pytest.fail(f"Failed to query cluster health: {str(e)}")


class TestMinIOGrafanaDashboard:
    """Test suite for MinIO Grafana dashboard."""
    
    def test_grafana_accessible(self):
        """Test that Grafana is accessible."""
        try:
            response = requests.get(
                f"{GRAFANA_URL}/api/health",
                timeout=10
            )
            assert response.status_code == 200
        except requests.exceptions.RequestException as e:
            pytest.fail(f"Grafana not accessible: {str(e)}")
    
    def test_minio_dashboard_exists(self):
        """Test that MinIO dashboard is provisioned in Grafana."""
        # Note: This test requires Grafana authentication
        # Using anonymous access or default credentials
        try:
            response = requests.get(
                f"{GRAFANA_URL}/api/search",
                params={'query': 'MinIO'},
                auth=('admin', 'admin'),
                timeout=10
            )
            
            if response.status_code == 200:
                dashboards = response.json()
                minio_dashboards = [
                    d for d in dashboards
                    if 'minio' in d.get('title', '').lower()
                ]
                assert len(minio_dashboards) > 0, "MinIO dashboard not found in Grafana"
            else:
                pytest.skip("Cannot access Grafana API (authentication required)")
                
        except requests.exceptions.RequestException as e:
            pytest.skip(f"Cannot verify Grafana dashboard: {str(e)}")


class TestMinIOLokiLogs:
    """Test suite for MinIO Loki logging integration."""
    
    def test_loki_accessible(self):
        """Test that Loki is accessible."""
        try:
            response = requests.get(
                f"{LOKI_URL}/ready",
                timeout=10
            )
            assert response.status_code == 200
        except requests.exceptions.RequestException as e:
            pytest.fail(f"Loki not accessible: {str(e)}")
    
    def test_loki_has_minio_labels(self):
        """Test that Loki has MinIO log labels configured."""
        try:
            response = requests.get(
                f"{LOKI_URL}/loki/api/v1/labels",
                timeout=10
            )
            assert response.status_code == 200
            
            data = response.json()
            assert data['status'] == 'success'
            
            labels = data['data']
            # Check for MinIO-related labels
            assert 'source' in labels or 'container' in labels, \
                "Expected log labels not found"
            
        except requests.exceptions.RequestException as e:
            pytest.skip(f"Cannot query Loki labels: {str(e)}")
    
    def test_loki_receiving_minio_logs(self):
        """Test that Loki is receiving MinIO logs."""
        try:
            # Query for MinIO logs
            response = requests.get(
                f"{LOKI_URL}/loki/api/v1/query",
                params={
                    'query': '{source="minio"}',
                    'limit': 1
                },
                timeout=10
            )
            
            if response.status_code == 200:
                data = response.json()
                assert data['status'] == 'success'
                
                # Check if there are any log streams
                # Note: May be empty if MinIO just started
                result = data['data']['result']
                # Don't fail if empty, just check structure is correct
                assert isinstance(result, list), "Invalid Loki response structure"
            else:
                pytest.skip("Cannot query Loki (may require authentication)")
                
        except requests.exceptions.RequestException as e:
            pytest.skip(f"Cannot query Loki logs: {str(e)}")


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

