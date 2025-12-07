#!/bin/bash
# =============================================================================
# MinIO Service Account Creation Script
# =============================================================================
# Creates a service account with access key and secret for application use.
#
# Usage: ./create-service-account.sh <account-name>
# Example: ./create-service-account.sh backup-service
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
    echo -e "${RED}Error: Missing account name${NC}"
    echo "Usage: $0 <account-name>"
    echo "Example: $0 backup-service"
    exit 1
fi

ACCOUNT_NAME=$1

echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}MinIO Service Account Creation${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""
echo "Account Name: ${ACCOUNT_NAME}"
echo "Endpoint: ${MINIO_ENDPOINT}"
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

# Create service account
echo ""
echo -e "${YELLOW}Creating service account...${NC}"

OUTPUT=$(mc admin user svcacct add ${MC_ALIAS} ${MINIO_ROOT_USER} --name ${ACCOUNT_NAME} 2>&1)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Service account created successfully${NC}"
    echo ""
    echo -e "${GREEN}==============================================================================${NC}"
    echo -e "${GREEN}Service Account Credentials${NC}"
    echo -e "${GREEN}==============================================================================${NC}"
    echo ""
    echo "${OUTPUT}"
    echo ""
    echo -e "${YELLOW}⚠ IMPORTANT: Save these credentials securely!${NC}"
    echo "These credentials will not be shown again."
    echo ""
    echo "Next steps:"
    echo "  1. Assign a policy: ./assign-policy.sh ${ACCOUNT_NAME} <policy-name>"
    echo "  2. Add credentials to your application's .env file"
    echo ""
else
    echo -e "${RED}✗ Failed to create service account${NC}"
    echo "${OUTPUT}"
    exit 1
fi

