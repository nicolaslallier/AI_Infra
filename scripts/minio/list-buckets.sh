#!/bin/bash
# =============================================================================
# MinIO Bucket Listing Script
# =============================================================================
# Lists all buckets with their metadata and statistics.
#
# Usage: ./list-buckets.sh
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
MINIO_ENDPOINT="${MINIO_ENDPOINT:-http://localhost/storage}"
MINIO_ROOT_USER="${MINIO_ROOT_USER:-admin}"
MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:-changeme123}"
MC_ALIAS="ai-infra"

echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}MinIO Buckets${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""

# Configure MinIO alias
mc alias remove ${MC_ALIAS} 2>/dev/null || true
if ! mc alias set ${MC_ALIAS} ${MINIO_ENDPOINT} ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD} &>/dev/null; then
    echo -e "${RED}✗ Failed to connect to MinIO${NC}"
    echo "Endpoint: ${MINIO_ENDPOINT}"
    exit 1
fi

# List buckets
echo -e "${YELLOW}Listing buckets...${NC}"
echo ""
mc ls ${MC_ALIAS}
echo ""

# Get bucket details
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}Bucket Details${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""

for bucket in $(mc ls ${MC_ALIAS} | awk '{print $NF}' | sed 's/\///'); do
    echo -e "${YELLOW}Bucket: ${bucket}${NC}"
    
    # Get bucket size and object count
    STATS=$(mc du ${MC_ALIAS}/${bucket} 2>/dev/null | tail -1)
    echo "  Size: $(echo ${STATS} | awk '{print $1, $2}')"
    echo "  Objects: $(echo ${STATS} | awk '{print $3}')"
    
    # Get lifecycle policy if exists
    if mc ilm export ${MC_ALIAS}/${bucket} &>/dev/null; then
        echo "  Lifecycle: Configured"
        mc ilm export ${MC_ALIAS}/${bucket} | grep -A2 "Expiration" | grep "Days" | sed 's/^/  /'
    else
        echo "  Lifecycle: Not configured"
    fi
    
    echo ""
done

echo -e "${GREEN}==============================================================================${NC}"

