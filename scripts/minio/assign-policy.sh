#!/bin/bash
# =============================================================================
# MinIO Policy Assignment Script
# =============================================================================
# Assigns an IAM policy to a service account.
#
# Usage: ./assign-policy.sh <access-key> <policy-file>
# Example: ./assign-policy.sh AKIAIOSFODNN7EXAMPLE backup-service-policy
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
POLICY_DIR="../../docker/minio/policy-templates"

# Check arguments
if [ $# -lt 2 ]; then
    echo -e "${RED}Error: Missing arguments${NC}"
    echo "Usage: $0 <access-key> <policy-name>"
    echo ""
    echo "Available policies:"
    ls -1 ${POLICY_DIR}/*.json | xargs -n1 basename | sed 's/.json$//' | sed 's/^/  - /'
    echo ""
    echo "Example: $0 AKIAIOSFODNN7EXAMPLE backup-service-policy"
    exit 1
fi

ACCESS_KEY=$1
POLICY_NAME=$2
POLICY_FILE="${POLICY_DIR}/${POLICY_NAME}.json"

echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}MinIO Policy Assignment${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""
echo "Access Key: ${ACCESS_KEY}"
echo "Policy: ${POLICY_NAME}"
echo ""

# Check if policy file exists
if [ ! -f "${POLICY_FILE}" ]; then
    echo -e "${RED}Error: Policy file not found: ${POLICY_FILE}${NC}"
    echo ""
    echo "Available policies:"
    ls -1 ${POLICY_DIR}/*.json | xargs -n1 basename | sed 's/.json$//' | sed 's/^/  - /'
    exit 1
fi

# Configure MinIO alias
echo -e "${YELLOW}Configuring MinIO connection...${NC}"
mc alias remove ${MC_ALIAS} 2>/dev/null || true
if mc alias set ${MC_ALIAS} ${MINIO_ENDPOINT} ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD}; then
    echo -e "${GREEN}✓ Connected to MinIO${NC}"
else
    echo -e "${RED}✗ Failed to connect to MinIO${NC}"
    exit 1
fi

# Create/update policy in MinIO
echo ""
echo -e "${YELLOW}Creating/updating policy in MinIO...${NC}"
if mc admin policy create ${MC_ALIAS} ${POLICY_NAME} ${POLICY_FILE} 2>/dev/null || \
   mc admin policy update ${MC_ALIAS} ${POLICY_NAME} ${POLICY_FILE}; then
    echo -e "${GREEN}✓ Policy ${POLICY_NAME} created/updated${NC}"
else
    echo -e "${RED}✗ Failed to create/update policy${NC}"
    exit 1
fi

# Attach policy to service account
echo ""
echo -e "${YELLOW}Attaching policy to service account...${NC}"
if mc admin policy attach ${MC_ALIAS} ${POLICY_NAME} --user=${ACCESS_KEY}; then
    echo -e "${GREEN}✓ Policy attached successfully${NC}"
    echo ""
    echo -e "${GREEN}==============================================================================${NC}"
    echo -e "${GREEN}Policy Assignment Complete${NC}"
    echo -e "${GREEN}==============================================================================${NC}"
    echo ""
    echo "Service account ${ACCESS_KEY} now has the ${POLICY_NAME} policy."
    echo ""
else
    echo -e "${RED}✗ Failed to attach policy${NC}"
    exit 1
fi

