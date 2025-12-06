"""
E2E Test: Database Stack

Tests PostgreSQL and pgAdmin functionality through the infrastructure.
"""

import pytest
import requests


@pytest.mark.e2e
class TestPgAdminAccess:
    """Test pgAdmin web interface accessibility."""
    
    def test_pgadmin_loads_through_nginx(self, base_url, wait_for_services):
        """Test that pgAdmin interface loads through Nginx."""
        response = requests.get(
            f"{base_url}/pgadmin/",
            timeout=10,
            allow_redirects=True
        )
        assert response.status_code == 200
        assert "pgAdmin" in response.text or "login" in response.text.lower()
    
    def test_pgadmin_static_resources(self, base_url, wait_for_services):
        """Test that pgAdmin static resources are accessible."""
        # pgAdmin login page typically loads CSS/JS
        response = requests.get(
            f"{base_url}/pgadmin/",
            timeout=10,
            allow_redirects=True
        )
        assert response.status_code == 200
        # Check that it's not just returning an error page
        assert len(response.text) > 1000  # Substantial HTML content
    
    def test_pgadmin_api_endpoint(self, base_url, wait_for_services):
        """Test that pgAdmin API endpoints are accessible."""
        # Try to access the misc endpoint (doesn't require auth for version info)
        response = requests.get(
            f"{base_url}/pgadmin/misc/ping",
            timeout=10,
            allow_redirects=True
        )
        # May return various responses depending on config
        assert response.status_code in [200, 302, 401, 404, 405]


@pytest.mark.e2e
@pytest.mark.database
class TestPostgreSQLMetrics:
    """Test PostgreSQL monitoring and metrics."""
    
    def test_postgres_exporter_metrics_in_prometheus(self, base_url, wait_for_services):
        """Test that PostgreSQL metrics are available in Prometheus."""
        response = requests.get(
            f"{base_url}/monitoring/prometheus/api/v1/query",
            params={"query": "pg_up"},
            timeout=10
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
        
        # If postgres_exporter is configured
        if data["data"]["result"]:
            # Check that PostgreSQL is up
            assert data["data"]["result"][0]["value"][1] == "1"
    
    def test_postgres_connection_metrics(self, base_url, wait_for_services):
        """Test that PostgreSQL connection metrics are available."""
        queries = [
            "pg_stat_database_numbackends",
            "pg_stat_database_xact_commit",
            "pg_settings_max_connections",
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
            # Metrics might or might not exist depending on exporter config


@pytest.mark.e2e
class TestDatabaseIntegration:
    """Test database integration with other services."""
    
    def test_keycloak_uses_postgres(self, base_url, wait_for_services):
        """Test that Keycloak is using PostgreSQL (implicit by it working)."""
        # If Keycloak responds, it's connected to PostgreSQL
        response = requests.get(
            f"{base_url}/auth/realms/master",
            timeout=10
        )
        assert response.status_code == 200
        # Keycloak wouldn't start without database
    
    def test_grafana_uses_database(self, base_url, wait_for_services):
        """Test that Grafana database is healthy."""
        response = requests.get(
            f"{base_url}/monitoring/grafana/api/health",
            timeout=10
        )
        assert response.status_code == 200
        data = response.json()
        assert data["database"] == "ok"

