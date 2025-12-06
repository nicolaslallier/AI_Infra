#!/bin/bash

# ============================================
# Update Frontend Submodule Script
# ============================================
# This script pulls the latest changes from the frontend submodule
# and updates the reference in the main repository.

set -e

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}Updating frontend submodule...${NC}"

# Check if frontend submodule exists
if [ ! -d "frontend/ai-front/.git" ]; then
    echo -e "${YELLOW}Frontend submodule not initialized. Initializing...${NC}"
    git submodule update --init --recursive
fi

# Navigate to submodule directory
cd frontend/ai-front

# Fetch latest changes
echo -e "${BLUE}Fetching latest changes...${NC}"
git fetch origin

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)

if [ -z "$CURRENT_BRANCH" ]; then
    # Detached HEAD state, checkout main
    echo -e "${YELLOW}Submodule is in detached HEAD state. Checking out main...${NC}"
    git checkout main
    CURRENT_BRANCH="main"
fi

echo -e "${BLUE}Current branch: ${CURRENT_BRANCH}${NC}"

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo -e "${RED}Error: Uncommitted changes in frontend submodule${NC}"
    echo -e "${YELLOW}Please commit or stash your changes first.${NC}"
    exit 1
fi

# Pull latest changes
echo -e "${BLUE}Pulling latest changes from origin/${CURRENT_BRANCH}...${NC}"
git pull origin "$CURRENT_BRANCH"

# Return to main repository root
cd ../..

# Check if submodule reference changed
if git diff --quiet frontend/ai-front; then
    echo -e "${GREEN}✓ Frontend is already up to date${NC}"
else
    echo -e "${YELLOW}Frontend submodule reference updated${NC}"
    echo -e "${BLUE}To commit this update, run:${NC}"
    echo -e "  git add frontend/ai-front"
    echo -e "  git commit -m \"chore: update frontend submodule\""
fi

echo -e "${GREEN}✓ Frontend update complete!${NC}"
echo -e ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "  1. Rebuild frontend: ${GREEN}make frontend-build${NC}"
echo -e "  2. Restart services: ${GREEN}docker-compose restart frontend nginx${NC}"

