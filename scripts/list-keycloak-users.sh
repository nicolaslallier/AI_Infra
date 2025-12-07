#!/bin/bash

# Script to list all users in Keycloak with their roles and groups
# Usage: ./list-keycloak-users.sh

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

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Keycloak Users List${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

# Get admin access token
echo -e "${BLUE}Getting admin access token...${NC}"
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
echo ""

# Get all users
echo -e "${BLUE}Fetching users from realm '${REALM}'...${NC}"
USERS=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM}/users" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}")

# Parse and display users
python3 << 'EOF' - "$USERS" "$ACCESS_TOKEN" "$KEYCLOAK_URL" "$REALM"
import sys
import json
import subprocess

users_json = sys.argv[1]
access_token = sys.argv[2]
keycloak_url = sys.argv[3]
realm = sys.argv[4]

users = json.loads(users_json)

if not users:
    print("\033[0;33m⚠️  No users found in realm\033[0m")
    sys.exit(0)

print(f"\033[0;32mFound {len(users)} user(s):\033[0m\n")

for i, user in enumerate(users, 1):
    username = user.get('username', 'N/A')
    user_id = user.get('id', '')
    email = user.get('email', 'No email')
    enabled = '✅ Enabled' if user.get('enabled', False) else '❌ Disabled'
    
    print(f"\033[1;36m{i}. {username}\033[0m")
    print(f"   Email: {email}")
    print(f"   Status: {enabled}")
    print(f"   ID: {user_id}")
    
    # Get user's roles
    roles_cmd = [
        'curl', '-s', '-X', 'GET',
        f'{keycloak_url}/admin/realms/{realm}/users/{user_id}/role-mappings/realm',
        '-H', f'Authorization: Bearer {access_token}'
    ]
    
    try:
        roles_response = subprocess.run(roles_cmd, capture_output=True, text=True, check=True)
        roles = json.loads(roles_response.stdout)
        
        if roles:
            print(f"   Roles:")
            for role in roles:
                role_name = role.get('name', 'Unknown')
                role_desc = role.get('description', '')
                if role_desc:
                    print(f"     • {role_name} - {role_desc}")
                else:
                    print(f"     • {role_name}")
        else:
            print(f"   Roles: \033[0;33mNone assigned\033[0m")
    except:
        print(f"   Roles: \033[0;31mFailed to fetch\033[0m")
    
    # Get user's groups
    groups_cmd = [
        'curl', '-s', '-X', 'GET',
        f'{keycloak_url}/admin/realms/{realm}/users/{user_id}/groups',
        '-H', f'Authorization: Bearer {access_token}'
    ]
    
    try:
        groups_response = subprocess.run(groups_cmd, capture_output=True, text=True, check=True)
        groups = json.loads(groups_response.stdout)
        
        if groups:
            print(f"   Groups:")
            for group in groups:
                group_name = group.get('name', 'Unknown')
                group_path = group.get('path', '')
                print(f"     • {group_name} ({group_path})")
        else:
            print(f"   Groups: \033[0;33mNone assigned\033[0m")
    except:
        print(f"   Groups: \033[0;31mFailed to fetch\033[0m")
    
    print()

print("\033[0;34m═══════════════════════════════════════════════════════\033[0m")
print("\033[0;32m✅ User list complete\033[0m")
EOF

echo ""
echo "To assign roles to a user, run:"
echo "  ./scripts/assign-user-roles.sh <username> <role>"
echo ""
echo "To assign groups to a user, run:"
echo "  ./scripts/assign-user-groups.sh <username> <group>"

