#!/bin/bash

# ============================================
# AI Infrastructure - Seed Data Script
# ============================================
# This script loads test/sample data into the database

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}AI Infrastructure - Seed Data${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Load environment variables
if [ -f "$PROJECT_DIR/.env" ]; then
    source "$PROJECT_DIR/.env"
else
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

cd "$PROJECT_DIR"

# Check if PostgreSQL is running
if ! docker-compose ps postgres | grep -q "Up"; then
    echo -e "${RED}Error: PostgreSQL is not running${NC}"
    echo "Please start the services first with: ./scripts/start.sh"
    exit 1
fi

echo -e "${YELLOW}Seeding PostgreSQL with sample data...${NC}"

# Insert sample users
docker-compose exec -T postgres psql -U "${POSTGRES_USER:-postgres}" -d "${POSTGRES_DB:-app_db}" << 'EOF'
-- Insert sample users
INSERT INTO app.users (email, username, password_hash, first_name, last_name, is_active, is_verified)
VALUES
    ('john.doe@example.com', 'johndoe', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYzj1UqHXUW', 'John', 'Doe', true, true),
    ('jane.smith@example.com', 'janesmith', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYzj1UqHXUW', 'Jane', 'Smith', true, true),
    ('admin@example.com', 'admin', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYzj1UqHXUW', 'Admin', 'User', true, true)
ON CONFLICT (email) DO NOTHING;

SELECT COUNT(*) || ' users inserted' FROM app.users;
EOF

echo -e "${GREEN}✓ Sample data seeded successfully${NC}"
echo ""
echo "Sample credentials:"
echo "  - Email: john.doe@example.com"
echo "  - Email: jane.smith@example.com"
echo "  - Email: admin@example.com"
echo "  - Password: password (hashed)"

