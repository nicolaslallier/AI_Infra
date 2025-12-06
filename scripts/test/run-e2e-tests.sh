#!/bin/bash
# ============================================
# Run E2E Tests
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

echo "🌐 Running E2E Tests..."

# Check if E2E tests exist
if [ ! -d "tests/e2e" ] || [ -z "$(find tests/e2e -name 'test_*.py' 2>/dev/null)" ]; then
    echo "⚠️  No E2E tests found yet. Skipping E2E tests."
    echo "   E2E tests will be implemented in future iterations."
    exit 0
fi

# Ensure services are running
docker-compose ps | grep "Up" || {
    echo "Starting services for E2E tests..."
    docker-compose up -d
    sleep 30
}

# Run Playwright tests from frontend
if [ -d "frontend/ai-front" ]; then
    cd frontend/ai-front
    if [ -d "tests/e2e" ] && [ -n "$(find tests/e2e -name '*.spec.ts' 2>/dev/null)" ]; then
        npx playwright test --reporter=html
    fi
    cd ../..
fi

# Run Python E2E tests
pytest tests/e2e \
    -v \
    --junitxml=tests/reports/junit-e2e.xml \
    --html=tests/reports/e2e-tests.html \
    --self-contained-html \
    -m "e2e"

echo "✅ E2E tests completed"

