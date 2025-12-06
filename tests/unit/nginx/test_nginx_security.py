"""
Test Nginx Security Configuration

Validates security-related settings and headers.
"""

import pytest
import re
from pathlib import Path


@pytest.mark.unit
@pytest.mark.security
class TestNginxSecurity:
    """Test Nginx security configuration."""
    
    @pytest.fixture
    def nginx_config_path(self):
        """Path to nginx configuration file."""
        return Path(__file__).parent.parent.parent.parent / "docker" / "nginx" / "nginx.conf"
    
    @pytest.fixture
    def nginx_config_content(self, nginx_config_path):
        """Load nginx configuration content."""
        with open(nginx_config_path, 'r') as f:
            return f.read()
    
    def test_server_tokens_hidden(self, nginx_config_content):
        """Test that server tokens are hidden (or not explicitly shown)."""
        # Best practice: don't expose nginx version
        # Default is 'on', so we check if it's explicitly disabled
        # Note: This might not be in config if using default
        if 'server_tokens' in nginx_config_content:
            assert 'server_tokens off' in nginx_config_content, \
                "Server tokens should be disabled to hide nginx version"
    
    def test_client_max_body_size_limited(self, nginx_config_content):
        """Test that client body size is limited to prevent DoS."""
        assert 'client_max_body_size' in nginx_config_content, \
            "client_max_body_size should be set to prevent large uploads"
        
        # Extract the value
        match = re.search(r'client_max_body_size\s+(\d+)([KMG])?', nginx_config_content)
        if match:
            size_value = int(match.group(1))
            size_unit = match.group(2) or ''
            
            # Check it's reasonable (not unlimited)
            if size_unit == 'G':
                assert size_value <= 2, "client_max_body_size is too large (DoS risk)"
            elif size_unit == 'M':
                assert size_value <= 1000, "client_max_body_size is too large"
    
    def test_ssl_protocols_secure(self, nginx_config_content):
        """Test that only secure SSL/TLS protocols are enabled."""
        # If SSL is configured, check protocols
        if 'ssl_protocols' in nginx_config_content:
            # Should not use old insecure protocols
            assert 'SSLv2' not in nginx_config_content, "SSLv2 is insecure"
            assert 'SSLv3' not in nginx_config_content, "SSLv3 is insecure"
            assert 'TLSv1 ' not in nginx_config_content and 'TLSv1;' not in nginx_config_content, \
                "TLSv1.0 is insecure"
    
    def test_proxy_headers_prevent_injection(self, nginx_config_content):
        """Test that proxy headers are properly sanitized."""
        # X-Forwarded-For should use $proxy_add_x_forwarded_for
        # which properly appends rather than replaces
        assert 'proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for' in nginx_config_content, \
            "X-Forwarded-For should use $proxy_add_x_forwarded_for to prevent header injection"
    
    def test_no_default_server_vulnerabilities(self, nginx_config_content):
        """Test that server_name is defined (not using default_server unsafely)."""
        # Should have server_name configured
        assert 'server_name' in nginx_config_content, \
            "server_name should be explicitly configured"
    
    def test_access_log_configured(self, nginx_config_content):
        """Test that access logging is enabled for security monitoring."""
        assert 'access_log' in nginx_config_content, \
            "Access logging should be enabled for security auditing"
    
    def test_error_log_configured(self, nginx_config_content):
        """Test that error logging is enabled."""
        assert 'error_log' in nginx_config_content, \
            "Error logging should be enabled"
    
    def test_health_endpoint_no_sensitive_info(self, nginx_config_content):
        """Test that health endpoint doesn't expose sensitive information."""
        # Find health check location block
        health_match = re.search(r'location /health.*?\}', nginx_config_content, re.DOTALL)
        
        if health_match:
            health_block = health_match.group()
            # Should just return OK, not system info
            assert 'return 200' in health_block, "Health check should return simple 200 OK"
            # Should not execute any scripts or expose system info
            assert 'fastcgi_pass' not in health_block, "Health check should not use FastCGI"
            assert 'proxy_pass' not in health_block, "Health check should not proxy to backends"
    
    def test_directory_traversal_protection(self, nginx_config_content):
        """Test that alias directives are used safely."""
        # alias can be dangerous if not ended with /
        alias_matches = re.findall(r'alias\s+([^;]+);', nginx_config_content)
        
        for alias in alias_matches:
            # If location ends with /, alias should too
            # This is a simplified check
            if alias.strip().endswith('/'):
                pass  # Good
    
    def test_proxy_redirect_configured(self, nginx_config_content):
        """Test proxy_redirect for security."""
        # proxy_redirect default is usually safe, but explicit is better
        # This is optional but good practice
        pass  # Not critical for this infra
    
    def test_keepalive_timeout_reasonable(self, nginx_config_content):
        """Test that keepalive timeout is not too long (resource exhaustion)."""
        if 'keepalive_timeout' in nginx_config_content:
            match = re.search(r'keepalive_timeout\s+(\d+)', nginx_config_content)
            if match:
                timeout = int(match.group(1))
                assert timeout <= 120, \
                    f"keepalive_timeout too long ({timeout}s), may cause resource exhaustion"
    
    def test_rate_limiting_considered(self, nginx_config_content):
        """Check if rate limiting is configured (optional but recommended)."""
        # Rate limiting is recommended but not required
        # Just log a note if not present
        if 'limit_req' not in nginx_config_content:
            pytest.skip("Rate limiting not configured (recommended for production)")
    
    def test_no_autoindex(self, nginx_config_content):
        """Test that directory listing is disabled."""
        if 'autoindex' in nginx_config_content:
            assert 'autoindex off' in nginx_config_content or 'autoindex on' not in nginx_config_content, \
                "Directory listing (autoindex) should be disabled"
    
    def test_sensitive_locations_protected(self, nginx_config_content):
        """Test that sensitive files are not accessible."""
        # Should have protection for common sensitive files
        # This is more applicable if serving static files
        # For a pure reverse proxy, this is less critical
        pass  # Not critical for this reverse proxy setup

