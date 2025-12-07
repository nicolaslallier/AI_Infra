#!/bin/bash
# Reset Grafana - Fix Access Loss Issue
# This script resets Grafana to a clean state with default credentials

set -e  # Exit on error

echo "🔧 Grafana Reset Script"
echo "======================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    print_error "docker-compose not found. Please install Docker Compose."
    exit 1
fi

# Parse command line arguments
FULL_RESET=false
RESET_PASSWORD=false
PASSWORD="admin"

while [[ $# -gt 0 ]]; do
    case $1 in
        --full)
            FULL_RESET=true
            shift
            ;;
        --password)
            RESET_PASSWORD=true
            PASSWORD="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --full              Full reset (removes volume and recreates container)"
            echo "  --password <pwd>    Reset admin password to specified value"
            echo "  --help              Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                          # Quick reset (restart container)"
            echo "  $0 --full                   # Full reset with clean volume"
            echo "  $0 --password myNewPass123  # Reset password only"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo "📋 Reset Mode: $([ "$FULL_RESET" = true ] && echo 'FULL RESET' || echo 'QUICK RESET')"
echo ""

if [ "$FULL_RESET" = true ]; then
    print_warning "This will DELETE all Grafana data (dashboards, users, settings)"
    read -p "Are you sure? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        print_info "Operation cancelled"
        exit 0
    fi
    
    print_info "Stopping Grafana..."
    docker-compose stop grafana
    
    print_info "Removing Grafana volume..."
    docker volume rm ai_infra_grafana_data 2>/dev/null || print_warning "Volume already removed or doesn't exist"
    
    print_info "Recreating Grafana container..."
    docker-compose up -d grafana --force-recreate
    
    print_info "Waiting for Grafana to start (30 seconds)..."
    sleep 30
    
    # Check if Grafana is healthy
    if docker inspect ai_infra_grafana | grep -q '"Status": "healthy"'; then
        print_info "Grafana is healthy!"
    else
        print_warning "Grafana health check pending..."
    fi
    
    print_info "✅ Grafana has been fully reset"
    print_info "🔑 Login credentials:"
    echo "   Username: admin"
    echo "   Password: admin"
    echo ""
    print_info "Access Grafana at: http://localhost/monitoring/grafana/"
    
elif [ "$RESET_PASSWORD" = true ]; then
    print_info "Resetting Grafana admin password..."
    
    # Check if container is running
    if ! docker ps | grep -q ai_infra_grafana; then
        print_error "Grafana container is not running"
        print_info "Starting Grafana..."
        docker-compose up -d grafana
        sleep 10
    fi
    
    print_info "Resetting password to: $PASSWORD"
    docker exec -it ai_infra_grafana grafana-cli admin reset-admin-password "$PASSWORD"
    
    print_info "Restarting Grafana..."
    docker-compose restart grafana
    
    print_info "Waiting for Grafana to restart (10 seconds)..."
    sleep 10
    
    print_info "✅ Password has been reset"
    print_info "🔑 New login credentials:"
    echo "   Username: admin"
    echo "   Password: $PASSWORD"
    echo ""
    print_info "Access Grafana at: http://localhost/monitoring/grafana/"
    
else
    print_info "Quick reset: Restarting Grafana container..."
    docker-compose restart grafana
    
    print_info "Waiting for Grafana to restart (10 seconds)..."
    sleep 10
    
    print_info "✅ Grafana has been restarted"
    print_info "ℹ️  If you still can't login, try:"
    echo "   1. Clear browser cookies for localhost"
    echo "   2. Run: $0 --password admin"
    echo "   3. Or do a full reset: $0 --full"
    echo ""
    print_info "Access Grafana at: http://localhost/monitoring/grafana/"
fi

echo ""
print_info "Checking Grafana status..."
if curl -sf http://localhost/monitoring/grafana/api/health > /dev/null; then
    print_info "✅ Grafana is responding!"
    curl -s http://localhost/monitoring/grafana/api/health | python3 -m json.tool 2>/dev/null || echo "Health check OK"
else
    print_warning "⚠️  Grafana is not responding yet. Wait a few more seconds and try accessing it."
fi

echo ""
print_info "📚 Troubleshooting:"
echo "   - Clear browser cookies if you get 'Invalid session' errors"
echo "   - Check logs: docker logs ai_infra_grafana -f"
echo "   - Verify health: curl http://localhost/monitoring/grafana/api/health"
echo ""
print_info "Done! 🎉"

