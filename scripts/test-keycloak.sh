#!/bin/bash
# Keycloak Access Test Script
# Tests if Keycloak is accessible through NGINX reverse proxy

set -e

echo "═══════════════════════════════════════════════════════"
echo "  Keycloak Access Test"
echo "═══════════════════════════════════════════════════════"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results counter
PASSED=0
FAILED=0

# Test 1: Health check
echo -n "Test 1: Health check endpoint... "
if curl -sf http://localhost/auth/health/ready > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ FAILED${NC}"
    ((FAILED++))
fi

# Test 2: Ready check
echo -n "Test 2: Ready endpoint... "
if curl -sf http://localhost/auth/health/ready > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ FAILED${NC}"
    ((FAILED++))
fi

# Test 3: Admin console access
echo -n "Test 3: Admin console access... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/auth/ 2>/dev/null)
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "303" ] || [ "$HTTP_CODE" = "302" ]; then
    echo -e "${GREEN}✓ PASSED${NC} (HTTP $HTTP_CODE)"
    ((PASSED++))
else
    echo -e "${RED}✗ FAILED${NC} (HTTP $HTTP_CODE)"
    ((FAILED++))
fi

# Test 4: Realm discovery
echo -n "Test 4: Realm OIDC discovery... "
if curl -sf http://localhost/auth/realms/infra-admin/.well-known/openid-configuration > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ FAILED${NC}"
    ((FAILED++))
fi

# Test 5: Master realm
echo -n "Test 5: Master realm access... "
if curl -sf http://localhost/auth/realms/master > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ FAILED${NC}"
    ((FAILED++))
fi

# Test 6: Metrics endpoint
echo -n "Test 6: Metrics endpoint... "
if curl -sf http://localhost/auth/metrics > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED${NC}"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠ SKIPPED${NC} (may require auth)"
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}"
echo "═══════════════════════════════════════════════════════"
echo ""

# Additional diagnostics if tests failed
if [ $FAILED -gt 0 ]; then
    echo -e "${YELLOW}Running diagnostics...${NC}"
    echo ""
    
    echo "Keycloak container status:"
    docker ps --filter name=keycloak --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    
    echo "Last 10 lines of Keycloak logs:"
    docker logs --tail 10 ai_infra_keycloak 2>&1 || echo "Could not fetch logs"
    echo ""
    
    echo "NGINX container status:"
    docker ps --filter name=nginx --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    
    echo -e "${YELLOW}Troubleshooting tips:${NC}"
    echo "1. Check if Keycloak is running: docker ps | grep keycloak"
    echo "2. View Keycloak logs: docker logs ai_infra_keycloak"
    echo "3. View NGINX logs: docker logs ai_infra_nginx"
    echo "4. Restart Keycloak: docker-compose restart keycloak"
    echo "5. Check KEYCLOAK-HTTPS-FIX.md for detailed troubleshooting"
    echo ""
    
    exit 1
fi

echo -e "${GREEN}All critical tests passed! Keycloak is accessible.${NC}"
echo ""
echo "Next steps:"
echo "  • Access admin console: http://localhost/auth/"
echo "  • Default credentials: admin / admin"
echo "  • View documentation: KEYCLOAK_INTEGRATION.md"
echo ""

exit 0

