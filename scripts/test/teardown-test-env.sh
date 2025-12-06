#!/bin/bash
# ============================================
# Teardown Test Environment
# ============================================

set -e

echo "🧹 Tearing down test environment..."

cd "$(dirname "$0")/../.."

# Stop test containers
echo "Stopping test containers..."
docker-compose -f docker-compose.test.yml down

# Optional: Clean up test data
if [ "$CLEAN_TEST_DATA" = "true" ]; then
    echo "Cleaning test data..."
    docker volume rm ai_infra_postgres_test_data 2>/dev/null || true
fi

# Generate final report summary
if [ -d "tests/reports" ]; then
    echo ""
    echo "📊 Test Reports available in: tests/reports/"
    ls -lh tests/reports/ | tail -n +2
fi

echo "✅ Test environment teardown complete"

