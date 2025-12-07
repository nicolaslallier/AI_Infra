#!/bin/bash
# =============================================================================
# MinIO Bucket Initialization Script
# =============================================================================
# This script initializes MinIO buckets with appropriate policies and settings.
# It should be run after MinIO cluster is up and running.
#
# Usage: ./init-buckets.sh
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
echo -e "${GREEN}MinIO Bucket Initialization${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""

# Function to check if mc (MinIO Client) is installed
check_mc_installed() {
    if ! command -v mc &> /dev/null; then
        echo -e "${RED}Error: MinIO Client (mc) is not installed.${NC}"
        echo "Please install it from: https://min.io/docs/minio/linux/reference/minio-mc.html"
        echo ""
        echo "Quick install:"
        echo "  wget https://dl.min.io/client/mc/release/linux-amd64/mc"
        echo "  chmod +x mc"
        echo "  sudo mv mc /usr/local/bin/"
        exit 1
    fi
    echo -e "${GREEN}✓ MinIO Client (mc) is installed${NC}"
}

# Function to configure MinIO alias
configure_alias() {
    echo ""
    echo -e "${YELLOW}Configuring MinIO alias: ${MC_ALIAS}${NC}"
    
    # Remove existing alias if it exists
    mc alias remove ${MC_ALIAS} 2>/dev/null || true
    
    # Add new alias
    if mc alias set ${MC_ALIAS} ${MINIO_ENDPOINT} ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD}; then
        echo -e "${GREEN}✓ MinIO alias configured successfully${NC}"
    else
        echo -e "${RED}✗ Failed to configure MinIO alias${NC}"
        echo "Please check that MinIO is running and accessible at: ${MINIO_ENDPOINT}"
        exit 1
    fi
}

# Function to create a bucket
create_bucket() {
    local bucket_name=$1
    local description=$2
    
    echo ""
    echo -e "${YELLOW}Creating bucket: ${bucket_name}${NC}"
    echo "  Description: ${description}"
    
    if mc ls ${MC_ALIAS}/${bucket_name} &>/dev/null; then
        echo -e "${GREEN}✓ Bucket ${bucket_name} already exists${NC}"
    else
        if mc mb ${MC_ALIAS}/${bucket_name}; then
            echo -e "${GREEN}✓ Bucket ${bucket_name} created successfully${NC}"
        else
            echo -e "${RED}✗ Failed to create bucket ${bucket_name}${NC}"
            return 1
        fi
    fi
}

# Function to set bucket lifecycle policy
set_lifecycle_policy() {
    local bucket_name=$1
    local retention_days=$2
    
    echo "  Setting ${retention_days}-day retention policy..."
    
    # Create lifecycle JSON configuration
    cat > /tmp/lifecycle-${bucket_name}.json <<EOF
{
    "Rules": [
        {
            "ID": "DeleteOldObjects",
            "Status": "Enabled",
            "Expiration": {
                "Days": ${retention_days}
            }
        }
    ]
}
EOF
    
    if mc ilm import ${MC_ALIAS}/${bucket_name} < /tmp/lifecycle-${bucket_name}.json; then
        echo -e "${GREEN}  ✓ Lifecycle policy applied${NC}"
        rm /tmp/lifecycle-${bucket_name}.json
    else
        echo -e "${RED}  ✗ Failed to apply lifecycle policy${NC}"
        rm /tmp/lifecycle-${bucket_name}.json
        return 1
    fi
}

# Function to set bucket quota (optional)
set_bucket_quota() {
    local bucket_name=$1
    local quota_gb=$2
    
    if [ -n "$quota_gb" ]; then
        echo "  Setting ${quota_gb}GB quota..."
        if mc quota set ${MC_ALIAS}/${bucket_name} --size ${quota_gb}GB; then
            echo -e "${GREEN}  ✓ Quota applied${NC}"
        else
            echo -e "${YELLOW}  ⚠ Failed to apply quota (may not be supported in this MinIO version)${NC}"
        fi
    fi
}

# Main execution
main() {
    echo "Endpoint: ${MINIO_ENDPOINT}"
    echo ""
    
    # Check prerequisites
    check_mc_installed
    
    # Configure MinIO alias
    configure_alias
    
    # Create buckets
    echo ""
    echo -e "${GREEN}==============================================================================${NC}"
    echo -e "${GREEN}Creating Buckets${NC}"
    echo -e "${GREEN}==============================================================================${NC}"
    
    # PostgreSQL Backup Bucket
    create_bucket "backups-postgresql" "PostgreSQL database backups"
    set_lifecycle_policy "backups-postgresql" 30
    
    # Optional: Create other buckets (commented out for initial setup)
    # Uncomment as needed
    
    # create_bucket "logs-exports" "Exported logs from monitoring stack"
    # set_lifecycle_policy "logs-exports" 90
    
    # create_bucket "app-files" "Application file storage"
    # # No lifecycle policy for app-files (persistent storage)
    
    # create_bucket "temp-uploads" "Temporary file upload zone"
    # set_lifecycle_policy "temp-uploads" 7
    
    echo ""
    echo -e "${GREEN}==============================================================================${NC}"
    echo -e "${GREEN}Bucket Initialization Complete${NC}"
    echo -e "${GREEN}==============================================================================${NC}"
    echo ""
    echo "Summary:"
    mc ls ${MC_ALIAS}
    echo ""
    echo -e "${GREEN}✓ All buckets initialized successfully${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Create service accounts: ./create-service-account.sh <name>"
    echo "  2. Assign policies: ./assign-policy.sh <account> <policy>"
    echo "  3. Configure applications with S3 credentials"
}

# Run main function
main

