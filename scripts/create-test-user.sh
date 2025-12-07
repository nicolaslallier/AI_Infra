#!/bin/bash

# Script to create a test user in Keycloak with permanent password

set -e

echo "👤 Creating test user in Keycloak..."

# Keycloak admin credentials
KEYCLOAK_URL="http://localhost/auth"
ADMIN_USER="${KEYCLOAK_ADMIN:-admin}"
ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-admin}"
REALM="infra-admin"

# Test user details
TEST_USERNAME="${1:-testuser}"
TEST_PASSWORD="${2:-testpass123}"
TEST_EMAIL="${TEST_USERNAME}@example.com"

echo "1️⃣ Getting admin access token..."
TOKEN_RESPONSE=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=${ADMIN_USER}" \
  -d "password=${ADMIN_PASSWORD}" \
  -d "grant_type=password" \
  -d "client_id=admin-cli")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null || echo "")

if [ -z "$ACCESS_TOKEN" ]; then
  echo "❌ Failed to get admin access token"
  exit 1
fi

echo "✅ Got access token"

echo "2️⃣ Creating user: ${TEST_USERNAME}"
CREATE_USER=$(curl -s -w "\n%{http_code}" -X POST "${KEYCLOAK_URL}/admin/realms/${REALM}/users" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"username\": \"${TEST_USERNAME}\",
    \"email\": \"${TEST_EMAIL}\",
    \"firstName\": \"Test\",
    \"lastName\": \"User\",
    \"enabled\": true,
    \"emailVerified\": true
  }")

HTTP_CODE=$(echo "$CREATE_USER" | tail -1)
if [ "$HTTP_CODE" = "201" ]; then
  echo "✅ User created"
else
  echo "⚠️  User might already exist or creation failed (HTTP $HTTP_CODE)"
fi

echo "3️⃣ Getting user ID..."
USER_DATA=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM}/users?username=${TEST_USERNAME}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}")

USER_ID=$(echo "$USER_DATA" | python3 -c "import sys, json; print(json.load(sys.stdin)[0]['id'])" 2>/dev/null || echo "")

if [ -z "$USER_ID" ]; then
  echo "❌ Failed to get user ID"
  exit 1
fi

echo "✅ Got user ID: ${USER_ID}"

echo "4️⃣ Setting permanent password..."
SET_PASSWORD=$(curl -s -w "\n%{http_code}" -X PUT "${KEYCLOAK_URL}/admin/realms/${REALM}/users/${USER_ID}/reset-password" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"type\": \"password\",
    \"value\": \"${TEST_PASSWORD}\",
    \"temporary\": false
  }")

HTTP_CODE=$(echo "$SET_PASSWORD" | tail -1)
if [ "$HTTP_CODE" = "204" ]; then
  echo "✅ Password set"
else
  echo "❌ Failed to set password (HTTP $HTTP_CODE)"
  exit 1
fi

echo ""
echo "🎉 Test user created successfully!"
echo ""
echo "📋 Login Credentials:"
echo "   Username: ${TEST_USERNAME}"
echo "   Password: ${TEST_PASSWORD}"
echo "   Email: ${TEST_EMAIL}"
echo ""
echo "✅ You can now login at: http://localhost/home"

