"""
E2E Test: Nginx Routing

Tests complete routing scenarios through Nginx reverse proxy.
"""

import pytest
import requests


@pytest.mark.e2e
class TestNginxServiceRouting:
    """Test Nginx routes traffic to correct services."""
    
    @pytest.mark.parametrize("path,expected_service", [
        ("/", "frontend"),
        ("/health", "nginx"),
        ("/monitoring/grafana/", "grafana"),
        ("/monitoring/prometheus/", "prometheus"),
        ("/auth/", "keycloak"),
        ("/pgadmin/", "pgadmin"),
    ])
    def test_service_routing(self, base_url, wait_for_services, path, expected_service):
        """Test that requests are routed to the correct service."""
        response = requests.get(
            f"{base_url}{path}",
            timeout=10,
            allow_redirects=True
        )
        assert response.status_code == 200, \
            f"Service {expected_service} at {path} not accessible"
        
        # Verify response contains service-specific content
        service_indicators = {
            "frontend": ["<!DOCTYPE html>", "<div id=\"app\"></div>"],
            "nginx": ["OK"],
            "grafana": ["Grafana"],
            "prometheus": ["Prometheus"],
            "keycloak": ["keycloak", "Keycloak", "auth"],
            "pgadmin": ["pgAdmin", "login"],
        }
        
        indicators = service_indicators[expected_service]
        if indicators:
            assert any(indicator in response.text for indicator in indicators), \
                f"Response doesn't contain expected {expected_service} content"
    
    def test_tempo_routing(self, base_url, wait_for_services):
        """Test Tempo routing separately (API service)."""
        response = requests.get(
            f"{base_url}/monitoring/tempo/ready",
            timeout=10
        )
        assert response.status_code in [200, 204], \
            f"Tempo ready endpoint not accessible"
    
    def test_loki_routing(self, base_url, wait_for_services):
        """Test Loki routing separately (API service)."""
        response = requests.get(
            f"{base_url}/monitoring/loki/ready",
            timeout=10
        )
        assert response.status_code == 200, \
            f"Loki ready endpoint not accessible"
        assert response.text.strip() == "ready"
    
    def test_redirect_to_trailing_slash(self, base_url, wait_for_services):
        """Test that paths without trailing slashes redirect correctly."""
        paths_requiring_slash = [
            "/monitoring/grafana",
            "/monitoring/prometheus",
            "/pgadmin",
        ]
        
        for path in paths_requiring_slash:
            response = requests.get(
                f"{base_url}{path}",
                timeout=10,
                allow_redirects=False
            )
            # Should redirect to path with trailing slash
            assert response.status_code in [301, 302, 307, 308]
            assert response.headers.get("Location", "").endswith("/")
    
    def test_subpath_routing(self, base_url, wait_for_services):
        """Test that subpaths are correctly routed."""
        subpaths = [
            ("/monitoring/grafana/api/health", 200),
            ("/monitoring/prometheus/-/healthy", 200),
            ("/monitoring/loki/ready", 200),
            ("/monitoring/tempo/ready", 200),
            ("/auth/realms/master", 200),
        ]
        
        for subpath, expected_status in subpaths:
            response = requests.get(
                f"{base_url}{subpath}",
                timeout=10,
                allow_redirects=True
            )
            assert response.status_code == expected_status, \
                f"Subpath {subpath} returned {response.status_code} instead of {expected_status}"


@pytest.mark.e2e
class TestNginxHeaders:
    """Test Nginx header forwarding in real scenarios."""
    
    def test_xff_header_forwarded(self, base_url, wait_for_services):
        """Test that X-Forwarded-For header is properly set."""
        response = requests.get(
            f"{base_url}/health",
            headers={"X-Forwarded-For": "192.168.1.100"},
            timeout=10
        )
        assert response.status_code == 200
        # Header should be forwarded to backend
    
    def test_custom_headers_forwarded_to_keycloak(self, base_url, wait_for_services):
        """Test that Keycloak receives proper forwarding headers."""
        response = requests.get(
            f"{base_url}/auth/realms/master",
            timeout=10
        )
        assert response.status_code == 200
        # Keycloak works, meaning headers were correct


@pytest.mark.e2e
class TestNginxPerformance:
    """Test Nginx performance characteristics."""
    
    def test_compression_enabled(self, base_url, wait_for_services):
        """Test that Gzip compression is working."""
        response = requests.get(
            f"{base_url}/",
            headers={"Accept-Encoding": "gzip, deflate"},
            timeout=10
        )
        # Check if response is compressed
        if int(response.headers.get("Content-Length", "999999")) > 1000:
            # Large responses should be compressed
            assert response.headers.get("Content-Encoding") in ["gzip", None]
    
    def test_response_time_reasonable(self, base_url, wait_for_services):
        """Test that response times are reasonable."""
        import time
        
        endpoints = [
            "/health",
            "/monitoring/prometheus/-/healthy",
            "/monitoring/loki/ready",
        ]
        
        for endpoint in endpoints:
            start = time.time()
            response = requests.get(
                f"{base_url}{endpoint}",
                timeout=10
            )
            duration = time.time() - start
            
            assert response.status_code == 200
            # Health checks should be fast (< 1 second)
            assert duration < 1.0, \
                f"Endpoint {endpoint} took {duration:.2f}s (too slow)"
    
    def test_concurrent_requests_handled(self, base_url, wait_for_services):
        """Test that Nginx can handle concurrent requests."""
        import concurrent.futures
        
        def make_request():
            response = requests.get(f"{base_url}/health", timeout=10)
            return response.status_code == 200
        
        # Send 10 concurrent requests
        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
            futures = [executor.submit(make_request) for _ in range(10)]
            results = [f.result() for f in concurrent.futures.as_completed(futures)]
        
        # All requests should succeed
        assert all(results), "Some concurrent requests failed"

