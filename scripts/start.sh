#!/bin/bash

# ============================================
# AI Infrastructure - Start Script
# ============================================
# This script starts all Docker services

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
echo -e "${GREEN}AI Infrastructure - Starting Services${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running${NC}"
    echo "Please start Docker and try again"
    exit 1
fi

# Check if .env file exists
if [ ! -f "$PROJECT_DIR/.env" ]; then
    echo -e "${YELLOW}Warning: .env file not found${NC}"
    echo "Creating .env from .env.example..."
    cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
    echo -e "${GREEN}.env file created${NC}"
    echo -e "${YELLOW}Please review and update the .env file with your configuration${NC}"
    echo ""
fi

# Parse command line arguments
ENVIRONMENT="dev"
BUILD=false
DETACHED=true
SPECIFIC_SERVICES=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --prod|--production)
            ENVIRONMENT="prod"
            shift
            ;;
        --build)
            BUILD=true
            shift
            ;;
        --foreground|-f)
            DETACHED=false
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
            echo "  --prod, --production    Start in production mode"
            echo "  --build                 Rebuild images before starting"
            echo "  --foreground, -f        Run in foreground (show logs)"
            echo "  --service, -s SERVICE   Start specific service(s)"
            echo "  --help, -h              Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                      Start all services in development mode"
            echo "  $0 --build              Rebuild and start all services"
            echo "  $0 -s postgres redis    Start only postgres and redis"
            echo "  $0 --prod               Start in production mode"
            exit 0
            ;;
        *)
            SPECIFIC_SERVICES="$SPECIFIC_SERVICES $1"
            shift
            ;;
    esac
done

# Determine docker-compose files
COMPOSE_FILES="-f $PROJECT_DIR/docker-compose.yml"
if [ "$ENVIRONMENT" == "dev" ]; then
    COMPOSE_FILES="$COMPOSE_FILES -f $PROJECT_DIR/docker-compose.dev.yml"
    echo -e "${YELLOW}Environment: Development${NC}"
else
    echo -e "${YELLOW}Environment: Production${NC}"
fi

# Build option
BUILD_FLAG=""
if [ "$BUILD" = true ]; then
    echo -e "${YELLOW}Building images...${NC}"
    BUILD_FLAG="--build"
fi

# Detached option
DETACHED_FLAG="-d"
if [ "$DETACHED" = false ]; then
    DETACHED_FLAG=""
fi

# Create necessary directories
echo -e "${YELLOW}Creating necessary directories...${NC}"
mkdir -p "$PROJECT_DIR/logs"
mkdir -p "$PROJECT_DIR/backups"

# Start services
echo -e "${YELLOW}Starting Docker services...${NC}"
cd "$PROJECT_DIR"

if [ -z "$SPECIFIC_SERVICES" ]; then
    # Start all services
    docker-compose $COMPOSE_FILES up $DETACHED_FLAG $BUILD_FLAG
else
    # Start specific services
    docker-compose $COMPOSE_FILES up $DETACHED_FLAG $BUILD_FLAG $SPECIFIC_SERVICES
fi

if [ "$DETACHED" = true ]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Services started successfully!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Service URLs:"
    echo "  - Grafana:      http://localhost:3000 (admin/admin)"
    echo "  - Prometheus:   http://localhost:9090"
    echo "  - RabbitMQ:     http://localhost:15672 (rabbitmq/rabbitmq)"
    echo "  - Elasticsearch: http://localhost:9200 (elastic/elastic)"
    echo "  - Python API:   http://localhost:8000"
    echo "  - Node.js API:  http://localhost:3001"
    echo ""
    echo "Useful commands:"
    echo "  - View logs:    ./scripts/logs.sh"
    echo "  - Stop services: ./scripts/stop.sh"
    echo "  - Service status: docker-compose ps"
    echo ""
fi

