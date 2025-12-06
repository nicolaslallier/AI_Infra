#!/bin/bash

# ============================================
# AI Infrastructure - Logs Script
# ============================================
# This script displays logs from Docker services

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Parse command line arguments
FOLLOW=true
TAIL_LINES=100
SPECIFIC_SERVICES=""
TIMESTAMPS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-follow|-n)
            FOLLOW=false
            shift
            ;;
        --tail|-t)
            TAIL_LINES="$2"
            shift 2
            ;;
        --timestamps)
            TIMESTAMPS=true
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
            echo "  --no-follow, -n         Don't follow log output"
            echo "  --tail, -t NUMBER       Number of lines to show (default: 100)"
            echo "  --timestamps            Show timestamps"
            echo "  --service, -s SERVICE   Show logs for specific service(s)"
            echo "  --help, -h              Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                      Follow all service logs"
            echo "  $0 -s postgres          Show postgres logs only"
            echo "  $0 -t 50 --timestamps   Show last 50 lines with timestamps"
            echo "  $0 -n postgres redis    Show logs without following"
            exit 0
            ;;
        *)
            SPECIFIC_SERVICES="$SPECIFIC_SERVICES $1"
            shift
            ;;
    esac
done

cd "$PROJECT_DIR"

# Build docker-compose command
CMD="docker-compose logs"

if [ "$FOLLOW" = true ]; then
    CMD="$CMD -f"
fi

CMD="$CMD --tail=$TAIL_LINES"

if [ "$TIMESTAMPS" = true ]; then
    CMD="$CMD -t"
fi

# Add specific services if provided
if [ ! -z "$SPECIFIC_SERVICES" ]; then
    CMD="$CMD $SPECIFIC_SERVICES"
    echo -e "${GREEN}Showing logs for:${NC} $SPECIFIC_SERVICES"
else
    echo -e "${GREEN}Showing logs for all services${NC}"
fi

if [ "$FOLLOW" = true ]; then
    echo -e "${YELLOW}Following logs... (Press Ctrl+C to exit)${NC}"
else
    echo -e "${YELLOW}Displaying last $TAIL_LINES lines...${NC}"
fi
echo ""

# Execute command
$CMD

