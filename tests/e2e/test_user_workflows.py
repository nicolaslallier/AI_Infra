"""
E2E Test: User Workflows

Tests complete user scenarios across the infrastructure.
"""

import pytest
import requests
import time


@pytest.mark.e2e
@pytest.mark.critical
class TestBasicUserWorkflow:
    """Test basic user interaction workflows."""
    
    def test_user_accesses_frontend(self, base_url, wait_for_services):
        """Test that a user can access the frontend application."""
        response = requests.get(base_url, timeout=10)
        assert response.status_code == 200
        assert "<!DOCTYPE html>" in response.text
        # Frontend should load
        assert len(response.text) > 500
    
    def test_user_views_monitoring_dashboards(self, base_url, wait_for_services):
        """Test that a user can access monitoring dashboards."""
        # Access Grafana
        response = requests.get(
            f"{base_url}/monitoring/grafana/",
            timeout=10,
            allow_redirects=True
        )
        assert response.status_code == 200
        assert "Grafana" in response.text
    
    def test_user_checks_system_health(self, base_url, wait_for_services):
        """Test that a user can check system health."""
        response = requests.get(f"{base_url}/health", timeout=10)
        assert response.status_code == 200
        assert "OK" in response.text


@pytest.mark.e2e
class TestAdminWorkflow:
    """Test administrator workflows."""
    
    def test_admin_accesses_database_management(self, base_url, wait_for_services):
        """Test that admin can access database management (pgAdmin)."""
        response = requests.get(
            f"{base_url}/pgadmin/",
            timeout=10,
            allow_redirects=True
        )
        assert response.status_code == 200
        assert "pgAdmin" in response.text or "login" in response.text.lower()
    
    def test_admin_accesses_auth_management(self, base_url, wait_for_services):
        """Test that admin can access authentication management (Keycloak)."""
        response = requests.get(
            f"{base_url}/auth/",
            timeout=10,
            allow_redirects=True
        )
        assert response.status_code == 200
    
    def test_admin_views_metrics(self, base_url, wait_for_services):
        """Test that admin can view system metrics."""
        # Query Prometheus for system metrics
        response = requests.get(
            f"{base_url}/monitoring/prometheus/api/v1/query",
            params={"query": "up"},
            timeout=10
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
        assert len(data["data"]["result"]) > 0
    
    def test_admin_views_logs(self, base_url, wait_for_services):
        """Test that admin can access log aggregation."""
        response = requests.get(
            f"{base_url}/monitoring/loki/ready",
            timeout=10
        )
        assert response.status_code == 200


@pytest.mark.e2e
class TestDevOpsWorkflow:
    """Test DevOps engineer workflows."""
    
    def test_devops_monitors_service_health(self, base_url, wait_for_services):
        """Test DevOps can monitor all services."""
        services = {
            "Nginx": f"{base_url}/health",
            "Prometheus": f"{base_url}/monitoring/prometheus/-/healthy",
            "Grafana": f"{base_url}/monitoring/grafana/api/health",
            "Loki": f"{base_url}/monitoring/loki/ready",
            "Tempo": f"{base_url}/monitoring/tempo/ready",
        }
        
        for service_name, health_url in services.items():
            response = requests.get(health_url, timeout=10)
            assert response.status_code in [200, 204], \
                f"{service_name} health check failed"
    
    def test_devops_queries_prometheus_targets(self, base_url, wait_for_services):
        """Test DevOps can check Prometheus scrape targets."""
        response = requests.get(
            f"{base_url}/monitoring/prometheus/api/v1/targets",
            timeout=10
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
        assert len(data["data"]["activeTargets"]) > 0
    
    def test_devops_queries_service_uptime(self, base_url, wait_for_services):
        """Test DevOps can query service uptime metrics."""
        response = requests.get(
            f"{base_url}/monitoring/prometheus/api/v1/query",
            params={"query": "process_start_time_seconds"},
            timeout=10
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"


@pytest.mark.e2e
@pytest.mark.slow
class TestHighAvailabilityScenarios:
    """Test high availability and resilience scenarios."""
    
    def test_multiple_concurrent_users(self, base_url, wait_for_services):
        """Test system handles multiple concurrent users."""
        import concurrent.futures
        
        def user_session():
            """Simulate a user session."""
            try:
                # Access frontend
                r1 = requests.get(base_url, timeout=10)
                # Check health
                r2 = requests.get(f"{base_url}/health", timeout=10)
                # View monitoring
                r3 = requests.get(f"{base_url}/monitoring/grafana/", timeout=10, allow_redirects=True)
                
                return all(r.status_code == 200 for r in [r1, r2, r3])
            except Exception:
                return False
        
        # Simulate 5 concurrent users
        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
            futures = [executor.submit(user_session) for _ in range(5)]
            results = [f.result() for f in concurrent.futures.as_completed(futures)]
        
        # All user sessions should succeed
        assert all(results), "Some user sessions failed under concurrent load"
    
    def test_service_response_under_load(self, base_url, wait_for_services):
        """Test that services respond quickly under load."""
        response_times = []
        
        for _ in range(10):
            start = time.time()
            response = requests.get(f"{base_url}/health", timeout=10)
            duration = time.time() - start
            
            assert response.status_code == 200
            response_times.append(duration)
        
        # Average response time should be reasonable
        avg_response_time = sum(response_times) / len(response_times)
        assert avg_response_time < 0.5, \
            f"Average response time {avg_response_time:.2f}s too slow"
        
        # No single request should be extremely slow
        assert max(response_times) < 2.0, \
            f"Slowest request took {max(response_times):.2f}s"


@pytest.mark.e2e
class TestErrorHandling:
    """Test error handling across the stack."""
    
    def test_404_for_nonexistent_routes(self, base_url, wait_for_services):
        """Test that nonexistent routes return appropriate errors."""
        response = requests.get(
            f"{base_url}/nonexistent-route-12345",
            timeout=10,
            allow_redirects=True
        )
        # Frontend SPA might serve index.html for all routes
        assert response.status_code in [200, 404]
    
    def test_invalid_api_requests_handled(self, base_url, wait_for_services):
        """Test that invalid API requests are handled gracefully."""
        # Try invalid Prometheus query
        response = requests.get(
            f"{base_url}/monitoring/prometheus/api/v1/query",
            params={"query": "invalid{{{query"},
            timeout=10
        )
        assert response.status_code in [200, 400, 422]
        # Should return error, not crash
    
    def test_service_handles_malformed_requests(self, base_url, wait_for_services):
        """Test that services handle malformed requests gracefully."""
        # Try to POST to a GET-only endpoint
        response = requests.post(
            f"{base_url}/health",
            data={"invalid": "data"},
            timeout=10
        )
        # Should return error, not crash
        assert response.status_code in [200, 405, 400]

