#!/bin/bash
# =============================================================================
# MinIO Bucket Creation Script
# =============================================================================
# Creates a new bucket with optional lifecycle policy.
#
# Usage: ./create-bucket.sh <bucket-name> [retention-days]
# Example: ./create-bucket.sh app-files
# Example: ./create-bucket.sh temp-data 7
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

# Check arguments
if [ $# -lt 1 ]; then
    echo -e "${RED}Error: Missing bucket name${NC}"
    echo "Usage: $0 <bucket-name> [retention-days]"
    echo "Example: $0 app-files"
    echo "Example: $0 temp-data 7"
    exit 1
fi

BUCKET_NAME=$1
RETENTION_DAYS=${2:-}

echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}MinIO Bucket Creation${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""
echo "Bucket Name: ${BUCKET_NAME}"
if [ -n "${RETENTION_DAYS}" ]; then
    echo "Retention: ${RETENTION_DAYS} days"
else
    echo "Retention: None (permanent storage)"
fi
echo ""

# Configure MinIO alias
echo -e "${YELLOW}Configuring MinIO connection...${NC}"
mc alias remove ${MC_ALIAS} 2>/dev/null || true
if mc alias set ${MC_ALIAS} ${MINIO_ENDPOINT} ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD}; then
    echo -e "${GREEN}✓ Connected to MinIO${NC}"
else
    echo -e "${RED}✗ Failed to connect to MinIO${NC}"
    exit 1
fi

# Create bucket
echo ""
echo -e "${YELLOW}Creating bucket...${NC}"
if mc ls ${MC_ALIAS}/${BUCKET_NAME} &>/dev/null; then
    echo -e "${YELLOW}⚠ Bucket ${BUCKET_NAME} already exists${NC}"
else
    if mc mb ${MC_ALIAS}/${BUCKET_NAME}; then
        echo -e "${GREEN}✓ Bucket ${BUCKET_NAME} created successfully${NC}"
    else
        echo -e "${RED}✗ Failed to create bucket${NC}"
        exit 1
    fi
fi

# Apply lifecycle policy if retention days specified
if [ -n "${RETENTION_DAYS}" ]; then
    echo ""
    echo -e "${YELLOW}Applying lifecycle policy...${NC}"
    
    # Create lifecycle JSON configuration
    cat > /tmp/lifecycle-${BUCKET_NAME}.json <<EOF
{
    "Rules": [
        {
            "ID": "DeleteOldObjects",
            "Status": "Enabled",
            "Expiration": {
                "Days": ${RETENTION_DAYS}
            }
        }
    ]
}
EOF
    
    if mc ilm import ${MC_ALIAS}/${BUCKET_NAME} < /tmp/lifecycle-${BUCKET_NAME}.json; then
        echo -e "${GREEN}✓ Lifecycle policy applied (${RETENTION_DAYS} days retention)${NC}"
        rm /tmp/lifecycle-${BUCKET_NAME}.json
    else
        echo -e "${RED}✗ Failed to apply lifecycle policy${NC}"
        rm /tmp/lifecycle-${BUCKET_NAME}.json
    fi
fi

echo ""
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}Bucket Creation Complete${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""
echo "Bucket ${BUCKET_NAME} is ready to use."
echo ""
echo "Next steps:"
echo "  1. Create service account: ./create-service-account.sh ${BUCKET_NAME}-service"
echo "  2. Assign policy: ./assign-policy.sh <access-key> <policy-name>"
echo ""

