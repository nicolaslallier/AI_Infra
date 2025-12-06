"""
Test Nginx Configuration Syntax

Validates that nginx.conf has correct syntax and can be loaded.
"""

import pytest
import subprocess
from pathlib import Path


@pytest.mark.unit
class TestNginxConfigSyntax:
    """Test Nginx configuration file syntax."""
    
    @pytest.fixture
    def nginx_config_path(self):
        """Path to nginx configuration file."""
        return Path(__file__).parent.parent.parent.parent / "docker" / "nginx" / "nginx.conf"
    
    def test_nginx_config_file_exists(self, nginx_config_path):
        """Test that nginx.conf file exists."""
        assert nginx_config_path.exists(), f"Nginx config not found at {nginx_config_path}"
        assert nginx_config_path.is_file(), "Nginx config path is not a file"
    
    def test_nginx_config_is_readable(self, nginx_config_path):
        """Test that nginx.conf is readable."""
        assert nginx_config_path.stat().st_size > 0, "Nginx config file is empty"
        
        with open(nginx_config_path, 'r') as f:
            content = f.read()
            assert len(content) > 100, "Nginx config seems too short"
    
    def test_nginx_config_has_required_blocks(self, nginx_config_path):
        """Test that nginx.conf has required configuration blocks."""
        with open(nginx_config_path, 'r') as f:
            content = f.read()
        
        required_blocks = ['events', 'http', 'server']
        for block in required_blocks:
            assert f'{block} {{' in content or f'{block}{{' in content, \
                f"Missing required block: {block}"
    
    @pytest.mark.skip(reason="Nginx config references Docker services that aren't available during isolated testing. Use integration tests instead.")
    def test_nginx_config_syntax_with_docker(self, nginx_config_path):
        """Test nginx configuration syntax using nginx -t command via docker.
        
        Note: This test is skipped because our nginx.conf uses dynamic DNS resolution
        for Docker service names (grafana, tempo, loki, etc.) which won't resolve
        outside of the Docker Compose network. The config is validated during:
        1. Docker Compose startup (docker-compose up validates configs)
        2. Integration tests (tests with full stack running)
        3. Static analysis tests (this file's other tests)
        """
        pytest.skip("Config validation requires full Docker Compose environment")
    
    def test_nginx_config_has_resolver(self, nginx_config_path):
        """Test that nginx.conf has DNS resolver configured."""
        with open(nginx_config_path, 'r') as f:
            content = f.read()
        
        assert 'resolver' in content, "Missing DNS resolver configuration"
        assert '127.0.0.11' in content, "Missing Docker DNS resolver (127.0.0.11)"
    
    def test_nginx_config_has_gzip_enabled(self, nginx_config_path):
        """Test that gzip compression is configured."""
        with open(nginx_config_path, 'r') as f:
            content = f.read()
        
        assert 'gzip on' in content, "Gzip compression not enabled"
    
    def test_nginx_config_has_logging(self, nginx_config_path):
        """Test that logging is configured."""
        with open(nginx_config_path, 'r') as f:
            content = f.read()
        
        assert 'access_log' in content, "Access log not configured"
        assert 'error_log' in content, "Error log not configured"
    
    def test_nginx_config_has_security_headers(self, nginx_config_path):
        """Test that security-related configurations are present."""
        with open(nginx_config_path, 'r') as f:
            content = f.read()
        
        # Check for common security settings
        security_indicators = [
            'proxy_set_header',
            'X-Real-IP',
            'X-Forwarded-For',
            'X-Forwarded-Proto'
        ]
        
        for indicator in security_indicators:
            assert indicator in content, f"Missing security configuration: {indicator}"
    
    def test_nginx_config_has_timeout_settings(self, nginx_config_path):
        """Test that appropriate timeout settings are configured."""
        with open(nginx_config_path, 'r') as f:
            content = f.read()
        
        assert 'keepalive_timeout' in content, "Missing keepalive timeout"
    
    def test_nginx_config_listen_port(self, nginx_config_path):
        """Test that nginx listens on port 80."""
        with open(nginx_config_path, 'r') as f:
            content = f.read()
        
        assert 'listen 80' in content, "Nginx not configured to listen on port 80"

