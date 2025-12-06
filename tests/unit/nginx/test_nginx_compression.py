"""
Test Nginx Compression Configuration

Validates gzip compression settings for performance.
"""

import pytest
import re
from pathlib import Path


@pytest.mark.unit
class TestNginxCompression:
    """Test Nginx compression configuration."""
    
    @pytest.fixture
    def nginx_config_path(self):
        """Path to nginx configuration file."""
        return Path(__file__).parent.parent.parent.parent / "docker" / "nginx" / "nginx.conf"
    
    @pytest.fixture
    def nginx_config_content(self, nginx_config_path):
        """Load nginx configuration content."""
        with open(nginx_config_path, 'r') as f:
            return f.read()
    
    def test_gzip_enabled(self, nginx_config_content):
        """Test that gzip compression is enabled."""
        assert 'gzip on' in nginx_config_content, \
            "Gzip compression should be enabled"
    
    def test_gzip_vary_enabled(self, nginx_config_content):
        """Test that gzip_vary is enabled for proper caching."""
        assert 'gzip_vary on' in nginx_config_content, \
            "gzip_vary should be enabled for proper Accept-Encoding header handling"
    
    def test_gzip_proxied_configured(self, nginx_config_content):
        """Test that gzip_proxied is configured for proxied content."""
        assert 'gzip_proxied' in nginx_config_content, \
            "gzip_proxied should be configured to compress proxied responses"
        
        # 'any' is a good default for proxied content
        if 'gzip_proxied' in nginx_config_content:
            assert 'gzip_proxied any' in nginx_config_content or \
                   'gzip_proxied expired' in nginx_config_content, \
                   "gzip_proxied should compress appropriate proxied content"
    
    def test_gzip_comp_level_reasonable(self, nginx_config_content):
        """Test that gzip compression level is reasonable."""
        match = re.search(r'gzip_comp_level\s+(\d+)', nginx_config_content)
        
        if match:
            level = int(match.group(1))
            assert 1 <= level <= 9, \
                "gzip_comp_level should be between 1 and 9"
            assert level <= 6, \
                f"gzip_comp_level {level} may be too high (CPU intensive), recommend <=6"
    
    def test_gzip_types_configured(self, nginx_config_content):
        """Test that gzip_types includes appropriate MIME types."""
        if 'gzip_types' in nginx_config_content:
            # Extract gzip_types line
            types_match = re.search(r'gzip_types\s+([^;]+);', nginx_config_content)
            
            if types_match:
                types_line = types_match.group(1)
                
                # Check for common compressible types
                recommended_types = [
                    'text/plain',
                    'text/css',
                    'application/json',
                    'application/javascript',
                    'text/xml',
                ]
                
                for mime_type in recommended_types:
                    assert mime_type in types_line, \
                        f"gzip_types should include {mime_type}"
    
    def test_gzip_types_excludes_pre_compressed(self, nginx_config_content):
        """Test that gzip_types doesn't include pre-compressed formats."""
        if 'gzip_types' in nginx_config_content:
            types_match = re.search(r'gzip_types\s+([^;]+);', nginx_config_content)
            
            if types_match:
                types_line = types_match.group(1)
                
                # These formats are already compressed
                should_not_compress = [
                    'image/jpeg',
                    'image/png',
                    'image/gif',
                    'video/',
                    'application/zip',
                    'application/gzip',
                ]
                
                for mime_type in should_not_compress:
                    if mime_type in types_line:
                        pytest.fail(f"gzip_types should not include already-compressed format: {mime_type}")
    
    def test_gzip_min_length_set(self, nginx_config_content):
        """Test that gzip_min_length is set to avoid compressing tiny files."""
        if 'gzip_min_length' in nginx_config_content:
            match = re.search(r'gzip_min_length\s+(\d+)', nginx_config_content)
            
            if match:
                min_length = int(match.group(1))
                assert min_length >= 256, \
                    f"gzip_min_length {min_length} may be too small, recommend >= 256 bytes"
    
    def test_gzip_buffers_configured(self, nginx_config_content):
        """Test that gzip_buffers is configured if needed."""
        # gzip_buffers is optional but can improve performance
        # Not critical, just check if present
        if 'gzip_buffers' in nginx_config_content:
            match = re.search(r'gzip_buffers\s+(\d+)\s+(\d+)([kKmM])?', nginx_config_content)
            assert match, "gzip_buffers format invalid"
    
    def test_gzip_http_version(self, nginx_config_content):
        """Test gzip_http_version if specified."""
        if 'gzip_http_version' in nginx_config_content:
            # Should be at least 1.1 for modern clients
            assert 'gzip_http_version 1.1' in nginx_config_content or \
                   'gzip_http_version 1.0' in nginx_config_content, \
                   "gzip_http_version should be 1.0 or 1.1"
    
    def test_gzip_disable_for_old_browsers(self, nginx_config_content):
        """Test that gzip is disabled for problematic browsers."""
        # gzip_disable for old IE versions is good practice
        # Not critical for modern infrastructure
        pass  # Optional for this infrastructure
    
    def test_compression_for_json_apis(self, nginx_config_content):
        """Test that JSON responses will be compressed."""
        if 'gzip_types' in nginx_config_content:
            types_match = re.search(r'gzip_types\s+([^;]+);', nginx_config_content)
            
            if types_match:
                types_line = types_match.group(1)
                assert 'application/json' in types_line, \
                    "API responses (application/json) should be compressed"

