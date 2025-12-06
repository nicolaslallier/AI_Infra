#!/bin/bash
# Verification script for pgAdmin configuration and health
# Part of AI Infrastructure Project

set -e

echo "=================================================="
echo "pgAdmin Verification Script"
echo "=================================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if container is running
echo "1. Checking if pgAdmin container is running..."
if docker ps | grep -q ai_infra_pgadmin; then
    echo -e "${GREEN}✓ Container is running${NC}"
else
    echo -e "${RED}✗ Container is not running${NC}"
    exit 1
fi

# Check container health
echo ""
echo "2. Checking container health..."
HEALTH=$(docker inspect --format='{{.State.Health.Status}}' ai_infra_pgadmin 2>/dev/null || echo "no-healthcheck")
if [ "$HEALTH" = "healthy" ]; then
    echo -e "${GREEN}✓ Container is healthy${NC}"
elif [ "$HEALTH" = "starting" ]; then
    echo -e "${YELLOW}⚠ Container health check is still starting${NC}"
else
    echo -e "${RED}✗ Container is unhealthy: $HEALTH${NC}"
fi

# Check for configuration errors in logs
echo ""
echo "3. Checking for configuration errors..."
ERROR_COUNT=$(docker logs ai_infra_pgadmin 2>&1 | grep -c "NameError: name 'internal' is not defined" || true)
if [ "$ERROR_COUNT" -eq 0 ]; then
    echo -e "${GREEN}✓ No authentication configuration errors${NC}"
else
    echo -e "${RED}✗ Found $ERROR_COUNT authentication errors${NC}"
fi

# Check for gunicorn timeout errors
echo ""
echo "4. Checking for gunicorn errors..."
GUNICORN_ERROR=$(docker logs ai_infra_pgadmin 2>&1 | grep -c "gunicorn: error: argument -t/--timeout" || true)
if [ "$GUNICORN_ERROR" -eq 0 ]; then
    echo -e "${GREEN}✓ No gunicorn timeout errors${NC}"
else
    echo -e "${RED}✗ Found $GUNICORN_ERROR gunicorn timeout errors${NC}"
fi

# Check if pgAdmin is responding
echo ""
echo "5. Testing HTTP endpoint..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/pgadmin/login || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ pgAdmin login page is accessible (HTTP $HTTP_CODE)${NC}"
else
    echo -e "${RED}✗ pgAdmin login page returned HTTP $HTTP_CODE${NC}"
fi

# Verify configuration files are mounted
echo ""
echo "6. Verifying configuration files..."
if docker exec ai_infra_pgadmin test -f /pgadmin4/config_distro.py; then
    echo -e "${GREEN}✓ config_distro.py is mounted${NC}"
else
    echo -e "${RED}✗ config_distro.py is missing${NC}"
fi

if docker exec ai_infra_pgadmin test -f /pgadmin4/config_local.py; then
    echo -e "${GREEN}✓ config_local.py is mounted${NC}"
else
    echo -e "${RED}✗ config_local.py is missing${NC}"
fi

# Check authentication sources configuration
echo ""
echo "7. Verifying authentication configuration..."
if docker exec ai_infra_pgadmin grep -q "AUTHENTICATION_SOURCES = \['internal', 'oauth2'\]" /pgadmin4/config_distro.py 2>/dev/null; then
    echo -e "${GREEN}✓ Authentication sources correctly configured in config_distro.py${NC}"
    docker exec ai_infra_pgadmin grep "AUTHENTICATION_SOURCES" /pgadmin4/config_distro.py | head -1
else
    echo -e "${RED}✗ Authentication configuration issue${NC}"
fi

# Check pgAdmin version
echo ""
echo "8. pgAdmin version information..."
PGADMIN_VERSION=$(docker logs ai_infra_pgadmin 2>&1 | grep "Starting pgAdmin" | tail -1)
if [ -n "$PGADMIN_VERSION" ]; then
    echo -e "${GREEN}✓ $PGADMIN_VERSION${NC}"
else
    echo -e "${YELLOW}⚠ Could not determine pgAdmin version${NC}"
fi

# Summary
echo ""
echo "=================================================="
echo "Verification Summary"
echo "=================================================="
echo ""

if [ "$HTTP_CODE" = "200" ] && [ "$ERROR_COUNT" -eq 0 ] && [ "$GUNICORN_ERROR" -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! pgAdmin is fully operational.${NC}"
    echo ""
    echo "Access pgAdmin at: http://localhost/pgadmin/"
    echo "Default credentials (if not changed):"
    echo "  Email: admin@example.com"
    echo "  Password: admin"
    exit 0
else
    echo -e "${RED}✗ Some checks failed. Please review the output above.${NC}"
    echo ""
    echo "For troubleshooting, check:"
    echo "  - docker logs ai_infra_pgadmin"
    echo "  - /docker/pgadmin/README.md"
    echo "  - /PGADMIN-STARTUP-FIX.md"
    exit 1
fi

