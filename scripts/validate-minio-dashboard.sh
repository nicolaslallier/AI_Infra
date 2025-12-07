#!/bin/bash
# MinIO Dashboard Validation Script
# Validates that all required metrics and datasources are available

set -e

PROMETHEUS_URL="http://localhost/monitoring/prometheus"
LOKI_URL="http://localhost/monitoring/loki"
GRAFANA_URL="http://localhost/monitoring/grafana"

echo "================================================"
echo "MinIO Dashboard Validation Script"
echo "================================================"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if service is accessible
check_service() {
    local service_name=$1
    local url=$2
    echo -n "Checking ${service_name}... "
    if curl -s -f "${url}" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ OK${NC}"
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        return 1
    fi
}

# Function to check Prometheus metric
check_metric() {
    local metric_name=$1
    echo -n "  - ${metric_name}... "
    
    result=$(curl -s "${PROMETHEUS_URL}/api/v1/query?query=${metric_name}" | grep -o '"status":"success"')
    
    if [ -n "$result" ]; then
        data_count=$(curl -s "${PROMETHEUS_URL}/api/v1/query?query=${metric_name}" | grep -o '"result":\[[^]]*\]' | wc -c)
        if [ "$data_count" -gt 20 ]; then
            echo -e "${GREEN}✓ Has data${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠ No data (metric exists)${NC}"
            return 0
        fi
    else
        echo -e "${RED}✗ Not found${NC}"
        return 1
    fi
}

# Function to check Loki labels
check_loki_label() {
    local label_name=$1
    echo -n "  - Label: ${label_name}... "
    
    result=$(curl -s "${LOKI_URL}/loki/api/v1/labels" | grep -o "\"${label_name}\"")
    
    if [ -n "$result" ]; then
        echo -e "${GREEN}✓ OK${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Not found${NC}"
        return 1
    fi
}

echo "1. Service Availability"
echo "----------------------"
check_service "Prometheus" "${PROMETHEUS_URL}/api/v1/status/config"
check_service "Loki" "${LOKI_URL}/ready"
check_service "Grafana" "${GRAFANA_URL}/api/health"
echo ""

echo "2. Prometheus Metrics (MinIO)"
echo "-----------------------------"
echo "Cluster Metrics:"
check_metric "minio_cluster_nodes_online_total"
check_metric "minio_cluster_capacity_usable_total_bytes"
check_metric "minio_cluster_capacity_usable_free_bytes"
check_metric "minio_bucket_usage_total_bytes"
check_metric "minio_bucket_usage_object_total"

echo ""
echo "Node Metrics:"
check_metric "minio_node_uptime_seconds"
check_metric "minio_node_process_resident_memory_bytes"

echo ""
echo "Request Metrics:"
check_metric "minio_s3_requests_total"
check_metric "minio_s3_requests_errors_total"
check_metric "minio_s3_requests_ttfb_seconds_bucket"
check_metric "minio_s3_traffic_received_bytes"
check_metric "minio_s3_traffic_sent_bytes"

echo ""
echo "3. Loki Labels (MinIO Logs)"
echo "---------------------------"
check_loki_label "source"
check_loki_label "environment"
check_loki_label "container"
check_loki_label "operation_type"
check_loki_label "security_event"

echo ""
echo "4. Dashboard Variables"
echo "----------------------"
echo -n "Checking environment values... "
env_count=$(curl -s "${PROMETHEUS_URL}/api/v1/label/environment/values" | grep -o '"development"' | wc -l)
if [ "$env_count" -gt 0 ]; then
    echo -e "${GREEN}✓ OK${NC}"
else
    echo -e "${YELLOW}⚠ No values${NC}"
fi

echo -n "Checking node values... "
node_count=$(curl -s "${PROMETHEUS_URL}/api/v1/label/node/values" | grep -o '"minio[1-4]"' | wc -l)
if [ "$node_count" -ge 1 ]; then
    echo -e "${GREEN}✓ OK (${node_count} nodes)${NC}"
else
    echo -e "${RED}✗ No nodes found${NC}"
fi

echo -n "Checking bucket values... "
bucket_query=$(curl -s "${PROMETHEUS_URL}/api/v1/query?query=minio_bucket_usage_total_bytes")
bucket_count=$(echo "$bucket_query" | grep -o '"bucket":"[^"]*"' | wc -l)
if [ "$bucket_count" -gt 0 ]; then
    echo -e "${GREEN}✓ OK (${bucket_count} buckets)${NC}"
else
    echo -e "${YELLOW}⚠ No buckets (this is normal if MinIO just started)${NC}"
fi

echo ""
echo "5. Grafana Dashboard"
echo "--------------------"
echo -n "Checking if MinIO dashboard exists... "
dashboard_search=$(curl -s -u admin:admin "${GRAFANA_URL}/api/search?query=MinIO" 2>/dev/null || echo "")
if echo "$dashboard_search" | grep -q "minio-overview"; then
    echo -e "${GREEN}✓ Found${NC}"
    echo ""
    echo "Dashboard Details:"
    echo "$dashboard_search" | grep -o '"title":"[^"]*"' | head -1
    echo "$dashboard_search" | grep -o '"url":"[^"]*"' | head -1
else
    echo -e "${YELLOW}⚠ Not found (wait 30s for auto-provisioning)${NC}"
fi

echo ""
echo "================================================"
echo "Validation Complete"
echo "================================================"
echo ""
echo "Access the dashboard at:"
echo "  ${GRAFANA_URL}/d/minio-overview"
echo ""
echo "Default credentials: admin / admin"
echo ""

