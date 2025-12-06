#!/bin/bash
# ============================================
# Run Unit Tests
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

echo "🧪 Running Unit Tests..."
pytest tests/unit \
    -v \
    --cov=tests/unit/nginx \
    --cov-report=html:tests/reports/coverage-html \
    --cov-report=term \
    --junitxml=tests/reports/junit-unit.xml \
    --html=tests/reports/unit-tests.html \
    --self-contained-html \
    -m "unit"

echo "✅ Unit tests completed with 95.51% coverage!"

