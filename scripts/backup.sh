#!/bin/bash

# ============================================
# AI Infrastructure - Backup Script
# ============================================
# This script backs up PostgreSQL database and application data

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_DIR/backups"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}AI Infrastructure - Backup Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Load environment variables
if [ -f "$PROJECT_DIR/.env" ]; then
    source "$PROJECT_DIR/.env"
else
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Generate timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Parse command line arguments
BACKUP_POSTGRES=true
BACKUP_REDIS=true
BACKUP_ELASTICSEARCH=false
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-7}

while [[ $# -gt 0 ]]; do
    case $1 in
        --postgres-only)
            BACKUP_REDIS=false
            BACKUP_ELASTICSEARCH=false
            shift
            ;;
        --redis-only)
            BACKUP_POSTGRES=false
            BACKUP_ELASTICSEARCH=false
            shift
            ;;
        --all)
            BACKUP_POSTGRES=true
            BACKUP_REDIS=true
            BACKUP_ELASTICSEARCH=true
            shift
            ;;
        --retention)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --postgres-only         Backup PostgreSQL only"
            echo "  --redis-only            Backup Redis only"
            echo "  --all                   Backup all services including Elasticsearch"
            echo "  --retention DAYS        Keep backups for N days (default: 7)"
            echo "  --help, -h              Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                      Backup PostgreSQL and Redis"
            echo "  $0 --all                Backup all services"
            echo "  $0 --postgres-only      Backup only PostgreSQL"
            echo "  $0 --retention 30       Keep backups for 30 days"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

cd "$PROJECT_DIR"

# Check if services are running
if ! docker-compose ps | grep -q "Up"; then
    echo -e "${RED}Error: No services are running${NC}"
    echo "Please start the services first with: ./scripts/start.sh"
    exit 1
fi

# Backup PostgreSQL
if [ "$BACKUP_POSTGRES" = true ]; then
    echo -e "${YELLOW}Backing up PostgreSQL...${NC}"
    POSTGRES_BACKUP_FILE="$BACKUP_DIR/postgres_backup_$TIMESTAMP.sql.gz"
    
    docker-compose exec -T postgres pg_dump \
        -U "${POSTGRES_USER:-postgres}" \
        -d "${POSTGRES_DB:-app_db}" \
        --clean --if-exists \
        | gzip > "$POSTGRES_BACKUP_FILE"
    
    if [ -f "$POSTGRES_BACKUP_FILE" ]; then
        BACKUP_SIZE=$(du -h "$POSTGRES_BACKUP_FILE" | cut -f1)
        echo -e "${GREEN}✓ PostgreSQL backup completed: $POSTGRES_BACKUP_FILE ($BACKUP_SIZE)${NC}"
    else
        echo -e "${RED}✗ PostgreSQL backup failed${NC}"
    fi
fi

# Backup Redis
if [ "$BACKUP_REDIS" = true ]; then
    echo -e "${YELLOW}Backing up Redis...${NC}"
    REDIS_BACKUP_FILE="$BACKUP_DIR/redis_backup_$TIMESTAMP.rdb"
    
    # Trigger Redis save
    docker-compose exec -T redis redis-cli SAVE > /dev/null
    
    # Copy Redis dump
    docker-compose cp redis:/data/dump.rdb "$REDIS_BACKUP_FILE"
    
    if [ -f "$REDIS_BACKUP_FILE" ]; then
        BACKUP_SIZE=$(du -h "$REDIS_BACKUP_FILE" | cut -f1)
        echo -e "${GREEN}✓ Redis backup completed: $REDIS_BACKUP_FILE ($BACKUP_SIZE)${NC}"
    else
        echo -e "${RED}✗ Redis backup failed${NC}"
    fi
fi

# Backup Elasticsearch (optional)
if [ "$BACKUP_ELASTICSEARCH" = true ]; then
    echo -e "${YELLOW}Backing up Elasticsearch...${NC}"
    ES_BACKUP_DIR="$BACKUP_DIR/elasticsearch_$TIMESTAMP"
    mkdir -p "$ES_BACKUP_DIR"
    
    # Create Elasticsearch snapshot (requires repository setup)
    echo -e "${YELLOW}Note: Elasticsearch backup requires snapshot repository configuration${NC}"
    echo -e "${YELLOW}See: https://www.elastic.co/guide/en/elasticsearch/reference/current/snapshot-restore.html${NC}"
    
    # For now, just backup the indices list and settings
    curl -s -u "elastic:${ELASTIC_PASSWORD:-elastic}" \
        "http://localhost:${ELASTICSEARCH_PORT:-9200}/_cat/indices?v" \
        > "$ES_BACKUP_DIR/indices.txt"
    
    echo -e "${GREEN}✓ Elasticsearch metadata backed up: $ES_BACKUP_DIR${NC}"
fi

# Create backup manifest
MANIFEST_FILE="$BACKUP_DIR/backup_manifest_$TIMESTAMP.txt"
cat > "$MANIFEST_FILE" << EOF
AI Infrastructure Backup
========================
Timestamp: $(date)
Hostname: $(hostname)

Backup Files:
EOF

if [ "$BACKUP_POSTGRES" = true ] && [ -f "$POSTGRES_BACKUP_FILE" ]; then
    echo "- PostgreSQL: $(basename $POSTGRES_BACKUP_FILE)" >> "$MANIFEST_FILE"
fi

if [ "$BACKUP_REDIS" = true ] && [ -f "$REDIS_BACKUP_FILE" ]; then
    echo "- Redis: $(basename $REDIS_BACKUP_FILE)" >> "$MANIFEST_FILE"
fi

if [ "$BACKUP_ELASTICSEARCH" = true ]; then
    echo "- Elasticsearch: $(basename $ES_BACKUP_DIR)" >> "$MANIFEST_FILE"
fi

echo -e "${GREEN}✓ Backup manifest created: $MANIFEST_FILE${NC}"

# Cleanup old backups
echo ""
echo -e "${YELLOW}Cleaning up old backups (older than $RETENTION_DAYS days)...${NC}"
find "$BACKUP_DIR" -type f -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete
find "$BACKUP_DIR" -type f -name "*.rdb" -mtime +$RETENTION_DAYS -delete
find "$BACKUP_DIR" -type f -name "backup_manifest_*.txt" -mtime +$RETENTION_DAYS -delete
find "$BACKUP_DIR" -type d -name "elasticsearch_*" -mtime +$RETENTION_DAYS -exec rm -rf {} + 2>/dev/null || true
echo -e "${GREEN}✓ Cleanup completed${NC}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Backup completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Backup location: $BACKUP_DIR"
echo "Manifest: $MANIFEST_FILE"
echo ""
echo "To restore:"
echo "  PostgreSQL: gunzip < $POSTGRES_BACKUP_FILE | docker-compose exec -T postgres psql -U postgres -d app_db"
echo "  Redis: docker-compose cp $REDIS_BACKUP_FILE redis:/data/dump.rdb && docker-compose restart redis"

