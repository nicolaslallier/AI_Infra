# Keycloak Configuration

This directory contains configuration files for the Keycloak identity and access management service.

## Files

### realm-export.json

Pre-configured Keycloak realm for infrastructure administration.

**Contents:**
- Realm: `infra-admin`
- Clients: `pgadmin-client` (with OIDC configuration)
- Roles: `ROLE_DBA`, `ROLE_DEVOPS`, `ROLE_READONLY_MONITORING`
- Groups: DBAs, DevOps, Monitoring
- Test Users: admin-dba, devops-user

**Import:** Automatically imported on Keycloak startup via `--import-realm` flag.

**Export:**
To export the current realm configuration:

1. Access Keycloak Admin Console: `http://localhost/auth/`
2. Select realm: **infra-admin**
3. Navigate to: Realm Settings → Export
4. Configure export options:
   - Export groups and roles: Yes
   - Export clients: Yes
5. Click **Export**
6. Save as `realm-export.json` (overwrite existing)

### keycloak.conf

Keycloak configuration file with database, HTTP, proxy, and security settings.

**Key Settings:**
- Database: PostgreSQL connection pool configuration
- HTTP: Port 8080 (development), HTTPS for production
- Proxy: Edge mode (behind NGINX reverse proxy)
- Logging: Console output, INFO level
- Health & Metrics: Enabled

**Production Changes:**
```conf
# Disable HTTP, enable HTTPS
http-enabled=false
https-port=8443
https-certificate-file=/path/to/cert.pem
https-certificate-key-file=/path/to/key.pem

# Set proper hostname
hostname=auth.your-domain.com
hostname-strict=true
hostname-strict-https=true

# Increase log level for troubleshooting
log-level=DEBUG
```

## Quick Reference

### Admin Access

**URL:** `http://localhost/auth/`  
**Username:** `admin` (env: KEYCLOAK_ADMIN)  
**Password:** `admin` (env: KEYCLOAK_ADMIN_PASSWORD)

### Database Connection

**Database:** `keycloak` on PostgreSQL  
**User:** `keycloak`  
**Password:** From `KEYCLOAK_DB_PASSWORD` environment variable  
**Connection String:** `postgresql://keycloak:password@postgres:5432/keycloak`

### Test Users

| Username | Password | Role | Group |
|----------|----------|------|-------|
| admin-dba | ChangeMe123! | ROLE_DBA | /DBAs |
| devops-user | ChangeMe123! | ROLE_DEVOPS | /DevOps |

**Note:** Passwords are temporary and must be changed on first login.

## Common Tasks

### Adding a New Client

1. Admin Console → Clients → Create client
2. Fill in Client ID (e.g., `grafana-client`)
3. Configure:
   - Client authentication: ON (for confidential clients)
   - Standard flow: ON (for web apps)
   - Direct access grants: OFF (recommended)
4. Set Redirect URIs
5. Save and configure credentials

### Creating a Role

1. Admin Console → Realm Roles → Create role
2. Enter role name (e.g., `ROLE_AUDITOR`)
3. Add description
4. Save

### Assigning Roles to Users

**Via User:**
1. Users → Select user → Role Mapping
2. Click "Assign role"
3. Select roles → Assign

**Via Group:**
1. Groups → Select group (e.g., DBAs)
2. Role Mapping → Assign roles
3. Members → Add users

### Resetting a User Password

1. Users → Select user
2. Credentials tab
3. Click "Reset password"
4. Enter new password
5. Toggle "Temporary" (user must change on next login)
6. Click "Save"

### Unlocking a Locked Account

1. Users → Select user
2. Credentials tab
3. Credential Reset actions
4. Click "Reset Login Failures"

## Troubleshooting

### Keycloak Won't Start

Check logs:
```bash
docker logs ai_infra_keycloak
```

Common issues:
- Database not accessible: Verify PostgreSQL is running
- Port conflict: Ensure port 8080 is available
- Configuration error: Check keycloak.conf syntax

### Realm Import Failed

1. Check JSON syntax in realm-export.json
2. Verify all referenced users/clients exist
3. Review startup logs for specific errors:
   ```bash
   docker logs ai_infra_keycloak | grep -i "import"
   ```

### Database Connection Issues

Test connection:
```bash
docker exec ai_infra_keycloak pg_isready -h postgres -U keycloak -d keycloak
```

Check environment variables:
```bash
docker exec ai_infra_keycloak env | grep KC_DB
```

### Performance Issues

Increase JVM memory:
```yaml
# In docker-compose.yml
environment:
  JAVA_OPTS: "-Xms512m -Xmx2g"
```

Enable query logging:
```conf
# In keycloak.conf
log-level=DEBUG
```

## Security Notes

### Production Deployment

Before deploying to production:

1. **Change Admin Password:**
   ```bash
   KEYCLOAK_ADMIN=production-admin
   KEYCLOAK_ADMIN_PASSWORD=<strong-random-password>
   ```

2. **Enable HTTPS:**
   - Generate SSL certificates
   - Update keycloak.conf
   - Configure NGINX for SSL termination

3. **Secure Client Secrets:**
   - Regenerate all client secrets
   - Store in secret management system
   - Never commit to version control

4. **Configure SMTP:**
   - Set up email for password reset
   - Enable email verification
   - Test email delivery

5. **Review Password Policy:**
   - Increase minimum length to 16
   - Enable all complexity rules
   - Configure password history

6. **Enable Audit Logging:**
   - Configure admin events: ON
   - Save admin events: ON
   - Configure event listeners

### Backup Recommendations

**What to Backup:**
- PostgreSQL `keycloak` database
- Realm export JSON
- Configuration files (keycloak.conf)
- Client secrets (from secret management)

**Backup Commands:**
```bash
# Database backup
docker exec ai_infra_postgres pg_dump -U postgres keycloak > keycloak_backup.sql

# Realm export (via Admin Console)
# Realm Settings → Export → Download

# Configuration files
cp docker/keycloak/keycloak.conf backups/keycloak.conf.$(date +%Y%m%d)
```

**Restore Procedures:**
```bash
# Restore database
cat keycloak_backup.sql | docker exec -i ai_infra_postgres psql -U postgres keycloak

# Realm import (place in docker/keycloak/ and restart)
docker-compose restart keycloak
```

## Additional Resources

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Server Administration Guide](https://www.keycloak.org/docs/latest/server_admin/)
- [Main Integration Guide](../../KEYCLOAK_INTEGRATION.md)
- [Environment Variables](../../../AI/DOCS/AI_Infra/ENV_VARIABLES.md)

