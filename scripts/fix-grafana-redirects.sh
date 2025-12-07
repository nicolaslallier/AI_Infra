#!/bin/bash

# Script to fix Grafana "too many redirects" error
# This script restarts the affected services to apply the configuration changes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Grafana Redirect Loop Fix${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}This script will restart Grafana and Nginx to apply configuration changes${NC}"
echo -e "${YELLOW}that fix the 'too many redirects' error.${NC}"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  echo -e "${RED}❌ Docker is not running${NC}"
  echo "Please start Docker and try again."
  exit 1
fi

echo -e "${BLUE}1️⃣  Checking current status...${NC}"
GRAFANA_STATUS=$(docker-compose ps grafana --format json 2>/dev/null | grep -o '"State":"[^"]*"' | cut -d'"' -f4 || echo "not found")
NGINX_STATUS=$(docker-compose ps nginx --format json 2>/dev/null | grep -o '"State":"[^"]*"' | cut -d'"' -f4 || echo "not found")

echo "   Grafana: $GRAFANA_STATUS"
echo "   Nginx: $NGINX_STATUS"
echo ""

echo -e "${BLUE}2️⃣  Stopping affected services...${NC}"
docker-compose stop grafana nginx

echo -e "${GREEN}✅ Services stopped${NC}"
echo ""

echo -e "${BLUE}3️⃣  Starting services with new configuration...${NC}"
docker-compose up -d grafana nginx

echo -e "${GREEN}✅ Services started${NC}"
echo ""

echo -e "${BLUE}4️⃣  Waiting for Grafana to be ready...${NC}"
MAX_WAIT=30
COUNTER=0
while [ $COUNTER -lt $MAX_WAIT ]; do
  if docker exec ai_infra_grafana curl -sf http://localhost:3000/api/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Grafana is ready!${NC}"
    break
  fi
  echo -n "."
  sleep 1
  COUNTER=$((COUNTER + 1))
done

if [ $COUNTER -eq $MAX_WAIT ]; then
  echo ""
  echo -e "${YELLOW}⚠️  Grafana taking longer than expected to start${NC}"
  echo "Check logs with: docker logs ai_infra_grafana"
else
  echo ""
fi

echo ""
echo -e "${BLUE}5️⃣  Verifying configuration...${NC}"

# Check if serve_from_sub_path is set correctly
SERVE_CONFIG=$(docker exec ai_infra_grafana env | grep GF_SERVER_SERVE_FROM_SUB_PATH || echo "not set")
echo "   GF_SERVER_SERVE_FROM_SUB_PATH: $SERVE_CONFIG"

if echo "$SERVE_CONFIG" | grep -q "true"; then
  echo -e "${GREEN}   ✅ Configuration looks correct${NC}"
else
  echo -e "${YELLOW}   ⚠️  Configuration might not be correct${NC}"
fi

echo ""
echo -e "${BLUE}6️⃣  Testing Grafana endpoint...${NC}"

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/monitoring/grafana/ 2>/dev/null || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
  echo -e "${GREEN}   ✅ Grafana is responding (HTTP $HTTP_CODE)${NC}"
elif [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "301" ]; then
  echo -e "${YELLOW}   ⚠️  Grafana is redirecting (HTTP $HTTP_CODE)${NC}"
  echo -e "${YELLOW}   This might be normal for login redirect${NC}"
else
  echo -e "${RED}   ❌ Grafana returned HTTP $HTTP_CODE${NC}"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}✅ Configuration changes applied${NC}"
echo -e "${GREEN}✅ Services restarted${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Open your browser to: ${BLUE}http://localhost/monitoring/grafana/${NC}"
echo "2. You should see the Grafana login page (no redirect error)"
echo "3. Login with:"
echo "   Username: ${BLUE}admin${NC}"
echo "   Password: ${BLUE}admin${NC}"
echo ""
echo -e "${YELLOW}If you still see redirect errors:${NC}"
echo "- Clear your browser cache (Ctrl+Shift+Delete)"
echo "- Try incognito/private browsing mode"
echo "- Check logs: ${BLUE}docker logs ai_infra_grafana${NC}"
echo ""
echo "See ${BLUE}GRAFANA_REDIRECT_LOOP_FIX.md${NC} for more details."
echo ""

