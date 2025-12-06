"""
Test suite for Grafana redirect loop prevention.

This test ensures that accessing Grafana through the nginx reverse proxy
does not result in an infinite redirect loop.

The redirect loop was caused by:
1. Nginx passing the full path (/monitoring/grafana/*) to Grafana
2. Grafana generating redirect URLs that included the subpath again
3. Creating an infinite loop: /monitoring/grafana/ → /grafana/ → /monitoring/grafana/ → ...

The fix:
- Nginx strips /monitoring/grafana/ prefix before proxying to Grafana
- Grafana uses ROOT_URL to generate correct external redirect URLs
"""

import pytest
import requests
from typing import List, Tuple

# Configuration
BASE_URL = "http://localhost"
GRAFANA_PATH = "/monitoring/grafana/"
MAX_REDIRECTS = 10  # Reasonable limit - should reach destination in 2-3 redirects


class TestGrafanaRedirect:
    """Test suite for Grafana redirect behavior."""

    def test_no_redirect_loop(self):
        """
        Test that accessing Grafana does not result in a redirect loop.
        
        A redirect loop is detected when:
        - The same URL is visited twice in the redirect chain
        - More than MAX_REDIRECTS redirects occur
        """
        url = f"{BASE_URL}{GRAFANA_PATH}"
        visited_urls: List[str] = []
        redirect_count = 0
        
        session = requests.Session()
        
        # Manually follow redirects to track the chain
        while redirect_count < MAX_REDIRECTS:
            response = session.get(url, allow_redirects=False, timeout=10)
            visited_urls.append(url)
            
            # Check for redirect loop (same URL visited twice)
            if visited_urls.count(url) > 1:
                pytest.fail(
                    f"Redirect loop detected! URL '{url}' visited twice.\n"
                    f"Redirect chain: {' → '.join(visited_urls)}"
                )
            
            # If not a redirect, we've reached the destination
            if response.status_code not in (301, 302, 303, 307, 308):
                break
            
            # Follow the redirect
            location = response.headers.get("Location", "")
            if not location:
                pytest.fail(f"Redirect response {response.status_code} missing Location header")
            
            # Handle relative URLs
            if location.startswith("/"):
                url = f"{BASE_URL}{location}"
            elif not location.startswith("http"):
                url = f"{BASE_URL}/{location}"
            else:
                url = location
            
            redirect_count += 1
        else:
            pytest.fail(
                f"Too many redirects ({MAX_REDIRECTS})! Possible redirect loop.\n"
                f"Redirect chain: {' → '.join(visited_urls)}"
            )
        
        # Verify we reached a successful response
        assert response.status_code == 200, (
            f"Expected 200 OK after redirects, got {response.status_code}.\n"
            f"Redirect chain: {' → '.join(visited_urls)}"
        )
        
        print(f"✓ Redirect chain ({redirect_count} redirects): {' → '.join(visited_urls)}")

    def test_grafana_redirect_stays_in_monitoring_path(self):
        """
        Test that Grafana redirects stay within /monitoring/grafana/ path.
        
        Redirects should NOT go to /grafana/ (without /monitoring/ prefix)
        as that would trigger the backwards compatibility redirect and loop.
        """
        url = f"{BASE_URL}{GRAFANA_PATH}"
        
        session = requests.Session()
        response = session.get(url, allow_redirects=False, timeout=10)
        
        if response.status_code in (301, 302, 303, 307, 308):
            location = response.headers.get("Location", "")
            
            # Location should either be:
            # - Relative within /monitoring/grafana/ (e.g., /monitoring/grafana/login)
            # - Absolute URL with /monitoring/grafana/ path
            
            # It should NOT be /grafana/ (without /monitoring/)
            assert not location.startswith("/grafana/"), (
                f"Redirect went to /grafana/ instead of /monitoring/grafana/!\n"
                f"Location: {location}\n"
                "This will cause a redirect loop with backwards compatibility redirects."
            )
            
            # If it's a relative path, it should include /monitoring/grafana/
            if location.startswith("/"):
                assert location.startswith("/monitoring/grafana/"), (
                    f"Redirect path doesn't start with /monitoring/grafana/\n"
                    f"Location: {location}"
                )
            
            print(f"✓ Redirect location is correct: {location}")
        else:
            print(f"✓ No redirect (status {response.status_code})")

    def test_grafana_login_page_accessible(self):
        """Test that the Grafana login page is accessible."""
        url = f"{BASE_URL}{GRAFANA_PATH}login"
        
        response = requests.get(url, timeout=10)
        
        assert response.status_code == 200, (
            f"Grafana login page not accessible. Status: {response.status_code}"
        )
        
        # Verify it's actually Grafana (check for Grafana-specific content)
        assert "grafana" in response.text.lower() or "login" in response.text.lower(), (
            "Response doesn't appear to be Grafana login page"
        )
        
        print(f"✓ Grafana login page accessible at {url}")

    def test_grafana_api_accessible(self):
        """Test that the Grafana API is accessible through the proxy."""
        url = f"{BASE_URL}{GRAFANA_PATH}api/health"
        
        response = requests.get(url, timeout=10)
        
        assert response.status_code == 200, (
            f"Grafana API health endpoint not accessible. Status: {response.status_code}"
        )
        
        # Verify it returns valid JSON
        try:
            data = response.json()
            assert "database" in data or "version" in data, (
                f"Unexpected health response: {data}"
            )
        except ValueError:
            pytest.fail(f"Grafana API returned invalid JSON: {response.text[:200]}")
        
        print(f"✓ Grafana API accessible at {url}")

    def test_backwards_compat_redirect_works(self):
        """
        Test that the backwards compatibility redirect from /grafana/ works.
        
        /grafana/ should redirect to /monitoring/grafana/ and eventually
        reach the Grafana UI without looping.
        """
        url = f"{BASE_URL}/grafana/"
        
        # Follow redirects and verify we reach Grafana
        response = requests.get(url, timeout=10)
        
        assert response.status_code == 200, (
            f"Could not access Grafana via /grafana/ redirect. Status: {response.status_code}"
        )
        
        # Final URL should be in /monitoring/grafana/
        assert "/monitoring/grafana/" in response.url, (
            f"Final URL not in /monitoring/grafana/: {response.url}"
        )
        
        print(f"✓ Backwards compat redirect works: /grafana/ → {response.url}")

    def test_redirect_count_reasonable(self):
        """
        Test that reaching Grafana requires a reasonable number of redirects.
        
        Normal flow should be:
        1. /monitoring/grafana/ → /monitoring/grafana/login (or similar)
        2. Done
        
        More than 3 redirects suggests a configuration issue.
        """
        url = f"{BASE_URL}{GRAFANA_PATH}"
        redirect_count = 0
        max_expected = 3
        
        session = requests.Session()
        
        while redirect_count < MAX_REDIRECTS:
            response = session.get(url, allow_redirects=False, timeout=10)
            
            if response.status_code not in (301, 302, 303, 307, 308):
                break
            
            location = response.headers.get("Location", "")
            if location.startswith("/"):
                url = f"{BASE_URL}{location}"
            else:
                url = location
            
            redirect_count += 1
        
        assert redirect_count <= max_expected, (
            f"Too many redirects: {redirect_count} (expected <= {max_expected})\n"
            "This may indicate a redirect loop or misconfiguration."
        )
        
        print(f"✓ Redirect count is reasonable: {redirect_count} redirects")


class TestGrafanaWebSocket:
    """Test Grafana WebSocket endpoint accessibility."""

    def test_websocket_upgrade_headers(self):
        """Test that WebSocket upgrade headers are properly passed."""
        url = f"{BASE_URL}{GRAFANA_PATH}api/live/ws"
        
        headers = {
            "Connection": "Upgrade",
            "Upgrade": "websocket",
            "Sec-WebSocket-Key": "dGhlIHNhbXBsZSBub25jZQ==",
            "Sec-WebSocket-Version": "13",
        }
        
        response = requests.get(url, headers=headers, timeout=10)
        
        # WebSocket upgrade should return 101 Switching Protocols
        # or 400 Bad Request if not authenticated (which is still valid)
        # A redirect loop would give us 301/302 responses
        assert response.status_code not in (301, 302), (
            f"WebSocket endpoint redirecting (possible loop). Status: {response.status_code}"
        )
        
        print(f"✓ WebSocket endpoint responding with status {response.status_code}")


def run_tests():
    """Run all tests and print summary."""
    print("=" * 60)
    print("Grafana Redirect Loop Prevention Tests")
    print("=" * 60)
    print()
    
    # Run pytest programmatically
    exit_code = pytest.main([
        __file__,
        "-v",
        "--tb=short",
        "-x",  # Stop on first failure
    ])
    
    return exit_code


if __name__ == "__main__":
    exit(run_tests())

