#!/bin/bash
# =============================================================================
# PostgreSQL Restore from MinIO Script
# =============================================================================
# Restores a PostgreSQL database from a backup stored in MinIO.
#
# Usage: ./restore-from-minio.sh <backup-filename> [database-name]
# Example: ./restore-from-minio.sh postgres_backup_app_db_2024-01-15_10-30-00.sql.gz
# Example: ./restore-from-minio.sh postgres_backup_app_db_2024-01-15_10-30-00.sql.gz app_db
#
# Environment Variables:
#   POSTGRES_HOST - PostgreSQL host (default: postgres)
#   POSTGRES_PORT - PostgreSQL port (default: 5432)
#   POSTGRES_USER - PostgreSQL user (default: postgres)
#   POSTGRES_PASSWORD - PostgreSQL password (required)
#   POSTGRES_DB - Database to restore (default: app_db)
#   MINIO_ENDPOINT - MinIO endpoint (default: http://localhost/storage)
#   MINIO_ACCESS_KEY - MinIO access key (required)
#   MINIO_SECRET_KEY - MinIO secret key (required)
#   MINIO_BUCKET - MinIO bucket name (default: backups-postgresql)
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check arguments
if [ $# -lt 1 ]; then
    echo -e "${RED}Error: Missing backup filename${NC}"
    echo "Usage: $0 <backup-filename> [database-name]"
    echo ""
    echo "To list available backups, run:"
    echo "  mc ls backup-minio/backups-postgresql"
    exit 1
fi

# Configuration
BACKUP_FILENAME=$1
POSTGRES_DB="${2:-${POSTGRES_DB:-app_db}}"

POSTGRES_HOST="${POSTGRES_HOST:-postgres}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD}"

MINIO_ENDPOINT="${MINIO_ENDPOINT:-http://localhost/storage}"
MINIO_ACCESS_KEY="${MINIO_ACCESS_KEY}"
MINIO_SECRET_KEY="${MINIO_SECRET_KEY}"
MINIO_BUCKET="${MINIO_BUCKET:-backups-postgresql}"
MC_ALIAS="backup-minio"

RESTORE_DIR="${RESTORE_DIR:-/tmp/postgres-restores}"
RESTORE_PATH="${RESTORE_DIR}/${BACKUP_FILENAME}"

echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}PostgreSQL Restore from MinIO${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""
echo -e "${YELLOW}⚠ WARNING: This will overwrite the database: ${POSTGRES_DB}${NC}"
echo ""
echo "Backup file: ${BACKUP_FILENAME}"
echo "Database: ${POSTGRES_DB}"
echo "Host: ${POSTGRES_HOST}:${POSTGRES_PORT}"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Restore cancelled."
    exit 0
fi

# Validate requirements
check_requirements() {
    echo ""
    echo -e "${YELLOW}Checking requirements...${NC}"
    
    if [ -z "${POSTGRES_PASSWORD}" ]; then
        echo -e "${RED}Error: POSTGRES_PASSWORD not set${NC}"
        exit 1
    fi
    
    if [ -z "${MINIO_ACCESS_KEY}" ] || [ -z "${MINIO_SECRET_KEY}" ]; then
        echo -e "${RED}Error: MinIO credentials not set${NC}"
        exit 1
    fi
    
    if ! command -v psql &> /dev/null; then
        echo -e "${RED}Error: psql not found${NC}"
        exit 1
    fi
    
    if ! command -v mc &> /dev/null; then
        echo -e "${RED}Error: MinIO Client (mc) not found${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Requirements satisfied${NC}"
}

# Configure MinIO
configure_minio() {
    echo ""
    echo -e "${YELLOW}Configuring MinIO...${NC}"
    
    mc alias remove ${MC_ALIAS} 2>/dev/null || true
    
    if mc alias set ${MC_ALIAS} "${MINIO_ENDPOINT}" "${MINIO_ACCESS_KEY}" "${MINIO_SECRET_KEY}"; then
        echo -e "${GREEN}✓ MinIO configured${NC}"
    else
        echo -e "${RED}✗ Failed to configure MinIO${NC}"
        exit 1
    fi
}

# Download backup from MinIO
download_backup() {
    echo ""
    echo -e "${YELLOW}Downloading backup from MinIO...${NC}"
    
    mkdir -p "${RESTORE_DIR}"
    
    if mc cp "${MC_ALIAS}/${MINIO_BUCKET}/${BACKUP_FILENAME}" "${RESTORE_PATH}"; then
        local file_size=$(du -h "${RESTORE_PATH}" | cut -f1)
        echo -e "${GREEN}✓ Backup downloaded${NC}"
        echo "  File: ${RESTORE_PATH}"
        echo "  Size: ${file_size}"
    else
        echo -e "${RED}✗ Download failed${NC}"
        exit 1
    fi
}

# Restore database
restore_database() {
    echo ""
    echo -e "${YELLOW}Restoring database...${NC}"
    echo "  This may take a while for large databases..."
    
    export PGPASSWORD="${POSTGRES_PASSWORD}"
    
    # Drop existing connections to the database
    psql -h "${POSTGRES_HOST}" \
         -p "${POSTGRES_PORT}" \
         -U "${POSTGRES_USER}" \
         -d postgres \
         -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${POSTGRES_DB}' AND pid <> pg_backend_pid();" \
         2>/dev/null || true
    
    # Restore the database
    if gunzip -c "${RESTORE_PATH}" | \
       psql -h "${POSTGRES_HOST}" \
            -p "${POSTGRES_PORT}" \
            -U "${POSTGRES_USER}" \
            -d "${POSTGRES_DB}" \
            --single-transaction \
            2>&1; then
        echo -e "${GREEN}✓ Database restored successfully${NC}"
    else
        echo -e "${RED}✗ Restore failed${NC}"
        exit 1
    fi
    
    unset PGPASSWORD
}

# Cleanup
cleanup() {
    echo ""
    echo -e "${YELLOW}Cleaning up...${NC}"
    rm -f "${RESTORE_PATH}"
    echo -e "${GREEN}✓ Temporary files removed${NC}"
}

# Main execution
main() {
    local start_time=$(date +%s)
    
    check_requirements
    configure_minio
    download_backup
    restore_database
    cleanup
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    echo -e "${GREEN}==============================================================================${NC}"
    echo -e "${GREEN}Restore Complete${NC}"
    echo -e "${GREEN}==============================================================================${NC}"
    echo ""
    echo "Duration: ${duration} seconds"
    echo "Database: ${POSTGRES_DB}"
    echo ""
    echo -e "${GREEN}✓ Database restored successfully from MinIO backup${NC}"
    echo ""
}

# Run main
main

