#!/bin/bash
# ============================================
# Setup Test Environment
# ============================================

set -e

echo "🔧 Setting up test environment..."

cd "$(dirname "$0")/../.."

# Create necessary directories
mkdir -p tests/reports tests/fixtures logs

# Install Python test dependencies
if [ -f "tests/requirements.txt" ]; then
    echo "Checking for Python..."
    
    if ! command -v python3 &> /dev/null; then
        echo "⚠️  Warning: Python 3 not found. Skipping Python dependency installation."
        echo "   Install Python 3: brew install python3"
    else
        # Check if we should use a virtual environment
        if [ ! -d "venv" ]; then
            echo "Creating virtual environment..."
            python3 -m venv venv
        fi
        
        echo "Activating virtual environment..."
        source venv/bin/activate
        
        echo "Installing Python dependencies..."
        pip install --upgrade pip setuptools wheel
        pip install -r tests/requirements.txt
        
        echo "✅ Python dependencies installed in virtual environment"
        echo ""
        echo "To activate the virtual environment manually, run:"
        echo "  source venv/bin/activate"
        echo ""
        echo "To run tests:"
        echo "  source venv/bin/activate && make test"
        echo "  OR"
        echo "  ./venv/bin/pytest tests/unit/nginx -v"
    fi
fi

# Start test infrastructure
echo "Starting test infrastructure..."
docker-compose -f docker-compose.yml -f docker-compose.test.yml up -d

# Wait for services to be healthy
echo "Waiting for services to be healthy..."
sleep 20

# Check critical services
services=("ai_infra_nginx" "ai_infra_postgres" "ai_infra_grafana")
for service in "${services[@]}"; do
    if docker ps --filter "name=$service" --filter "status=running" | grep -q "$service"; then
        echo "✓ $service is running"
    else
        echo "✗ $service is not running"
    fi
done

echo "✅ Test environment setup complete"

