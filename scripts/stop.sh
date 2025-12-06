#!/bin/bash

# ============================================
# AI Infrastructure - Stop Script
# ============================================
# This script stops all Docker services

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
echo -e "${GREEN}AI Infrastructure - Stopping Services${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Parse command line arguments
REMOVE_VOLUMES=false
REMOVE_IMAGES=false
SPECIFIC_SERVICES=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --volumes|-v)
            REMOVE_VOLUMES=true
            shift
            ;;
        --images|-i)
            REMOVE_IMAGES=true
            shift
            ;;
        --clean|-c)
            REMOVE_VOLUMES=true
            REMOVE_IMAGES=true
            shift
            ;;
        --service|-s)
            SPECIFIC_SERVICES="$SPECIFIC_SERVICES $2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS] [SERVICES]"
            echo ""
            echo "Options:"
            echo "  --volumes, -v           Remove volumes (WARNING: deletes data)"
            echo "  --images, -i            Remove images"
            echo "  --clean, -c             Remove volumes and images"
            echo "  --service, -s SERVICE   Stop specific service(s)"
            echo "  --help, -h              Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                      Stop all services"
            echo "  $0 --volumes            Stop and remove volumes"
            echo "  $0 -s postgres          Stop only postgres service"
            echo "  $0 --clean              Complete cleanup (stops, removes volumes & images)"
            exit 0
            ;;
        *)
            SPECIFIC_SERVICES="$SPECIFIC_SERVICES $1"
            shift
            ;;
    esac
done

cd "$PROJECT_DIR"

# Stop services
if [ -z "$SPECIFIC_SERVICES" ]; then
    echo -e "${YELLOW}Stopping all services...${NC}"
    docker-compose down
else
    echo -e "${YELLOW}Stopping specific services: $SPECIFIC_SERVICES${NC}"
    docker-compose stop $SPECIFIC_SERVICES
fi

# Remove volumes if requested
if [ "$REMOVE_VOLUMES" = true ]; then
    echo -e "${RED}Warning: Removing volumes (this will delete all data)${NC}"
    read -p "Are you sure? (yes/no): " -r
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo -e "${YELLOW}Removing volumes...${NC}"
        docker-compose down -v
        echo -e "${GREEN}Volumes removed${NC}"
    else
        echo -e "${YELLOW}Volume removal cancelled${NC}"
    fi
fi

# Remove images if requested
if [ "$REMOVE_IMAGES" = true ]; then
    echo -e "${YELLOW}Removing images...${NC}"
    docker-compose down --rmi local
    echo -e "${GREEN}Images removed${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Services stopped successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Show remaining containers
REMAINING=$(docker-compose ps -q 2>/dev/null | wc -l | tr -d ' ')
if [ "$REMAINING" -gt 0 ]; then
    echo -e "${YELLOW}Remaining containers:${NC}"
    docker-compose ps
fi

