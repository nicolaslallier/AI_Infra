"""
E2E Tests for MinIO Cluster Health and Availability
Tests distributed cluster setup, node health, and basic connectivity.
"""
import pytest
import requests
from typing import Dict

# MinIO endpoints
MINIO_NODES = [
    "http://localhost/storage",
]
MINIO_CONSOLE = "http://localhost/minio-console"


class TestMinIOClusterHealth:
    """Test suite for MinIO cluster health and availability."""
    
    def test_minio_api_endpoint_accessible(self):
        """Test that MinIO S3 API endpoint is accessible through NGINX."""
        try:
            response = requests.get(
                f"{MINIO_NODES[0]}/",
                timeout=10,
                allow_redirects=False
            )
            # MinIO returns various codes for unauthenticated access
            # 403 (Forbidden) or redirect is acceptable
            assert response.status_code in [200, 403, 307], \
                f"MinIO API endpoint not accessible: {response.status_code}"
        except requests.exceptions.RequestException as e:
            pytest.fail(f"Failed to connect to MinIO API: {str(e)}")
    
    def test_minio_console_accessible(self):
        """Test that MinIO console UI is accessible through NGINX."""
        try:
            response = requests.get(
                f"{MINIO_CONSOLE}/",
                timeout=10,
                allow_redirects=True
            )
            # Console should return 200 (login page) or redirect to login
            assert response.status_code == 200, \
                f"MinIO console not accessible: {response.status_code}"
            # Check for MinIO console content
            assert "MinIO" in response.text or "minio" in response.text.lower(), \
                "MinIO console content not found"
        except requests.exceptions.RequestException as e:
            pytest.fail(f"Failed to connect to MinIO console: {str(e)}")
    
    def test_minio_health_endpoint(self):
        """Test MinIO health check endpoint."""
        try:
            # Health endpoint should be accessible without auth
            response = requests.get(
                f"{MINIO_NODES[0]}/minio/health/live",
                timeout=10
            )
            assert response.status_code == 200, \
                f"MinIO health check failed: {response.status_code}"
        except requests.exceptions.RequestException as e:
            pytest.fail(f"MinIO health check failed: {str(e)}")
    
    def test_minio_readiness_endpoint(self):
        """Test MinIO readiness check endpoint."""
        try:
            response = requests.get(
                f"{MINIO_NODES[0]}/minio/health/ready",
                timeout=10
            )
            # Readiness check should return 200 when cluster is ready
            assert response.status_code == 200, \
                f"MinIO not ready: {response.status_code}"
        except requests.exceptions.RequestException as e:
            pytest.fail(f"MinIO readiness check failed: {str(e)}")


class TestMinIOMetrics:
    """Test suite for MinIO Prometheus metrics exposure."""
    
    def test_minio_metrics_endpoint_exists(self):
        """Test that MinIO exposes Prometheus metrics."""
        try:
            # Note: Metrics endpoint may require authentication
            response = requests.get(
                f"{MINIO_NODES[0]}/minio/v2/metrics/cluster",
                timeout=10
            )
            # Should return 200 with public auth or 401/403 if auth required
            assert response.status_code in [200, 401, 403], \
                f"Unexpected metrics response: {response.status_code}"
            
            if response.status_code == 200:
                # If accessible, verify it's Prometheus format
                assert "# TYPE" in response.text or "# HELP" in response.text, \
                    "Metrics endpoint not in Prometheus format"
        except requests.exceptions.RequestException as e:
            pytest.fail(f"Failed to access MinIO metrics: {str(e)}")


class TestMinIONetworkIsolation:
    """Test suite for MinIO network security and isolation."""
    
    def test_minio_not_directly_accessible(self):
        """Test that MinIO nodes are not directly accessible (must go through NGINX)."""
        # MinIO nodes should not be exposed on their direct ports
        direct_ports = [9000, 9001]
        
        for port in direct_ports:
            try:
                response = requests.get(
                    f"http://localhost:{port}/",
                    timeout=2
                )
                pytest.fail(
                    f"MinIO is directly accessible on port {port} - "
                    f"this is a security risk!"
                )
            except requests.exceptions.ConnectionError:
                # This is expected - direct access should be blocked
                pass
            except requests.exceptions.Timeout:
                # Timeout is also acceptable
                pass


class TestMinIONginxRouting:
    """Test suite for NGINX reverse proxy routing to MinIO."""
    
    def test_storage_path_routes_to_minio(self):
        """Test that /storage/ path routes to MinIO S3 API."""
        try:
            response = requests.get(
                "http://localhost/storage/",
                timeout=10,
                allow_redirects=False
            )
            # Should get MinIO response (403 or redirect for unauthenticated)
            assert response.status_code in [200, 403, 307], \
                f"Storage path not routing correctly: {response.status_code}"
        except requests.exceptions.RequestException as e:
            pytest.fail(f"Storage path routing failed: {str(e)}")
    
    def test_minio_console_path_routes_correctly(self):
        """Test that /minio-console/ path routes to MinIO console."""
        try:
            response = requests.get(
                "http://localhost/minio-console/",
                timeout=10,
                allow_redirects=True
            )
            assert response.status_code == 200, \
                f"Console path not routing correctly: {response.status_code}"
        except requests.exceptions.RequestException as e:
            pytest.fail(f"Console path routing failed: {str(e)}")
    
    def test_storage_redirect_works(self):
        """Test that /storage redirects to /storage/."""
        try:
            response = requests.get(
                "http://localhost/storage",
                timeout=10,
                allow_redirects=False
            )
            # Should redirect to /storage/
            assert response.status_code in [301, 302], \
                f"Storage redirect not working: {response.status_code}"
            
            if response.status_code in [301, 302]:
                assert response.headers.get('Location', '').endswith('/storage/'), \
                    "Storage redirect not pointing to /storage/"
        except requests.exceptions.RequestException as e:
            pytest.fail(f"Storage redirect test failed: {str(e)}")


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

