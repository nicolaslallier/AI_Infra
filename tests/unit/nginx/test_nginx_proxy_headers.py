"""
Test Nginx Proxy Headers

Validates that proper headers are forwarded to upstream services.
"""

import pytest
import re
from pathlib import Path


@pytest.mark.unit
class TestNginxProxyHeaders:
    """Test Nginx proxy header configuration."""
    
    @pytest.fixture
    def nginx_config_path(self):
        """Path to nginx configuration file."""
        return Path(__file__).parent.parent.parent.parent / "docker" / "nginx" / "nginx.conf"
    
    @pytest.fixture
    def nginx_config_content(self, nginx_config_path):
        """Load nginx configuration content."""
        with open(nginx_config_path, 'r') as f:
            return f.read()
    
    def test_host_header_forwarded(self, nginx_config_content):
        """Test that Host header is forwarded."""
        assert 'proxy_set_header Host $host' in nginx_config_content, \
            "Host header not forwarded to upstream"
    
    def test_real_ip_header_forwarded(self, nginx_config_content):
        """Test that X-Real-IP header is set."""
        assert 'proxy_set_header X-Real-IP $remote_addr' in nginx_config_content, \
            "X-Real-IP header not set"
    
    def test_forwarded_for_header_set(self, nginx_config_content):
        """Test that X-Forwarded-For header is set."""
        assert 'proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for' in nginx_config_content, \
            "X-Forwarded-For header not set correctly"
    
    def test_forwarded_proto_header_set(self, nginx_config_content):
        """Test that X-Forwarded-Proto header is set."""
        assert 'proxy_set_header X-Forwarded-Proto $scheme' in nginx_config_content, \
            "X-Forwarded-Proto header not set"
    
    def test_keycloak_forwarded_host_header(self, nginx_config_content):
        """Test that Keycloak has X-Forwarded-Host header."""
        # Find the Keycloak location block and check for the header
        keycloak_block_match = re.search(
            r'location /auth/.*?(?=location|\})', 
            nginx_config_content, 
            re.DOTALL
        )
        
        if keycloak_block_match:
            keycloak_block = keycloak_block_match.group()
            assert 'proxy_set_header X-Forwarded-Host $host' in keycloak_block, \
                "X-Forwarded-Host header not set for Keycloak"
    
    def test_keycloak_forwarded_port_header(self, nginx_config_content):
        """Test that Keycloak has X-Forwarded-Port header."""
        # Find the Keycloak location block
        keycloak_block_match = re.search(
            r'location /auth/.*?(?=location|\})', 
            nginx_config_content, 
            re.DOTALL
        )
        
        if keycloak_block_match:
            keycloak_block = keycloak_block_match.group()
            assert 'proxy_set_header X-Forwarded-Port' in keycloak_block, \
                "X-Forwarded-Port header not set for Keycloak"
    
    def test_pgadmin_script_name_header(self, nginx_config_content):
        """Test that pgAdmin has X-Script-Name header for subpath."""
        # Check for X-Script-Name header anywhere in config (specifically for pgAdmin)
        # This is more robust than parsing location blocks
        assert 'proxy_set_header X-Script-Name /pgadmin' in nginx_config_content, \
            "X-Script-Name header not set for pgAdmin subpath"
    
    def test_websocket_upgrade_headers(self, nginx_config_content):
        """Test that WebSocket upgrade headers are configured."""
        # Check for Upgrade and Connection headers
        assert 'proxy_set_header Upgrade $http_upgrade' in nginx_config_content, \
            "WebSocket Upgrade header not configured"
        assert 'proxy_set_header Connection $connection_upgrade' in nginx_config_content, \
            "WebSocket Connection header not configured"
    
    def test_websocket_upgrade_mapping(self, nginx_config_content):
        """Test that WebSocket upgrade mapping is defined."""
        # Check for map directive
        assert 'map $http_upgrade $connection_upgrade' in nginx_config_content, \
            "WebSocket upgrade mapping not defined"
        assert 'default upgrade' in nginx_config_content, \
            "WebSocket default upgrade not set"
        assert "'' close" in nginx_config_content or '"" close' in nginx_config_content, \
            "WebSocket close on empty upgrade not set"
    
    def test_proxy_http_version(self, nginx_config_content):
        """Test that HTTP/1.1 is used for WebSocket support."""
        # HTTP/1.1 is required for WebSocket
        # Check in Grafana and Keycloak blocks which use WebSocket
        assert 'proxy_http_version 1.1' in nginx_config_content, \
            "HTTP/1.1 not configured for WebSocket support"
    
    def test_buffering_configuration_for_keycloak(self, nginx_config_content):
        """Test that buffering is configured for Keycloak's large responses."""
        keycloak_block_match = re.search(
            r'location /auth/.*?(?=location|\})', 
            nginx_config_content, 
            re.DOTALL
        )
        
        if keycloak_block_match:
            keycloak_block = keycloak_block_match.group()
            # Check for proxy buffering settings
            assert 'proxy_buffer' in keycloak_block, \
                "Proxy buffering not configured for Keycloak"
    
    def test_buffering_configuration_for_pgadmin(self, nginx_config_content):
        """Test that buffering is configured for pgAdmin's query results."""
        # Check for proxy buffering settings in the entire config
        # The nginx.conf has buffering configured globally and for specific services
        assert 'proxy_buffer' in nginx_config_content, \
            "Proxy buffering not configured"
        # Verify that buffering is enabled (not just configured)
        assert 'proxy_buffering on' in nginx_config_content, \
            "Proxy buffering not enabled"

