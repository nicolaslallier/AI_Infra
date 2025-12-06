"""
Test Nginx Health Check Endpoint

Validates the health check endpoint configuration and functionality.
"""

import pytest
import re
from pathlib import Path


@pytest.mark.unit
class TestNginxHealthEndpoint:
    """Test Nginx health check endpoint."""
    
    @pytest.fixture
    def nginx_config_path(self):
        """Path to nginx configuration file."""
        return Path(__file__).parent.parent.parent.parent / "docker" / "nginx" / "nginx.conf"
    
    @pytest.fixture
    def nginx_config_content(self, nginx_config_path):
        """Load nginx configuration content."""
        with open(nginx_config_path, 'r') as f:
            return f.read()
    
    def test_health_endpoint_exists(self, nginx_config_content):
        """Test that /health endpoint is configured."""
        assert 'location /health' in nginx_config_content, \
            "Health check endpoint (/health) not configured"
    
    def test_health_endpoint_returns_200(self, nginx_config_content):
        """Test that health endpoint returns 200 OK."""
        health_match = re.search(r'location /health.*?\}', nginx_config_content, re.DOTALL)
        
        assert health_match, "Health endpoint location block not found"
        health_block = health_match.group()
        assert 'return 200' in health_block, \
            "Health endpoint should return 200 OK"
    
    def test_health_endpoint_response_body(self, nginx_config_content):
        """Test that health endpoint returns appropriate response body."""
        health_match = re.search(r'location /health.*?\}', nginx_config_content, re.DOTALL)
        
        if health_match:
            health_block = health_match.group()
            # Should have a simple response body
            assert 'OK' in health_block or 'healthy' in health_block.lower(), \
                "Health endpoint should return status message"
    
    def test_health_endpoint_content_type(self, nginx_config_content):
        """Test that health endpoint sets appropriate content type."""
        health_match = re.search(r'location /health.*?\}', nginx_config_content, re.DOTALL)
        
        if health_match:
            health_block = health_match.group()
            # Should set Content-Type header
            assert 'add_header Content-Type' in health_block or \
                   'default_type' in health_block, \
                   "Health endpoint should set Content-Type header"
    
    def test_health_endpoint_no_logging(self, nginx_config_content):
        """Test that health endpoint has logging disabled or reduced."""
        health_match = re.search(r'location /health.*?\}', nginx_config_content, re.DOTALL)
        
        if health_match:
            health_block = health_match.group()
            # Health checks can generate a lot of logs
            # Should have access_log off or be configured to reduce noise
            if 'access_log' in health_block:
                assert 'access_log off' in health_block, \
                    "Consider disabling access_log for health endpoint to reduce log noise"
    
    def test_health_endpoint_simple_implementation(self, nginx_config_content):
        """Test that health endpoint doesn't depend on backends."""
        health_match = re.search(r'location /health.*?\}', nginx_config_content, re.DOTALL)
        
        if health_match:
            health_block = health_match.group()
            # Should not proxy to backends (avoids false negatives if backend is down)
            assert 'proxy_pass' not in health_block, \
                "Health endpoint should not depend on backend services"
            assert 'fastcgi_pass' not in health_block, \
                "Health endpoint should not depend on FastCGI backends"
    
    def test_health_endpoint_location_exact_match(self, nginx_config_content):
        """Test that health endpoint uses exact match for security."""
        # Using 'location = /health' is more secure than 'location /health'
        # as it prevents matching /health/something
        assert 'location /health' in nginx_config_content or \
               'location = /health' in nginx_config_content, \
               "Health endpoint should be configured"
        
        # Exact match is preferred
        if 'location = /health' not in nginx_config_content:
            pytest.skip("Health endpoint uses prefix match instead of exact match (consider using 'location =' for security)")
    
    def test_health_endpoint_no_authentication(self, nginx_config_content):
        """Test that health endpoint doesn't require authentication."""
        health_match = re.search(r'location /health.*?\}', nginx_config_content, re.DOTALL)
        
        if health_match:
            health_block = health_match.group()
            # Should not require auth (needed for monitoring systems)
            assert 'auth_basic' not in health_block, \
                "Health endpoint should not require authentication"
            assert 'auth_request' not in health_block, \
                "Health endpoint should not require authentication"
    
    def test_health_endpoint_fast_response(self, nginx_config_content):
        """Test that health endpoint is optimized for fast response."""
        health_match = re.search(r'location /health.*?\}', nginx_config_content, re.DOTALL)
        
        if health_match:
            health_block = health_match.group()
            # Should be a simple return statement (fastest)
            assert 'return' in health_block, \
                "Health endpoint should use 'return' directive for fast response"
    
    def test_no_other_health_endpoints(self, nginx_config_content):
        """Test that there aren't conflicting health endpoints."""
        # Check for common variations
        health_variations = [
            r'location.*/healthcheck',
            r'location.*/health-check',
            r'location.*/healthz',
            r'location.*/ready',
            r'location.*/alive',
        ]
        
        for pattern in health_variations:
            if re.search(pattern, nginx_config_content):
                pytest.skip(f"Found additional health endpoint: {pattern}. Ensure consistency.")

