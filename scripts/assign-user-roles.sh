#!/bin/bash

# Script to assign roles to a Keycloak user
# Usage: ./assign-user-roles.sh <username> <role1> [role2] [role3]
# Example: ./assign-user-roles.sh testuser ROLE_DEVOPS ROLE_READONLY_MONITORING

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
  echo "Usage: $0 <username> <role1> [role2] [role3] ..."
  echo ""
  echo "Available roles:"
  echo "  - ROLE_DBA                  (Database Administrator - Full pgAdmin access)"
  echo "  - ROLE_DEVOPS               (DevOps Engineer - Infrastructure & monitoring)"
  echo "  - ROLE_READONLY_MONITORING  (Read-only monitoring access)"
  echo ""
  echo "Examples:"
  echo "  $0 testuser ROLE_DEVOPS"
  echo "  $0 testuser ROLE_DBA ROLE_DEVOPS"
  echo "  $0 admin-user ROLE_DBA ROLE_DEVOPS ROLE_READONLY_MONITORING"
  exit 1
fi

USERNAME="$1"
shift
ROLES=("$@")

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Keycloak Role Assignment Script${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Target User:${NC} ${USERNAME}"
echo -e "${YELLOW}Roles to assign:${NC}"
for role in "${ROLES[@]}"; do
  echo "  • $role"
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
  echo "Response: $TOKEN_RESPONSE"
  exit 1
fi

echo -e "${GREEN}✅ Access token obtained${NC}"

# Step 2: Get user ID
echo -e "${BLUE}2️⃣  Looking up user: ${USERNAME}${NC}"
USER_DATA=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM}/users?username=${USERNAME}&exact=true" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}")

USER_ID=$(echo "$USER_DATA" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data[0]['id'] if data else '')" 2>/dev/null || echo "")

if [ -z "$USER_ID" ]; then
  echo -e "${RED}❌ User '${USERNAME}' not found in realm '${REALM}'${NC}"
  echo ""
  echo "Available users:"
  curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM}/users" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" | \
    python3 -c "import sys, json; [print(f\"  • {u['username']} ({u.get('email', 'no email')})\") for u in json.load(sys.stdin)]" 2>/dev/null || echo "  Unable to list users"
  exit 1
fi

echo -e "${GREEN}✅ User found (ID: ${USER_ID})${NC}"

# Step 3: Get available realm roles
echo -e "${BLUE}3️⃣  Fetching available realm roles...${NC}"
REALM_ROLES=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM}/roles" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}")

# Step 4: Assign each role
echo -e "${BLUE}4️⃣  Assigning roles...${NC}"

SUCCESS_COUNT=0
FAIL_COUNT=0
ALREADY_ASSIGNED=0

for ROLE_NAME in "${ROLES[@]}"; do
  echo ""
  echo -e "${YELLOW}  Assigning role: ${ROLE_NAME}${NC}"
  
  # Get role details
  ROLE_DATA=$(echo "$REALM_ROLES" | python3 -c "import sys, json; roles=[r for r in json.load(sys.stdin) if r['name']=='${ROLE_NAME}']; print(json.dumps(roles[0]) if roles else '')" 2>/dev/null || echo "")
  
  if [ -z "$ROLE_DATA" ]; then
    echo -e "${RED}    ❌ Role '${ROLE_NAME}' not found in realm${NC}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    continue
  fi
  
  ROLE_ID=$(echo "$ROLE_DATA" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])" 2>/dev/null || echo "")
  
  # Check if user already has this role
  CURRENT_ROLES=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM}/users/${USER_ID}/role-mappings/realm" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}")
  
  HAS_ROLE=$(echo "$CURRENT_ROLES" | python3 -c "import sys, json; print('yes' if any(r['name']=='${ROLE_NAME}' for r in json.load(sys.stdin)) else 'no')" 2>/dev/null || echo "no")
  
  if [ "$HAS_ROLE" = "yes" ]; then
    echo -e "${YELLOW}    ⚠️  User already has role '${ROLE_NAME}'${NC}"
    ALREADY_ASSIGNED=$((ALREADY_ASSIGNED + 1))
    continue
  fi
  
  # Assign the role
  ASSIGN_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${KEYCLOAK_URL}/admin/realms/${REALM}/users/${USER_ID}/role-mappings/realm" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "[$ROLE_DATA]")
  
  HTTP_CODE=$(echo "$ASSIGN_RESPONSE" | tail -1)
  
  if [ "$HTTP_CODE" = "204" ]; then
    echo -e "${GREEN}    ✅ Role assigned successfully${NC}"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  else
    echo -e "${RED}    ❌ Failed to assign role (HTTP ${HTTP_CODE})${NC}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
done

# Step 5: Verify current roles
echo ""
echo -e "${BLUE}5️⃣  Verifying current role assignments...${NC}"
FINAL_ROLES=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM}/users/${USER_ID}/role-mappings/realm" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}")

echo ""
echo -e "${GREEN}Current roles for user '${USERNAME}':${NC}"
echo "$FINAL_ROLES" | python3 -c "import sys, json; [print(f'  • {r[\"name\"]} - {r.get(\"description\", \"No description\")}') for r in json.load(sys.stdin)]" 2>/dev/null || echo "  Unable to parse roles"

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
  echo -e "${GREEN}🎉 Role assignment completed!${NC}"
  echo ""
  echo "The user can now login at: http://localhost/home"
  echo ""
  echo "To add the user to groups (optional), run:"
  echo "  ./scripts/assign-user-groups.sh ${USERNAME} <group-name>"
  exit 0
else
  echo -e "${RED}❌ No roles were assigned${NC}"
  exit 1
fi

