#!/bin/bash

# Script to assign groups to a Keycloak user
# Groups automatically grant associated roles
# Usage: ./assign-user-groups.sh <username> <group1> [group2] [group3]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Keycloak admin credentials
KEYCLOAK_URL="http://localhost/auth"
ADMIN_USER="${KEYCLOAK_ADMIN:-admin}"
ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-admin}"
REALM="infra-admin"

# Check arguments
if [ $# -lt 2 ]; then
  echo -e "${RED}❌ Error: Missing arguments${NC}"
  echo ""
  echo "Usage: $0 <username> <group1> [group2] [group3] ..."
  echo ""
  echo "Available groups:"
  echo "  - DBAs        (Grants ROLE_DBA)"
  echo "  - DevOps      (Grants ROLE_DEVOPS)"
  echo "  - Monitoring  (Grants ROLE_READONLY_MONITORING)"
  echo ""
  echo "Examples:"
  echo "  $0 testuser DevOps"
  echo "  $0 testuser DBAs DevOps"
  echo "  $0 admin-user DBAs DevOps Monitoring"
  exit 1
fi

USERNAME="$1"
shift
# Capture remaining arguments as array
GROUPS=("$@")

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Keycloak Group Assignment Script${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Target User:${NC} ${USERNAME}"
echo -e "${YELLOW}Groups to assign:${NC}"
for group in "${GROUPS[@]}"; do
  echo "  • $group"
done
echo ""

# Step 1: Get admin access token
echo -e "${BLUE}1️⃣  Getting admin access token...${NC}"
TOKEN_RESPONSE=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=${ADMIN_USER}" \
  -d "password=${ADMIN_PASSWORD}" \
  -d "grant_type=password" \
  -d "client_id=admin-cli")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null || echo "")

if [ -z "$ACCESS_TOKEN" ]; then
  echo -e "${RED}❌ Failed to get admin access token${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Access token obtained${NC}"

# Step 2: Get user ID
echo -e "${BLUE}2️⃣  Looking up user: ${USERNAME}${NC}"
USER_DATA=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM}/users?username=${USERNAME}&exact=true" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}")

USER_ID=$(echo "$USER_DATA" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data[0]['id'] if data else '')" 2>/dev/null || echo "")

if [ -z "$USER_ID" ]; then
  echo -e "${RED}❌ User '${USERNAME}' not found${NC}"
  exit 1
fi

echo -e "${GREEN}✅ User found (ID: ${USER_ID})${NC}"

# Step 3: Get available groups
echo -e "${BLUE}3️⃣  Fetching available groups...${NC}"
ALL_GROUPS=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM}/groups" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}")

# Step 4: Assign each group
echo -e "${BLUE}4️⃣  Assigning groups...${NC}"

SUCCESS_COUNT=0
FAIL_COUNT=0
ALREADY_ASSIGNED=0

for GROUP_NAME in "${GROUPS[@]}"; do
  echo ""
  echo -e "${YELLOW}  Assigning group: ${GROUP_NAME}${NC}"
  
  # Get group ID
  GROUP_ID=$(echo "$ALL_GROUPS" | python3 -c "import sys, json; groups=[g for g in json.load(sys.stdin) if g['name']=='${GROUP_NAME}']; print(groups[0]['id'] if groups else '')" 2>/dev/null || echo "")
  
  if [ -z "$GROUP_ID" ]; then
    echo -e "${RED}    ❌ Group '${GROUP_NAME}' not found${NC}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    continue
  fi
  
  # Check if user is already in group
  CURRENT_GROUPS=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM}/users/${USER_ID}/groups" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}")
  
  IN_GROUP=$(echo "$CURRENT_GROUPS" | python3 -c "import sys, json; print('yes' if any(g['name']=='${GROUP_NAME}' for g in json.load(sys.stdin)) else 'no')" 2>/dev/null || echo "no")
  
  if [ "$IN_GROUP" = "yes" ]; then
    echo -e "${YELLOW}    ⚠️  User already in group '${GROUP_NAME}'${NC}"
    ALREADY_ASSIGNED=$((ALREADY_ASSIGNED + 1))
    continue
  fi
  
  # Add user to group
  ADD_RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT "${KEYCLOAK_URL}/admin/realms/${REALM}/users/${USER_ID}/groups/${GROUP_ID}" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}")
  
  HTTP_CODE=$(echo "$ADD_RESPONSE" | tail -1)
  
  if [ "$HTTP_CODE" = "204" ]; then
    echo -e "${GREEN}    ✅ Added to group successfully${NC}"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  else
    echo -e "${RED}    ❌ Failed to add to group (HTTP ${HTTP_CODE})${NC}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
done

# Step 5: Verify current groups and roles
echo ""
echo -e "${BLUE}5️⃣  Verifying current assignments...${NC}"
FINAL_GROUPS=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM}/users/${USER_ID}/groups" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}")

FINAL_ROLES=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM}/users/${USER_ID}/role-mappings/realm" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}")

echo ""
echo -e "${GREEN}Current groups for user '${USERNAME}':${NC}"
echo "$FINAL_GROUPS" | python3 -c "import sys, json; [print(f'  • {g[\"name\"]} ({g[\"path\"]})') for g in json.load(sys.stdin)]" 2>/dev/null || echo "  Unable to parse groups"

echo ""
echo -e "${GREEN}Current roles for user '${USERNAME}':${NC}"
echo "$FINAL_ROLES" | python3 -c "import sys, json; [print(f'  • {r[\"name\"]}') for r in json.load(sys.stdin)]" 2>/dev/null || echo "  Unable to parse roles"

# Summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Successfully assigned: ${SUCCESS_COUNT}${NC}"
if [ $ALREADY_ASSIGNED -gt 0 ]; then
  echo -e "${YELLOW}⚠️  Already assigned: ${ALREADY_ASSIGNED}${NC}"
fi
if [ $FAIL_COUNT -gt 0 ]; then
  echo -e "${RED}❌ Failed: ${FAIL_COUNT}${NC}"
fi
echo ""

if [ $SUCCESS_COUNT -gt 0 ] || [ $ALREADY_ASSIGNED -gt 0 ]; then
  echo -e "${GREEN}🎉 Group assignment completed!${NC}"
  exit 0
else
  echo -e "${RED}❌ No groups were assigned${NC}"
  exit 1
fi

