#!/bin/bash

# Script to add the ai-front-spa client to Keycloak via REST API
# This is needed when the realm already exists and won't be reimported

set -e

echo "🔑 Adding ai-front-spa client to Keycloak..."

# Keycloak admin credentials (from docker-compose.yml)
KEYCLOAK_URL="http://localhost/auth"
ADMIN_USER="${KEYCLOAK_ADMIN:-admin}"
ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-admin}"
REALM="infra-admin"

echo "1️⃣ Getting admin access token..."
# Get admin access token
TOKEN_RESPONSE=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=${ADMIN_USER}" \
  -d "password=${ADMIN_PASSWORD}" \
  -d "grant_type=password" \
  -d "client_id=admin-cli")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null || echo "")

if [ -z "$ACCESS_TOKEN" ]; then
  echo "❌ Failed to get admin access token"
  echo "Response: $TOKEN_RESPONSE"
  exit 1
fi

echo "✅ Got access token"

echo "2️⃣ Checking if client already exists..."
# Check if client already exists
EXISTING_CLIENT=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM}/clients?clientId=ai-front-spa" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json")

if echo "$EXISTING_CLIENT" | grep -q "ai-front-spa"; then
  echo "⚠️  Client 'ai-front-spa' already exists"
  echo "   Deleting existing client..."
  
  # Get client ID (UUID)
  CLIENT_UUID=$(echo "$EXISTING_CLIENT" | python3 -c "import sys, json; print(json.load(sys.stdin)[0]['id'])")
  
  # Delete existing client
  DELETE_RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "${KEYCLOAK_URL}/admin/realms/${REALM}/clients/${CLIENT_UUID}" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}")
  
  HTTP_CODE=$(echo "$DELETE_RESPONSE" | tail -1)
  if [ "$HTTP_CODE" = "204" ]; then
    echo "✅ Deleted existing client"
  else
    echo "❌ Failed to delete existing client (HTTP $HTTP_CODE)"
  fi
fi

echo "3️⃣ Creating ai-front-spa client..."
# Create the client
CREATE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${KEYCLOAK_URL}/admin/realms/${REALM}/clients" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d @docker/keycloak/ai-front-spa-client.json)

HTTP_CODE=$(echo "$CREATE_RESPONSE" | tail -1)
RESPONSE_BODY=$(echo "$CREATE_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "201" ]; then
  echo "✅ Successfully created ai-front-spa client!"
  echo ""
  echo "📋 Client Configuration:"
  echo "   Client ID: ai-front-spa"
  echo "   Type: Public Client (SPA)"
  echo "   PKCE: Enabled (S256)"
  echo "   Valid Redirect URIs: http://localhost/*"
  echo "   Web Origins: http://localhost"
  echo ""
  echo "✅ You can now use the frontend application!"
else
  echo "❌ Failed to create client (HTTP $HTTP_CODE)"
  echo "Response: $RESPONSE_BODY"
  exit 1
fi

