#!/bin/bash

# Push All Repositories Script for v2.0.0 Release
# This script pushes all commits and tags for the AI platform repositories

set -e  # Exit on error

echo "======================================"
echo "AI Platform v2.0.0 - Push All Repos"
echo "======================================"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to push a repository
push_repo() {
    local repo_path=$1
    local repo_name=$2
    
    echo -e "${YELLOW}Processing: $repo_name${NC}"
    echo "Location: $repo_path"
    
    cd "$repo_path"
    
    # Check if there are commits to push
    if git status | grep -q "Your branch is ahead"; then
        echo "  Pushing commits..."
        git push origin main
        echo -e "  ${GREEN}✓ Commits pushed${NC}"
    else
        echo "  No new commits to push"
    fi
    
    # Check if v2.0.0 tag exists locally
    if git tag -l "v2.0.0" | grep -q "v2.0.0"; then
        echo "  Pushing v2.0.0 tag..."
        git push origin v2.0.0 2>/dev/null && echo -e "  ${GREEN}✓ Tag pushed${NC}" || echo "  Tag already exists on remote"
    else
        echo -e "  ${RED}✗ Tag v2.0.0 not found locally${NC}"
    fi
    
    echo ""
}

# Push all repositories
echo "Starting push process..."
echo ""

push_repo "/Users/nicolaslallier/Dev Nick/AI_Infra" "AI_Infra (Infrastructure)"
push_repo "/Users/nicolaslallier/Dev Nick/AI" "AI (Documentation Workspace)"
push_repo "/Users/nicolaslallier/Dev Nick/AI_Front" "AI_Front (Frontend Console Hub)"
push_repo "/Users/nicolaslallier/Dev Nick/AI_Middle" "AI_Middle (Middleware Services)"
push_repo "/Users/nicolaslallier/Dev Nick/AI_Backend" "AI_Backend (Backend Services)"

echo "======================================"
echo -e "${GREEN}All repositories processed!${NC}"
echo "======================================"
echo ""
echo "Summary of v2.0.0 Release:"
echo "  • AI_Infra: Complete infrastructure with MinIO, monitoring, and automation"
echo "  • AI_Front: Console hub with 7 integrated admin/monitoring tools"
echo "  • AI_Middle: Middleware services configuration"
echo "  • AI_Backend: Clean Architecture Python backend"
echo "  • AI: Comprehensive documentation archive"
echo ""
echo "To verify tags on GitHub, visit:"
echo "  https://github.com/nicolaslallier/AI_Infra/releases"
echo "  https://github.com/nicolaslallier/AI_Front/releases"
echo "  https://github.com/nicolaslallier/AI_Middle/releases"
echo "  https://github.com/nicolaslallier/AI_Backend/releases"
echo ""
