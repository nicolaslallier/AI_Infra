"""
Test Nginx DNS Resolution

Validates runtime DNS resolution configuration for Docker service discovery.
"""

import pytest
import re
from pathlib import Path


@pytest.mark.unit
@pytest.mark.docker
class TestNginxDNSResolution:
    """Test Nginx DNS resolution configuration."""
    
    @pytest.fixture
    def nginx_config_path(self):
        """Path to nginx configuration file."""
        return Path(__file__).parent.parent.parent.parent / "docker" / "nginx" / "nginx.conf"
    
    @pytest.fixture
    def nginx_config_content(self, nginx_config_path):
        """Load nginx configuration content."""
        with open(nginx_config_path, 'r') as f:
            return f.read()
    
    def test_dns_resolver_configured(self, nginx_config_content):
        """Test that DNS resolver is configured."""
        assert 'resolver' in nginx_config_content, \
            "DNS resolver not configured"
    
    def test_docker_dns_resolver_address(self, nginx_config_content):
        """Test that Docker's internal DNS (127.0.0.11) is used."""
        assert '127.0.0.11' in nginx_config_content, \
            "Docker DNS resolver (127.0.0.11) not configured"
    
    def test_dns_cache_ttl(self, nginx_config_content):
        """Test that DNS cache TTL is configured."""
        # Look for valid=Xs pattern
        ttl_pattern = r'valid=\d+s'
        assert re.search(ttl_pattern, nginx_config_content), \
            "DNS cache TTL not configured (missing 'valid=' parameter)"
    
    def test_ipv6_disabled(self, nginx_config_content):
        """Test that IPv6 is disabled for DNS resolution."""
        # IPv6 can cause issues in some Docker setups
        assert 'ipv6=off' in nginx_config_content, \
            "IPv6 should be disabled for DNS resolution"
    
    def test_variable_based_proxy_pass(self, nginx_config_content):
        """Test that proxy_pass uses variables for runtime DNS resolution."""
        # Variables force runtime DNS resolution instead of config-time
        variable_patterns = [
            r'\$frontend_upstream',
            r'\$grafana_upstream',
            r'\$prometheus_upstream',
            r'\$keycloak_upstream',
            r'\$pgadmin_upstream',
        ]
        
        for pattern in variable_patterns:
            assert re.search(pattern, nginx_config_content), \
                f"Missing variable for runtime DNS resolution: {pattern}"
    
    def test_upstream_variables_defined(self, nginx_config_content):
        """Test that upstream variables are defined with set directive."""
        # Each service should have a 'set $service_upstream' directive
        set_patterns = [
            r'set \$frontend_upstream',
            r'set \$grafana_upstream',
            r'set \$prometheus_upstream',
            r'set \$keycloak_upstream',
            r'set \$pgadmin_upstream',
        ]
        
        for pattern in set_patterns:
            assert re.search(pattern, nginx_config_content), \
                f"Missing upstream variable definition: {pattern}"
    
    def test_service_dns_names_used(self, nginx_config_content):
        """Test that Docker service names are used (not IPs)."""
        # Service names should be used, not IP addresses
        services = ['frontend', 'grafana', 'prometheus', 'keycloak', 'pgadmin', 'tempo', 'loki']
        
        for service in services:
            # Check that service name appears in http:// URLs
            pattern = f'http://{service}:'
            assert pattern in nginx_config_content, \
                f"Service DNS name not used for: {service}"
    
    def test_no_hardcoded_ips(self, nginx_config_content):
        """Test that no hardcoded IP addresses are used for upstreams."""
        # Look for private IP patterns in proxy_pass directives
        # This is a simplified check - adjust if legitimate IPs are found
        ip_pattern = r'proxy_pass\s+http://\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}'
        
        # Should not find hardcoded IPs in proxy_pass
        matches = re.findall(ip_pattern, nginx_config_content)
        assert len(matches) == 0, \
            f"Found hardcoded IP addresses in proxy_pass directives: {matches}"
    
    def test_resolver_in_http_block(self, nginx_config_content):
        """Test that resolver is in the http block for global scope."""
        # Simplified check: resolver should appear before any location blocks
        http_match = re.search(r'http\s*\{', nginx_config_content)
        resolver_match = re.search(r'resolver', nginx_config_content)
        first_location_match = re.search(r'location', nginx_config_content)
        
        assert http_match, "No http block found"
        assert resolver_match, "No resolver found"
        assert first_location_match, "No location blocks found"
        
        # Resolver should come after http block but before first location
        assert http_match.start() < resolver_match.start() < first_location_match.start(), \
            "Resolver should be in http block before location blocks"

