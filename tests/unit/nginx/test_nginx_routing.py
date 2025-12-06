"""
Test Nginx Routing Configuration

Validates URL routing rules and proxy configurations.
"""

import pytest
import re
from pathlib import Path


@pytest.mark.unit
class TestNginxRouting:
    """Test Nginx routing and proxy configuration."""
    
    @pytest.fixture
    def nginx_config_path(self):
        """Path to nginx configuration file."""
        return Path(__file__).parent.parent.parent.parent / "docker" / "nginx" / "nginx.conf"
    
    @pytest.fixture
    def nginx_config_content(self, nginx_config_path):
        """Load nginx configuration content."""
        with open(nginx_config_path, 'r') as f:
            return f.read()
    
    def test_frontend_routing(self, nginx_config_content):
        """Test that root path routes to frontend."""
        assert 'location /' in nginx_config_content, "Missing root location block"
        
        # Check for frontend upstream
        frontend_pattern = r'proxy_pass.*frontend'
        assert re.search(frontend_pattern, nginx_config_content), \
            "Frontend proxy_pass not configured"
    
    def test_grafana_routing(self, nginx_config_content):
        """Test Grafana routing configuration."""
        assert 'location /monitoring/grafana/' in nginx_config_content, \
            "Missing Grafana location block"
        
        # Check for grafana upstream
        grafana_pattern = r'proxy_pass.*grafana'
        assert re.search(grafana_pattern, nginx_config_content), \
            "Grafana proxy_pass not configured"
    
    def test_prometheus_routing(self, nginx_config_content):
        """Test Prometheus routing configuration."""
        assert 'location /monitoring/prometheus/' in nginx_config_content, \
            "Missing Prometheus location block"
        
        # Check for prometheus upstream
        prometheus_pattern = r'proxy_pass.*prometheus'
        assert re.search(prometheus_pattern, nginx_config_content), \
            "Prometheus proxy_pass not configured"
    
    def test_keycloak_routing(self, nginx_config_content):
        """Test Keycloak routing configuration."""
        assert 'location /auth/' in nginx_config_content, \
            "Missing Keycloak location block"
        
        # Check for keycloak upstream
        keycloak_pattern = r'proxy_pass.*keycloak'
        assert re.search(keycloak_pattern, nginx_config_content), \
            "Keycloak proxy_pass not configured"
    
    def test_pgadmin_routing(self, nginx_config_content):
        """Test pgAdmin routing configuration."""
        assert 'location /pgadmin' in nginx_config_content, \
            "Missing pgAdmin location block"
        
        # Check for pgadmin upstream
        pgadmin_pattern = r'proxy_pass.*pgadmin'
        assert re.search(pgadmin_pattern, nginx_config_content), \
            "pgAdmin proxy_pass not configured"
    
    def test_tempo_routing(self, nginx_config_content):
        """Test Tempo routing configuration."""
        assert 'location /monitoring/tempo/' in nginx_config_content, \
            "Missing Tempo location block"
        
        # Check for tempo upstream
        tempo_pattern = r'proxy_pass.*tempo'
        assert re.search(tempo_pattern, nginx_config_content), \
            "Tempo proxy_pass not configured"
    
    def test_loki_routing(self, nginx_config_content):
        """Test Loki routing configuration."""
        assert 'location /monitoring/loki/' in nginx_config_content, \
            "Missing Loki location block"
        
        # Check for loki upstream
        loki_pattern = r'proxy_pass.*loki'
        assert re.search(loki_pattern, nginx_config_content), \
            "Loki proxy_pass not configured"
    
    def test_health_check_endpoint(self, nginx_config_content):
        """Test health check endpoint configuration."""
        assert 'location /health' in nginx_config_content, \
            "Missing health check endpoint"
        
        assert 'return 200' in nginx_config_content, \
            "Health check not returning 200 OK"
    
    def test_backwards_compatibility_redirects(self, nginx_config_content):
        """Test that backwards compatibility redirects are configured."""
        redirects = [
            'location = /grafana',
            'location = /prometheus',
            'location = /keycloak',
        ]
        
        for redirect in redirects:
            assert redirect in nginx_config_content, \
                f"Missing backwards compatibility redirect: {redirect}"
    
    def test_websocket_support(self, nginx_config_content):
        """Test WebSocket upgrade configuration."""
        assert 'Upgrade $http_upgrade' in nginx_config_content, \
            "Missing WebSocket Upgrade header"
        assert '$connection_upgrade' in nginx_config_content, \
            "Missing WebSocket connection upgrade mapping"
    
    def test_proxy_headers_set(self, nginx_config_content):
        """Test that required proxy headers are set for all routes."""
        required_headers = [
            'proxy_set_header Host',
            'proxy_set_header X-Real-IP',
            'proxy_set_header X-Forwarded-For',
            'proxy_set_header X-Forwarded-Proto',
        ]
        
        for header in required_headers:
            assert header in nginx_config_content, \
                f"Missing required proxy header: {header}"
    
    def test_timeout_configuration(self, nginx_config_content):
        """Test that timeouts are configured for proxied services."""
        timeout_settings = [
            'proxy_connect_timeout',
            'proxy_send_timeout',
            'proxy_read_timeout',
        ]
        
        for setting in timeout_settings:
            assert setting in nginx_config_content, \
                f"Missing timeout setting: {setting}"
    
    def test_client_max_body_size(self, nginx_config_content):
        """Test that client_max_body_size is configured."""
        assert 'client_max_body_size' in nginx_config_content, \
            "Missing client_max_body_size configuration"

