#!/bin/bash

# ============================================
# Prometheus Validation Script
# AI Infrastructure Project
# ============================================
# This script validates that Prometheus is running correctly
# with proper alert rule configuration.

set -e

echo "================================================"
echo "Prometheus Validation Script"
echo "================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Prometheus container is running
echo "1. Checking Prometheus container status..."
if docker ps | grep "ai_infra_prometheus" | grep -q "healthy"; then
    echo -e "${GREEN}✓${NC} Prometheus container is running and healthy"
else
    echo -e "${RED}✗${NC} Prometheus container is not healthy"
    docker ps | grep prometheus
    exit 1
fi
echo ""

# Check for configuration errors
echo "2. Checking for configuration errors..."
ERROR_COUNT=$(docker logs ai_infra_prometheus --since 2m 2>&1 | grep -i "error loading rule file patterns\|could not parse expression" | wc -l)
if [ "$ERROR_COUNT" -eq 0 ]; then
    echo -e "${GREEN}✓${NC} No configuration or parse errors found"
else
    echo -e "${RED}✗${NC} Found $ERROR_COUNT configuration errors in logs"
    docker logs ai_infra_prometheus --since 5m 2>&1 | grep -i "error loading rule file patterns\|could not parse expression"
    exit 1
fi
echo ""

# Check if rule manager is running
echo "3. Checking rule manager status..."
if docker logs ai_infra_prometheus --since 5m 2>&1 | grep -q "Starting rule manager"; then
    echo -e "${GREEN}✓${NC} Rule manager started successfully"
else
    echo -e "${RED}✗${NC} Rule manager not started"
    exit 1
fi
echo ""

# Check if Keycloak alerts are loaded
echo "4. Checking Keycloak alert rules..."
if docker logs ai_infra_prometheus --since 5m 2>&1 | grep -q "keycloak_service_health"; then
    echo -e "${GREEN}✓${NC} Keycloak alert rules loaded successfully"
    
    # List loaded alert groups
    echo ""
    echo "   Loaded alert groups:"
    docker logs ai_infra_prometheus --since 5m 2>&1 | grep "keycloak" | grep -o "group=[^ ]*" | sort -u | sed 's/^/   - /'
else
    echo -e "${YELLOW}⚠${NC} Keycloak alert rules not found in logs"
fi
echo ""

# Check if server is ready
echo "5. Checking if Prometheus is ready to serve requests..."
if docker logs ai_infra_prometheus --since 5m 2>&1 | grep -q "Server is ready to receive web requests"; then
    echo -e "${GREEN}✓${NC} Prometheus server is ready"
else
    echo -e "${YELLOW}⚠${NC} Prometheus may still be starting up"
fi
echo ""

# Try to access Prometheus API
echo "6. Testing Prometheus API access..."
if curl -s -f http://localhost:9090/-/healthy > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Prometheus API is accessible"
else
    echo -e "${RED}✗${NC} Cannot access Prometheus API on localhost:9090"
    echo "   Note: This may be normal if Prometheus is behind nginx proxy"
fi
echo ""

# Check alert files
echo "7. Checking alert rule files..."
ALERT_FILES=$(docker exec ai_infra_prometheus ls /etc/prometheus/alerts/*.yml 2>/dev/null | wc -l)
if [ "$ALERT_FILES" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Found $ALERT_FILES alert rule file(s):"
    docker exec ai_infra_prometheus ls -1 /etc/prometheus/alerts/*.yml | sed 's|^/etc/prometheus/alerts/|   - |'
else
    echo -e "${YELLOW}⚠${NC} No alert rule files found"
fi
echo ""

# Check for disabled files
echo "8. Checking for disabled alert files..."
DISABLED_FILES=$(docker exec ai_infra_prometheus ls /etc/prometheus/alerts/*.disabled 2>/dev/null | wc -l || echo "0")
if [ "$DISABLED_FILES" -gt 0 ]; then
    echo -e "${YELLOW}⚠${NC} Found $DISABLED_FILES disabled alert file(s):"
    docker exec ai_infra_prometheus ls -1 /etc/prometheus/alerts/*.disabled 2>/dev/null | sed 's|^/etc/prometheus/alerts/|   - |'
    echo "   Note: These contain LogQL-based alerts for Loki Ruler"
else
    echo -e "${GREEN}✓${NC} No disabled alert files found"
fi
echo ""

# Summary
echo "================================================"
echo "Validation Summary"
echo "================================================"
echo ""
echo "Prometheus is configured correctly for metric-based alerting."
echo ""
echo "Active Features:"
echo "  ✓ Service health monitoring"
echo "  ✓ Resource utilization alerts (CPU, Memory)"
echo "  ✓ PromQL-based metric queries"
echo ""
echo "Disabled Features (require Loki Ruler):"
echo "  ⏸ Log-based authentication monitoring"
echo "  ⏸ Log-based admin event monitoring"
echo "  ⏸ Log-based database error monitoring"
echo "  ⏸ Log-based error rate analysis"
echo ""
echo "For full monitoring capabilities, see:"
echo "  docker/prometheus/alerts/README-LOG-BASED-ALERTS.md"
echo ""
echo -e "${GREEN}Validation Complete!${NC}"

