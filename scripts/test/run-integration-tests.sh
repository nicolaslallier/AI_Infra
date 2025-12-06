#!/bin/bash
# ============================================
# Run Integration Tests
# ============================================

set -e

cd "$(dirname "$0")/../.."

# Activate virtual environment if it exists
if [ -d "venv" ] && [ -f "venv/bin/activate" ]; then
    echo "🔧 Activating virtual environment..."
    source venv/bin/activate
else
    echo "⚠️  Warning: Virtual environment not found. Run 'make test-setup' first."
    exit 1
fi

echo "🔗 Running Integration Tests..."

# Check if integration tests exist
if [ ! -d "tests/integration" ] || [ -z "$(find tests/integration -name 'test_*.py' 2>/dev/null)" ]; then
    echo "⚠️  No integration tests found yet. Skipping integration tests."
    echo "   Integration tests will be implemented in future iterations."
    exit 0
fi

# Ensure services are running
echo "Checking if services are up..."
docker-compose ps | grep "Up" || {
    echo "❌ Services not running. Starting services..."
    docker-compose up -d
    sleep 30
}

pytest tests/integration \
    -v \
    --junitxml=tests/reports/junit-integration.xml \
    --html=tests/reports/integration-tests.html \
    --self-contained-html \
    -m "integration"

echo "✅ Integration tests completed"

