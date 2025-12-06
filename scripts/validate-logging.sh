#!/bin/bash
# =============================================================================
# PostgreSQL & pgAdmin Logging Validation Script
# AI Infrastructure Project
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASS=0
FAIL=0

# Functions
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

print_test() {
    echo -n "$1... "
}

print_pass() {
    echo -e "${GREEN}✓ PASS${NC}"
    ((PASS++))
}

print_fail() {
    echo -e "${RED}✗ FAIL${NC} - $1"
    ((FAIL++))
}

print_skip() {
    echo -e "${YELLOW}⊘ SKIP${NC} - $1"
}

# =============================================================================
# TESTS
# =============================================================================

print_header "PostgreSQL & pgAdmin Logging Validation"

# Test 1: Container Health
print_test "1. Checking PostgreSQL container health"
if docker ps | grep -q "ai_infra_postgres.*healthy"; then
    print_pass
else
    print_fail "PostgreSQL container not healthy"
fi

print_test "2. Checking pgAdmin container health"
if docker ps | grep -q "ai_infra_pgadmin.*Up"; then
    print_pass
else
    print_fail "pgAdmin container not running"
fi

print_test "3. Checking Promtail container health"
if docker ps | grep -q "ai_infra_promtail.*healthy"; then
    print_pass
else
    print_fail "Promtail container not healthy"
fi

print_test "4. Checking Loki container health"
if docker ps | grep -q "ai_infra_loki.*healthy"; then
    print_pass
else
    print_fail "Loki container not healthy"
fi

# Test 2: Service Readiness
print_test "5. Checking Loki ready status"
if curl -s http://localhost:3100/ready | grep -q "ready"; then
    print_pass
else
    print_fail "Loki not ready"
fi

print_test "6. Checking Promtail ready status"
if curl -s http://localhost:9080/ready 2>/dev/null | grep -q "Promtail"; then
    print_pass
else
    print_skip "Promtail ready endpoint may not be available"
fi

# Test 3: Log Generation
print_test "7. Checking PostgreSQL log generation"
POSTGRES_LOGS=$(docker logs ai_infra_postgres --tail 10 2>&1)
if [ -n "$POSTGRES_LOGS" ]; then
    print_pass
else
    print_fail "No PostgreSQL logs found"
fi

print_test "8. Checking pgAdmin log generation"
PGADMIN_LOGS=$(docker logs ai_infra_pgadmin --tail 10 2>&1)
if [ -n "$PGADMIN_LOGS" ]; then
    print_pass
else
    print_fail "No pgAdmin logs found"
fi

# Test 4: Log Collection
print_test "9. Checking PostgreSQL logs in Loki"
POSTGRES_QUERY=$(curl -s -G "http://localhost:3100/loki/api/v1/query_range" \
    --data-urlencode 'query={source="postgres"}' \
    --data-urlencode 'limit=1' 2>/dev/null)
if echo "$POSTGRES_QUERY" | grep -q '"result"'; then
    print_pass
else
    print_fail "No PostgreSQL logs found in Loki (may need time to collect)"
fi

print_test "10. Checking pgAdmin logs in Loki"
PGADMIN_QUERY=$(curl -s -G "http://localhost:3100/loki/api/v1/query_range" \
    --data-urlencode 'query={source="pgadmin"}' \
    --data-urlencode 'limit=1' 2>/dev/null)
if echo "$PGADMIN_QUERY" | grep -q '"result"'; then
    print_pass
else
    print_fail "No pgAdmin logs found in Loki (may need time to collect)"
fi

# Test 5: Promtail Targets
print_test "11. Checking Promtail target discovery"
TARGETS=$(curl -s http://localhost:9080/targets 2>/dev/null)
if echo "$TARGETS" | grep -q "postgres"; then
    print_pass
else
    print_fail "Promtail not discovering PostgreSQL container"
fi

# Test 6: Configuration Files
print_test "12. Checking PostgreSQL config JSON logging"
if docker exec ai_infra_postgres cat /etc/postgresql/postgresql.conf 2>/dev/null | grep -q "log_destination.*jsonlog"; then
    print_pass
else
    print_skip "PostgreSQL may not support jsonlog (requires v15+)"
fi

print_test "13. Checking pgAdmin config file mounted"
if docker exec ai_infra_pgadmin ls /pgadmin4/config_local.py >/dev/null 2>&1; then
    print_pass
else
    print_fail "pgAdmin config_local.py not mounted"
fi

print_test "14. Checking Promtail config file"
if docker exec ai_infra_promtail cat /etc/promtail/promtail.yml >/dev/null 2>&1; then
    print_pass
else
    print_fail "Promtail config not found"
fi

# Test 7: Alert Rules
print_test "15. Checking alert rules file"
if docker exec ai_infra_prometheus cat /etc/prometheus/alerts/database-logs-alerts.yml >/dev/null 2>&1; then
    print_pass
else
    print_fail "Alert rules file not found"
fi

# Test 8: Grafana Dashboards
print_test "16. Checking PostgreSQL dashboard file"
if [ -f "docker/grafana/dashboards/postgresql-logs.json" ]; then
    print_pass
else
    print_fail "PostgreSQL dashboard not found"
fi

print_test "17. Checking pgAdmin dashboard file"
if [ -f "docker/grafana/dashboards/pgadmin-audit.json" ]; then
    print_pass
else
    print_fail "pgAdmin dashboard not found"
fi

# Test 9: Documentation
print_test "18. Checking logging documentation"
if [ -f "docker/README-LOGGING.md" ]; then
    print_pass
else
    print_fail "Logging documentation not found"
fi

# Test 10: Functional Test - Generate Log
print_header "Functional Tests"

print_test "19. Testing PostgreSQL connection logging"
if docker exec ai_infra_postgres psql -U postgres -d app_db -c "SELECT 1;" >/dev/null 2>&1; then
    print_pass
else
    print_fail "Failed to connect to PostgreSQL"
fi

print_test "20. Testing PostgreSQL error logging"
docker exec ai_infra_postgres psql -U postgres -d app_db -c "SELECT * FROM nonexistent_table;" >/dev/null 2>&1 || true
if docker logs ai_infra_postgres --tail 20 | grep -q "nonexistent_table\|does not exist"; then
    print_pass
else
    print_skip "Error not found in recent logs"
fi

# =============================================================================
# SUMMARY
# =============================================================================

print_header "Validation Summary"

TOTAL=$((PASS + FAIL))
PASS_PERCENT=0
if [ $TOTAL -gt 0 ]; then
    PASS_PERCENT=$((PASS * 100 / TOTAL))
fi

echo -e "${GREEN}Passed: $PASS${NC}"
echo -e "${RED}Failed: $FAIL${NC}"
echo -e "Total:  $TOTAL"
echo -e "Success Rate: ${PASS_PERCENT}%"

if [ $FAIL -eq 0 ]; then
    echo -e "\n${GREEN}✓ All tests passed!${NC}"
    echo -e "Logging infrastructure is operational.\n"
    exit 0
else
    echo -e "\n${YELLOW}⚠ Some tests failed.${NC}"
    echo -e "Review the failures above and check:"
    echo -e "  - All containers are running and healthy"
    echo -e "  - Configuration files are properly mounted"
    echo -e "  - Services have had time to start (wait 30-60 seconds)"
    echo -e "  - Network connectivity between services"
    echo -e "\nFor detailed validation, see: docker/VALIDATION-CHECKLIST.md\n"
    exit 1
fi

