#!/bin/bash

# ============================================
# Frontend Development Mode Script
# ============================================
# This script runs the frontend in development mode with hot-reload.
# Useful for rapid frontend development without rebuilding Docker images.

set -e

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}Starting frontend in development mode...${NC}"

# Check if frontend submodule exists
if [ ! -d "frontend/ai-front" ]; then
    echo -e "${RED}Error: Frontend submodule not found${NC}"
    echo -e "${YELLOW}Run: git submodule update --init --recursive${NC}"
    exit 1
fi

# Navigate to frontend directory
cd frontend/ai-front

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}Dependencies not installed. Installing...${NC}"
    npm ci
fi

# Check for .env file
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}Creating .env file from .env.example...${NC}"
    if [ -f ".env.example" ]; then
        cp .env.example .env
    fi
fi

# Start development server
echo -e "${GREEN}✓ Starting Vite development server...${NC}"
echo -e "${BLUE}Access the frontend at: ${GREEN}http://localhost:3000${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo -e ""

# Run Vite dev server
npm run dev

