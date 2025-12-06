#!/bin/bash
# ============================================
# Keycloak Database Initialization
# AI Infrastructure Project
# ============================================
# This script creates a dedicated database and user for Keycloak
# to isolate authentication data from application data.

set -e

# Use environment variable or default password
KEYCLOAK_PASSWORD="${KEYCLOAK_DB_PASSWORD:-keycloak}"

echo "========================================="
echo "Keycloak Database Initialization"
echo "========================================="

# Create Keycloak user
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Create Keycloak user
    DO \$\$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'keycloak') THEN
        CREATE USER keycloak WITH ENCRYPTED PASSWORD '$KEYCLOAK_PASSWORD';
        RAISE NOTICE 'User keycloak created successfully';
      ELSE
        -- Update password in case it changed
        ALTER USER keycloak WITH ENCRYPTED PASSWORD '$KEYCLOAK_PASSWORD';
        RAISE NOTICE 'User keycloak password updated';
      END IF;
    END
    \$\$;
    
    -- Create Keycloak database if it doesn't exist
    SELECT 'CREATE DATABASE keycloak OWNER keycloak ENCODING ''UTF8'' LC_COLLATE ''en_US.UTF-8'' LC_CTYPE ''en_US.UTF-8'''
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'keycloak')\gexec
    
    -- Grant privileges
    GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;
EOSQL

# Connect to keycloak database and set up schema privileges
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "keycloak" <<-EOSQL
    -- Grant schema creation privileges
    GRANT CREATE ON SCHEMA public TO keycloak;
    
    -- Set default privileges for future objects
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO keycloak;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO keycloak;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO keycloak;
    
    -- Connection limit (optional - prevent resource exhaustion)
    ALTER USER keycloak CONNECTION LIMIT 100;
EOSQL

echo "========================================="
echo "✓ Keycloak database setup complete"
echo "  Database: keycloak"
echo "  User: keycloak"
echo "  Owner: keycloak"
echo "========================================="

