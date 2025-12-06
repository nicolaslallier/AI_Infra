#!/bin/bash
# ============================================
# Run All Tests
# ============================================
# Execute the complete test suite

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}Running Complete Test Suite${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Navigate to project root
cd "$(dirname "$0")/../.."

# Activate virtual environment if it exists
if [ -d "venv" ]; then
    echo -e "${BLUE}Activating virtual environment...${NC}"
    source venv/bin/activate
else
    echo -e "${YELLOW}Warning: Virtual environment not found. Run 'make test-setup' first.${NC}"
    echo ""
fi

# Create reports directory
mkdir -p tests/reports

# Track results
FAILED_TESTS=()

# Function to run test suite
run_test_suite() {
    local name=$1
    local command=$2
    
    echo -e "${BLUE}Running $name...${NC}"
    if eval "$command"; then
        echo -e "${GREEN}✓ $name passed${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}✗ $name failed${NC}"
        echo ""
        FAILED_TESTS+=("$name")
        return 1
    fi
}

# Unit Tests
run_test_suite "Unit Tests" "pytest tests/unit -v --maxfail=5"

# Integration Tests (skip if not implemented yet)
if [ -d "tests/integration" ] && [ -n "$(find tests/integration -name 'test_*.py' 2>/dev/null)" ]; then
    run_test_suite "Integration Tests" "pytest tests/integration -v --maxfail=3"
else
    echo -e "${YELLOW}⏭️  Integration tests not implemented yet - skipping${NC}"
    echo ""
fi

# Frontend Tests (skip if dependencies not installed)
if [ -d "frontend/ai-front" ]; then
    if [ -d "frontend/ai-front/node_modules" ]; then
        run_test_suite "Frontend Unit Tests" "cd frontend/ai-front && npm run test"
    else
        echo -e "${YELLOW}⏭️  Frontend dependencies not installed - skipping frontend tests${NC}"
        echo -e "${YELLOW}   Run 'cd frontend/ai-front && npm install' to enable frontend tests${NC}"
        echo ""
    fi
fi

# E2E Tests (skip if not implemented yet)
if [ -d "tests/e2e" ] && [ -n "$(find tests/e2e -name 'test_*.py' 2>/dev/null)" ]; then
    run_test_suite "E2E Tests" "pytest tests/e2e -v --maxfail=2"
else
    echo -e "${YELLOW}⏭️  E2E tests not implemented yet - skipping${NC}"
    echo ""
fi

# API Tests (if Newman is available)
if command -v newman &> /dev/null; then
    run_test_suite "API Tests" "./scripts/test/run-api-tests.sh"
fi

# Performance Tests (if k6 is available)
if command -v k6 &> /dev/null && [ "${RUN_PERFORMANCE_TESTS}" = "true" ]; then
    run_test_suite "Performance Tests" "./scripts/test/run-performance-tests.sh"
fi

# Summary
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

if [ ${#FAILED_TESTS[@]} -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ The following test suites failed:${NC}"
    for test in "${FAILED_TESTS[@]}"; do
        echo -e "${RED}  - $test${NC}"
    done
    exit 1
fi

