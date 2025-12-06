#!/bin/bash
#
# Test script to verify Grafana redirect loop is fixed.
#
# This test ensures that accessing Grafana through the nginx reverse proxy
# does not result in an infinite redirect loop.
#
# Usage: ./scripts/test/test-grafana-redirect.sh
#

# Don't exit on error - we want to run all tests
# set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
BASE_URL="${BASE_URL:-http://localhost}"
GRAFANA_PATH="/monitoring/grafana/"
MAX_REDIRECTS=10

# Counters
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
print_test() {
    echo -e "\n${YELLOW}TEST:${NC} $1"
}

print_pass() {
    echo -e "${GREEN}✓ PASS:${NC} $1"
    ((TESTS_PASSED++))
}

print_fail() {
    echo -e "${RED}✗ FAIL:${NC} $1"
    ((TESTS_FAILED++))
}

print_info() {
    echo -e "  ${NC}→ $1"
}

# Check if curl is available
if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl is required but not installed.${NC}"
    exit 1
fi

echo "=============================================="
echo "Grafana Redirect Loop Prevention Tests"
echo "=============================================="
echo "Base URL: $BASE_URL"
echo "Grafana Path: $GRAFANA_PATH"
echo ""

# Test 1: No redirect loop
print_test "No redirect loop when accessing Grafana"

url="${BASE_URL}${GRAFANA_PATH}"
redirect_count=0
visited_urls=""
current_url="$url"

while [ $redirect_count -lt $MAX_REDIRECTS ]; do
    # Get headers only, follow redirects manually
    response=$(curl -s -I -o /dev/null -w "%{http_code}|%{redirect_url}" "$current_url" 2>/dev/null)
    http_code=$(echo "$response" | cut -d'|' -f1)
    redirect_url=$(echo "$response" | cut -d'|' -f2)
    
    # Track visited URLs
    if echo "$visited_urls" | grep -q "$current_url"; then
        print_fail "Redirect loop detected! URL '$current_url' visited twice."
        print_info "Visited URLs: $visited_urls"
        break
    fi
    visited_urls="$visited_urls $current_url"
    
    # Check if it's a redirect
    if [[ "$http_code" =~ ^3[0-9][0-9]$ ]]; then
        ((redirect_count++))
        if [ -z "$redirect_url" ]; then
            # Get Location header manually
            redirect_url=$(curl -s -I "$current_url" 2>/dev/null | grep -i "^Location:" | sed 's/Location: //i' | tr -d '\r')
        fi
        
        # Handle relative URLs
        if [[ "$redirect_url" == /* ]]; then
            current_url="${BASE_URL}${redirect_url}"
        else
            current_url="$redirect_url"
        fi
    else
        # Not a redirect, we've reached destination
        break
    fi
done

if [ $redirect_count -ge $MAX_REDIRECTS ]; then
    print_fail "Too many redirects ($redirect_count). Possible redirect loop!"
elif [ "$http_code" == "200" ]; then
    print_pass "Reached Grafana successfully after $redirect_count redirect(s)"
    print_info "Final URL: $current_url"
else
    print_fail "Unexpected status code: $http_code"
fi

# Test 2: Redirect stays in /monitoring/grafana/ path
print_test "First redirect stays in /monitoring/grafana/ path"

url="${BASE_URL}${GRAFANA_PATH}"
location=$(curl -s -I "$url" 2>/dev/null | grep -i "^Location:" | sed 's/Location: //i' | tr -d '\r')

if [ -z "$location" ]; then
    print_info "No redirect (direct 200 response)"
    print_pass "No problematic redirect"
elif [[ "$location" == /grafana/* ]]; then
    print_fail "Redirect went to /grafana/ instead of /monitoring/grafana/"
    print_info "Location: $location"
    print_info "This causes a redirect loop with backwards compatibility redirects!"
elif [[ "$location" == /monitoring/grafana/* ]] || [[ "$location" == *"/monitoring/grafana/"* ]]; then
    print_pass "Redirect location is correct"
    print_info "Location: $location"
else
    print_info "Redirect to: $location"
    print_pass "Redirect doesn't go to problematic /grafana/ path"
fi

# Test 3: Grafana login page accessible
print_test "Grafana login page is accessible"

url="${BASE_URL}${GRAFANA_PATH}login"
http_code=$(curl -s -o /dev/null -w "%{http_code}" -L "$url" 2>/dev/null)

if [ "$http_code" == "200" ]; then
    print_pass "Login page accessible (HTTP 200)"
else
    print_fail "Login page not accessible (HTTP $http_code)"
fi

# Test 4: Grafana API health endpoint
print_test "Grafana API health endpoint is accessible"

url="${BASE_URL}${GRAFANA_PATH}api/health"
response=$(curl -s -L "$url" 2>/dev/null)
http_code=$(curl -s -o /dev/null -w "%{http_code}" -L "$url" 2>/dev/null)

if [ "$http_code" == "200" ]; then
    if echo "$response" | grep -q "database"; then
        print_pass "API health endpoint accessible and returning valid data"
        print_info "Response: $response"
    else
        print_pass "API health endpoint accessible (HTTP 200)"
    fi
else
    print_fail "API health endpoint not accessible (HTTP $http_code)"
fi

# Test 5: Backwards compatibility redirect
print_test "Backwards compatibility redirect (/grafana/ → /monitoring/grafana/)"

url="${BASE_URL}/grafana/"
final_url=$(curl -s -L -o /dev/null -w "%{url_effective}" "$url" 2>/dev/null)
http_code=$(curl -s -L -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)

if [ "$http_code" == "200" ]; then
    if [[ "$final_url" == *"/monitoring/grafana/"* ]]; then
        print_pass "Backwards compat redirect works correctly"
        print_info "Final URL: $final_url"
    else
        print_fail "Final URL not in /monitoring/grafana/"
        print_info "Final URL: $final_url"
    fi
else
    print_fail "Could not access Grafana via /grafana/ (HTTP $http_code)"
fi

# Test 6: Redirect count is reasonable
print_test "Redirect count is reasonable (≤ 3)"

url="${BASE_URL}${GRAFANA_PATH}"
redirect_count=$(curl -s -L -o /dev/null -w "%{num_redirects}" "$url" 2>/dev/null)

if [ "$redirect_count" -le 3 ]; then
    print_pass "Redirect count is reasonable ($redirect_count redirects)"
else
    print_fail "Too many redirects ($redirect_count). Possible configuration issue."
fi

# Test 7: No duplicate path segments
print_test "No duplicate /monitoring/grafana/ path segments"

url="${BASE_URL}${GRAFANA_PATH}"
final_url=$(curl -s -L -o /dev/null -w "%{url_effective}" "$url" 2>/dev/null)

# Check for duplicate path segments like /monitoring/grafana/monitoring/grafana/
if [[ "$final_url" == *"/monitoring/grafana/monitoring/grafana/"* ]]; then
    print_fail "Duplicate path segments detected in final URL!"
    print_info "Final URL: $final_url"
elif [[ "$final_url" == *"/grafana/grafana/"* ]]; then
    print_fail "Duplicate /grafana/ path segments detected!"
    print_info "Final URL: $final_url"
else
    print_pass "No duplicate path segments in final URL"
    print_info "Final URL: $final_url"
fi

# Summary
echo ""
echo "=============================================="
echo "Test Summary"
echo "=============================================="
echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
echo -e "${RED}Failed:${NC} $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed! ✓${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. Please check the configuration.${NC}"
    exit 1
fi

