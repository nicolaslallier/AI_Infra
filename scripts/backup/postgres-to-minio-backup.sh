#!/bin/bash
# =============================================================================
# PostgreSQL to MinIO Backup Script
# =============================================================================
# Automated PostgreSQL backup script that uploads to MinIO S3-compatible storage.
# This script performs:
#   1. PostgreSQL database dump using pg_dump
#   2. Compression with gzip
#   3. Upload to MinIO bucket
#   4. Cleanup of old local files
#
# Usage: ./postgres-to-minio-backup.sh [database-name]
# Example: ./postgres-to-minio-backup.sh app_db
#
# Environment Variables:
#   POSTGRES_HOST - PostgreSQL host (default: postgres)
#   POSTGRES_PORT - PostgreSQL port (default: 5432)
#   POSTGRES_USER - PostgreSQL user (default: postgres)
#   POSTGRES_PASSWORD - PostgreSQL password (required)
#   POSTGRES_DB - Database to backup (default: app_db)
#   MINIO_ENDPOINT - MinIO endpoint (default: http://localhost/storage)
#   MINIO_ACCESS_KEY - MinIO access key (required)
#   MINIO_SECRET_KEY - MinIO secret key (required)
#   MINIO_BUCKET - MinIO bucket name (default: backups-postgresql)
#   BACKUP_RETENTION_DAYS - Days to keep local backups (default: 7)
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration from environment variables
POSTGRES_HOST="${POSTGRES_HOST:-postgres}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD}"
POSTGRES_DB="${1:-${POSTGRES_DB:-app_db}}"

MINIO_ENDPOINT="${MINIO_ENDPOINT:-http://localhost/storage}"
MINIO_ACCESS_KEY="${MINIO_ACCESS_KEY}"
MINIO_SECRET_KEY="${MINIO_SECRET_KEY}"
MINIO_BUCKET="${MINIO_BUCKET:-backups-postgresql}"
MC_ALIAS="backup-minio"

BACKUP_DIR="${BACKUP_DIR:-/tmp/postgres-backups}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_FILENAME="postgres_backup_${POSTGRES_DB}_${TIMESTAMP}.sql.gz"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_FILENAME}"

echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}PostgreSQL to MinIO Backup${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""
echo "Timestamp: ${TIMESTAMP}"
echo "Database: ${POSTGRES_DB}"
echo "Host: ${POSTGRES_HOST}:${POSTGRES_PORT}"
echo "Backup file: ${BACKUP_FILENAME}"
echo "Destination: s3://${MINIO_BUCKET}/${BACKUP_FILENAME}"
echo ""

# Validate required environment variables
check_requirements() {
    local missing_vars=()
    
    if [ -z "${POSTGRES_PASSWORD}" ]; then
        missing_vars+=("POSTGRES_PASSWORD")
    fi
    
    if [ -z "${MINIO_ACCESS_KEY}" ]; then
        missing_vars+=("MINIO_ACCESS_KEY")
    fi
    
    if [ -z "${MINIO_SECRET_KEY}" ]; then
        missing_vars+=("MINIO_SECRET_KEY")
    fi
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo -e "${RED}Error: Missing required environment variables:${NC}"
        for var in "${missing_vars[@]}"; do
            echo "  - ${var}"
        done
        echo ""
        echo "Please set these variables before running the script."
        exit 1
    fi
    
    # Check if pg_dump is available
    if ! command -v pg_dump &> /dev/null; then
        echo -e "${RED}Error: pg_dump not found${NC}"
        echo "Please install PostgreSQL client tools."
        exit 1
    fi
    
    # Check if mc (MinIO Client) is available
    if ! command -v mc &> /dev/null; then
        echo -e "${RED}Error: MinIO Client (mc) not found${NC}"
        echo "Please install from: https://min.io/docs/minio/linux/reference/minio-mc.html"
        exit 1
    fi
    
    echo -e "${GREEN}✓ All requirements satisfied${NC}"
}

# Create backup directory
create_backup_dir() {
    echo ""
    echo -e "${YELLOW}Creating backup directory...${NC}"
    mkdir -p "${BACKUP_DIR}"
    echo -e "${GREEN}✓ Backup directory ready: ${BACKUP_DIR}${NC}"
}

# Perform PostgreSQL backup
backup_database() {
    echo ""
    echo -e "${YELLOW}Starting database backup...${NC}"
    echo "  This may take a while for large databases..."
    
    export PGPASSWORD="${POSTGRES_PASSWORD}"
    
    if pg_dump -h "${POSTGRES_HOST}" \
               -p "${POSTGRES_PORT}" \
               -U "${POSTGRES_USER}" \
               -d "${POSTGRES_DB}" \
               --format=plain \
               --no-owner \
               --no-acl \
               --verbose \
               2>&1 | gzip > "${BACKUP_PATH}"; then
        
        local backup_size=$(du -h "${BACKUP_PATH}" | cut -f1)
        echo -e "${GREEN}✓ Database backup completed${NC}"
        echo "  File: ${BACKUP_PATH}"
        echo "  Size: ${backup_size}"
    else
        echo -e "${RED}✗ Database backup failed${NC}"
        rm -f "${BACKUP_PATH}"
        exit 1
    fi
    
    unset PGPASSWORD
}

# Configure MinIO client
configure_minio() {
    echo ""
    echo -e "${YELLOW}Configuring MinIO connection...${NC}"
    
    # Remove existing alias
    mc alias remove ${MC_ALIAS} 2>/dev/null || true
    
    # Add MinIO alias with service account credentials
    if mc alias set ${MC_ALIAS} \
                    "${MINIO_ENDPOINT}" \
                    "${MINIO_ACCESS_KEY}" \
                    "${MINIO_SECRET_KEY}"; then
        echo -e "${GREEN}✓ MinIO connection configured${NC}"
    else
        echo -e "${RED}✗ Failed to configure MinIO connection${NC}"
        exit 1
    fi
}

# Upload backup to MinIO
upload_to_minio() {
    echo ""
    echo -e "${YELLOW}Uploading backup to MinIO...${NC}"
    
    # Check if bucket exists
    if ! mc ls ${MC_ALIAS}/${MINIO_BUCKET} &>/dev/null; then
        echo -e "${YELLOW}⚠ Bucket ${MINIO_BUCKET} not found, creating...${NC}"
        if mc mb ${MC_ALIAS}/${MINIO_BUCKET}; then
            echo -e "${GREEN}✓ Bucket created${NC}"
        else
            echo -e "${RED}✗ Failed to create bucket${NC}"
            exit 1
        fi
    fi
    
    # Upload file
    if mc cp "${BACKUP_PATH}" "${MC_ALIAS}/${MINIO_BUCKET}/${BACKUP_FILENAME}"; then
        echo -e "${GREEN}✓ Backup uploaded successfully${NC}"
        echo "  Location: s3://${MINIO_BUCKET}/${BACKUP_FILENAME}"
        
        # Verify upload
        if mc stat ${MC_ALIAS}/${MINIO_BUCKET}/${BACKUP_FILENAME} &>/dev/null; then
            echo -e "${GREEN}✓ Upload verified${NC}"
        else
            echo -e "${RED}✗ Upload verification failed${NC}"
            exit 1
        fi
    else
        echo -e "${RED}✗ Upload failed${NC}"
        exit 1
    fi
}

# Cleanup old local backups
cleanup_old_backups() {
    echo ""
    echo -e "${YELLOW}Cleaning up old local backups...${NC}"
    echo "  Retention period: ${BACKUP_RETENTION_DAYS} days"
    
    local deleted_count=0
    while IFS= read -r -d '' backup_file; do
        rm -f "${backup_file}"
        ((deleted_count++))
        echo "  Deleted: $(basename ${backup_file})"
    done < <(find "${BACKUP_DIR}" -name "postgres_backup_*.sql.gz" -type f -mtime +${BACKUP_RETENTION_DAYS} -print0)
    
    if [ ${deleted_count} -gt 0 ]; then
        echo -e "${GREEN}✓ Cleaned up ${deleted_count} old backup(s)${NC}"
    else
        echo -e "${GREEN}✓ No old backups to clean up${NC}"
    fi
}

# List recent backups in MinIO
list_backups() {
    echo ""
    echo -e "${YELLOW}Recent backups in MinIO:${NC}"
    mc ls ${MC_ALIAS}/${MINIO_BUCKET} | grep "postgres_backup_" | tail -5
}

# Main execution
main() {
    local start_time=$(date +%s)
    
    check_requirements
    create_backup_dir
    backup_database
    configure_minio
    upload_to_minio
    cleanup_old_backups
    list_backups
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    echo -e "${GREEN}==============================================================================${NC}"
    echo -e "${GREEN}Backup Complete${NC}"
    echo -e "${GREEN}==============================================================================${NC}"
    echo ""
    echo "Duration: ${duration} seconds"
    echo "Local backup: ${BACKUP_PATH}"
    echo "Remote backup: s3://${MINIO_BUCKET}/${BACKUP_FILENAME}"
    echo ""
    echo -e "${GREEN}✓ PostgreSQL backup completed successfully${NC}"
    echo ""
}

# Trap errors and cleanup
trap 'echo -e "${RED}✗ Backup failed${NC}"; exit 1' ERR

# Run main function
main

