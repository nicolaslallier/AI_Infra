#!/bin/bash
# ============================================
# Keycloak Integration Validation Script
# AI Infrastructure Project
# ============================================
# This script validates the Keycloak integration
# according to the Gherkin scenarios in Analysis-00004.html

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Helper functions
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    PASSED_TESTS=$((PASSED_TESTS + 1))
}

print_failure() {
    echo -e "${RED}[FAIL]${NC} $1"
    FAILED_TESTS=$((FAILED_TESTS + 1))
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

check_service_health() {
    local service=$1
    local url=$2
    local max_retries=5
    local retry_delay=2
    
    for i in $(seq 1 $max_retries); do
        if curl -sf "$url" > /dev/null 2>&1; then
            return 0
        fi
        sleep $retry_delay
    done
    return 1
}

# ============================================
# MAIN VALIDATION
# ============================================

print_header "Keycloak Integration Validation"

# ============================================
# 1. Service Health Checks
# ============================================

print_header "1. Service Health Checks"

print_test "Keycloak container is running"
if docker ps | grep -q "ai_infra_keycloak"; then
    print_success "Keycloak container is running"
else
    print_failure "Keycloak container is not running"
fi

print_test "Keycloak service is healthy"
if docker inspect ai_infra_keycloak --format='{{.State.Health.Status}}' 2>/dev/null | grep -q "healthy"; then
    print_success "Keycloak is healthy"
else
    print_failure "Keycloak health check failed"
fi

print_test "Keycloak is accessible via NGINX at /auth/"
if check_service_health "keycloak" "http://localhost/auth/"; then
    print_success "Keycloak is accessible via NGINX"
else
    print_failure "Cannot access Keycloak via NGINX"
fi

print_test "PostgreSQL keycloak database exists"
if docker exec ai_infra_postgres psql -U postgres -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw keycloak; then
    print_success "Keycloak database exists"
else
    print_failure "Keycloak database not found"
fi

print_test "PostgreSQL keycloak user exists"
if docker exec ai_infra_postgres psql -U postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='keycloak'" 2>/dev/null | grep -q 1; then
    print_success "Keycloak database user exists"
else
    print_failure "Keycloak database user not found"
fi

# ============================================
# 2. Keycloak Realm Configuration
# ============================================

print_header "2. Keycloak Realm Configuration"

print_test "Keycloak realm 'infra-admin' exists"
# Note: This requires admin API access - checking via logs/container
if docker logs ai_infra_keycloak 2>&1 | grep -q "infra-admin"; then
    print_success "Realm 'infra-admin' appears to be configured"
else
    print_failure "Could not verify realm 'infra-admin'"
fi

print_test "Realm configuration file exists"
if [ -f "docker/keycloak/realm-export.json" ]; then
    print_success "Realm configuration file exists"
else
    print_failure "Realm configuration file not found"
fi

print_test "Realm configuration contains pgAdmin client"
if grep -q "pgadmin-client" "docker/keycloak/realm-export.json" 2>/dev/null; then
    print_success "pgAdmin client configured in realm"
else
    print_failure "pgAdmin client not found in realm configuration"
fi

print_test "Realm configuration contains required roles"
roles_found=0
for role in "ROLE_DBA" "ROLE_DEVOPS" "ROLE_READONLY_MONITORING"; do
    if grep -q "$role" "docker/keycloak/realm-export.json" 2>/dev/null; then
        roles_found=$((roles_found + 1))
    fi
done
if [ $roles_found -eq 3 ]; then
    print_success "All required roles found in realm configuration"
else
    print_failure "Missing required roles (found $roles_found/3)"
fi

# ============================================
# 3. pgAdmin OIDC Configuration
# ============================================

print_header "3. pgAdmin OIDC Configuration"

print_test "pgAdmin container is running"
if docker ps | grep -q "ai_infra_pgadmin"; then
    print_success "pgAdmin container is running"
else
    print_failure "pgAdmin container is not running"
fi

print_test "pgAdmin config contains OAuth2 settings"
if grep -q "OAUTH2" "docker/pgadmin/config_local.py" 2>/dev/null; then
    print_success "pgAdmin OAuth2 configuration found"
else
    print_failure "pgAdmin OAuth2 configuration not found"
fi

print_test "pgAdmin supports both internal and OAuth2 auth"
if grep -q "AUTHENTICATION_SOURCES.*internal.*oauth2" "docker/pgadmin/config_local.py" 2>/dev/null; then
    print_success "pgAdmin supports both auth methods"
else
    print_failure "pgAdmin auth sources not properly configured"
fi

# ============================================
# 4. NGINX Proxy Configuration
# ============================================

print_header "4. NGINX Proxy Configuration"

print_test "NGINX configuration includes Keycloak proxy"
if grep -q "location /auth/" "docker/nginx/nginx.conf" 2>/dev/null; then
    print_success "NGINX Keycloak proxy configured"
else
    print_failure "NGINX Keycloak proxy not found"
fi

print_test "NGINX includes backward compatibility redirect"
if grep -q "location.*keycloak" "docker/nginx/nginx.conf" 2>/dev/null; then
    print_success "NGINX backward compatibility redirect configured"
else
    print_failure "NGINX backward compatibility redirect not found"
fi

# ============================================
# 5. Monitoring Integration
# ============================================

print_header "5. Monitoring Integration"

print_test "Promtail configuration includes Keycloak scrape config"
if grep -q "job_name: keycloak" "docker/promtail/promtail.yml" 2>/dev/null; then
    print_success "Promtail Keycloak scrape config found"
else
    print_failure "Promtail Keycloak scrape config not found"
fi

print_test "Prometheus configuration includes Keycloak job"
if grep -q "job_name:.*keycloak" "docker/prometheus/prometheus.yml" 2>/dev/null; then
    print_success "Prometheus Keycloak job configured"
else
    print_failure "Prometheus Keycloak job not found"
fi

print_test "Keycloak alert rules exist"
if [ -f "docker/prometheus/alerts/keycloak-alerts.yml" ]; then
    print_success "Keycloak alert rules file exists"
else
    print_failure "Keycloak alert rules file not found"
fi

print_test "Grafana Keycloak dashboard exists"
if [ -f "docker/grafana/dashboards/keycloak-dashboard.json" ]; then
    print_success "Keycloak Grafana dashboard exists"
else
    print_failure "Keycloak Grafana dashboard not found"
fi

# ============================================
# 6. Network Configuration
# ============================================

print_header "6. Network Configuration"

print_test "Keycloak is on frontend-net"
if docker inspect ai_infra_keycloak 2>/dev/null | grep -q "frontend-net"; then
    print_success "Keycloak connected to frontend-net"
else
    print_failure "Keycloak not on frontend-net"
fi

print_test "Keycloak is on database-net"
if docker inspect ai_infra_keycloak 2>/dev/null | grep -q "database-net"; then
    print_success "Keycloak connected to database-net"
else
    print_failure "Keycloak not on database-net"
fi

print_test "Keycloak is on monitoring-net"
if docker inspect ai_infra_keycloak 2>/dev/null | grep -q "monitoring-net"; then
    print_success "Keycloak connected to monitoring-net"
else
    print_failure "Keycloak not on monitoring-net"
fi

# ============================================
# 7. PostgreSQL Access Control
# ============================================

print_header "7. PostgreSQL Access Control"

print_test "pg_hba.conf allows Keycloak connections"
if grep -q "keycloak.*keycloak.*172.23.0.0/24" "docker/postgres/pg_hba.conf" 2>/dev/null; then
    print_success "pg_hba.conf configured for Keycloak"
else
    print_failure "pg_hba.conf not configured for Keycloak"
fi

# ============================================
# 8. Docker Compose Configuration
# ============================================

print_header "8. Docker Compose Configuration"

print_test "Keycloak service defined in docker-compose.yml"
if grep -q "keycloak:" "docker-compose.yml" 2>/dev/null; then
    print_success "Keycloak service defined"
else
    print_failure "Keycloak service not found in docker-compose.yml"
fi

print_test "Keycloak volume defined"
if grep -q "keycloak_data:" "docker-compose.yml" 2>/dev/null; then
    print_success "Keycloak volume defined"
else
    print_failure "Keycloak volume not defined"
fi

print_test "pgAdmin depends on Keycloak"
if docker-compose config 2>/dev/null | grep -A 5 "pgadmin:" | grep -q "keycloak"; then
    print_success "pgAdmin depends on Keycloak"
else
    print_failure "pgAdmin dependency on Keycloak not configured"
fi

# ============================================
# 9. Gherkin Scenario Validation
# ============================================

print_header "9. Gherkin Scenario Tests"

print_info "Scenario 8.1: SSO via Keycloak"
print_test "Keycloak login page accessible"
if curl -sf "http://localhost/auth/realms/infra-admin/protocol/openid-connect/auth" > /dev/null 2>&1; then
    print_success "Keycloak OIDC auth endpoint accessible"
else
    print_failure "Cannot access Keycloak auth endpoint"
fi

print_info "Scenario 8.3: Logs sent to monitoring"
print_test "Keycloak container has logging labels"
if docker inspect ai_infra_keycloak 2>/dev/null | grep -q "logging.source"; then
    print_success "Keycloak has logging labels configured"
else
    print_failure "Keycloak logging labels not found"
fi

# ============================================
# SUMMARY
# ============================================

print_header "Validation Summary"

echo "Total Tests: $TOTAL_TESTS"
echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
echo -e "${RED}Failed: $FAILED_TESTS${NC}"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "\n${GREEN}✓ All validation tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}✗ Some validation tests failed. Please review the output above.${NC}"
    exit 1
fi

