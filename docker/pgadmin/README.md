# pgAdmin Configuration

This directory contains configuration files for pgAdmin4, the PostgreSQL administration tool.

## Configuration Files

### 1. `config_distro.py`
Distribution-level configuration that overrides pgAdmin defaults. This file is loaded early in the pgAdmin startup process.

**Key Settings:**
- `AUTHENTICATION_SOURCES`: Python list of authentication methods (internal, oauth2)
- `SERVER_MODE`: Enables multi-user server mode
- `MASTER_PASSWORD_REQUIRED`: Disables master password requirement

**Important:** `AUTHENTICATION_SOURCES` must be a Python list literal, not a string. Incorrect format will cause startup errors.

### 2. `config_local.py`
Local configuration with detailed settings for logging, authentication, and security.

**Features:**
- JSON structured logging for Loki integration
- OAuth2/OIDC integration with Keycloak
- Role-based access control mapping
- Security settings and audit logging
- Custom log formatters

**Authentication Configuration:**
- Supports both internal authentication and Keycloak SSO
- Automatically maps Keycloak roles to pgAdmin permissions:
  - `ROLE_DBA` or `/DBAs` group → Admin access
  - `ROLE_DEVOPS` or `/DevOps` group → Admin access
  - Others → Read-only access

### 3. `servers.json`
Pre-configured database server connections that appear automatically in pgAdmin.

**Default Connection:**
- Name: AI Infrastructure PostgreSQL
- Host: postgres (Docker service name)
- Port: 5432
- Database: app_db

## Environment Variables

The following environment variables can be configured in `.env` or docker-compose.yml:

### Core Settings
```bash
PGADMIN_DEFAULT_EMAIL=admin@example.com
PGADMIN_DEFAULT_PASSWORD=admin
PGADMIN_LOG_LEVEL=INFO  # DEBUG, INFO, WARNING, ERROR, CRITICAL
```

### Gunicorn Settings
```bash
GUNICORN_TIMEOUT=60  # Timeout in seconds for worker processes
```

### Keycloak OAuth2 Settings
```bash
PGADMIN_OAUTH2_NAME=Keycloak
PGADMIN_OAUTH2_DISPLAY_NAME="Login with Keycloak"
PGADMIN_OAUTH2_CLIENT_ID=pgadmin-client
PGADMIN_OAUTH2_CLIENT_SECRET=your-secret-here
PGADMIN_OAUTH2_SCOPE="openid email profile"
KEYCLOAK_URL=http://keycloak:8080
KEYCLOAK_REALM=infra-admin
```

## Common Issues and Troubleshooting

### Issue: `NameError: name 'internal' is not defined`

**Cause:** The `AUTHENTICATION_SOURCES` variable is being set as an unquoted string instead of a Python list.

**Solution:** Ensure `config_distro.py` has:
```python
AUTHENTICATION_SOURCES = ['internal', 'oauth2']  # Correct - Python list
```

NOT:
```python
AUTHENTICATION_SOURCES = internal,oauth2  # Wrong - undefined variables
```

### Issue: `gunicorn: error: argument -t/--timeout: invalid int value: ''`

**Cause:** The `GUNICORN_TIMEOUT` environment variable is empty or not set.

**Solution:** Set in docker-compose.yml or .env:
```yaml
environment:
  GUNICORN_TIMEOUT: ${PGADMIN_GUNICORN_TIMEOUT:-60}
```

### Issue: pgAdmin UI not accessible

**Check:**
1. Container is running: `docker ps | grep pgadmin`
2. Health check passes: `docker inspect ai_infra_pgadmin | grep Health`
3. Logs for errors: `docker logs ai_infra_pgadmin`
4. Nginx proxy configuration: Check `/monitoring/pgadmin/` path

### Issue: Keycloak SSO not working

**Troubleshooting:**
1. Verify Keycloak is running and healthy
2. Check client secret matches between pgAdmin and Keycloak
3. Verify redirect URIs are configured in Keycloak client:
   - `http://localhost/pgadmin/*`
   - `http://localhost:5050/pgadmin/*`
4. Check logs for OAuth2 errors: `docker logs ai_infra_pgadmin | grep -i oauth`

## Logging

pgAdmin logs are configured to output JSON-formatted structured logs to stdout, which are:
- Collected by Docker's JSON log driver
- Forwarded to Promtail
- Aggregated in Loki
- Visualized in Grafana dashboards

**Log Fields:**
- `timestamp`: ISO 8601 format
- `level`: DEBUG, INFO, WARNING, ERROR, CRITICAL
- `source`: Always "pgadmin"
- `message`: Log message content
- `module`: Python module name
- `function`: Function name
- `line`: Line number
- `user`: Username (when available)
- `database`: Database name (when available)
- `request_id`: Request correlation ID (when available)

## Security Best Practices

1. **Change Default Credentials:**
   ```bash
   PGADMIN_DEFAULT_EMAIL=your-email@company.com
   PGADMIN_DEFAULT_PASSWORD=strong-password-here
   ```

2. **Enable HTTPS in Production:**
   - Set `SESSION_COOKIE_SECURE = True` in `config_local.py`
   - Configure Nginx with SSL/TLS certificates

3. **Restrict OAuth2 Scopes:**
   - Only request necessary scopes
   - Review Keycloak client configuration

4. **Regular Security Updates:**
   - Keep pgAdmin image updated: `docker pull dpage/pgadmin4:latest`
   - Review security advisories

5. **Audit Logging:**
   - Enabled by default via `AUDIT_LOG_ENABLED = True`
   - Review logs regularly in Grafana

## File Mounting in Docker

The configuration files are mounted as read-only volumes:

```yaml
volumes:
  - ./docker/pgadmin/servers.json:/pgadmin4/servers.json:ro
  - ./docker/pgadmin/config_local.py:/pgadmin4/config_local.py:ro
  - ./docker/pgadmin/config_distro.py:/pgadmin4/config_distro.py:ro
```

**Note:** The `:ro` flag makes them read-only, preventing accidental modifications by pgAdmin.

## Access URLs

- **Development:** http://localhost/pgadmin/
- **Direct (if exposed):** http://localhost:5050/

## Testing Authentication

### Test Internal Authentication:
```bash
curl -X POST http://localhost/pgadmin/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","password":"admin"}'
```

### Test Keycloak SSO:
1. Navigate to http://localhost/pgadmin/
2. Click "Login with Keycloak"
3. Authenticate with Keycloak credentials
4. Verify redirect back to pgAdmin

## Maintenance

### Backup pgAdmin Configuration:
```bash
docker exec ai_infra_pgadmin /bin/sh -c "cd /var/lib/pgadmin && tar czf - ." > pgadmin-backup.tar.gz
```

### Restore pgAdmin Configuration:
```bash
cat pgadmin-backup.tar.gz | docker exec -i ai_infra_pgadmin /bin/sh -c "cd /var/lib/pgadmin && tar xzf -"
docker restart ai_infra_pgadmin
```

### View Real-time Logs:
```bash
# All logs
docker logs -f ai_infra_pgadmin

# Only errors
docker logs -f ai_infra_pgadmin 2>&1 | grep -i error

# Only authentication events
docker logs -f ai_infra_pgadmin 2>&1 | grep -i auth
```

## Integration with Monitoring Stack

pgAdmin metrics and logs are integrated with:

- **Prometheus:** Health check monitoring (via Nginx/blackbox exporter)
- **Loki:** Log aggregation (JSON structured logs)
- **Grafana:** Visualization via "pgAdmin Audit" dashboard
- **Tempo:** Request tracing (when enabled)

Dashboard: http://localhost/monitoring/grafana/ → "pgAdmin Audit"

## Development Tips

1. **Hot-reload Configuration:**
   - Modify `config_local.py` or `config_distro.py`
   - Restart container: `docker restart ai_infra_pgadmin`
   - No rebuild needed (files are mounted)

2. **Debug Mode:**
   ```bash
   docker exec -it ai_infra_pgadmin /bin/sh
   cat /pgadmin4/config_local.py  # Verify configuration
   ps aux | grep gunicorn         # Check processes
   ```

3. **Test Configuration Syntax:**
   ```bash
   docker exec ai_infra_pgadmin python3 -c "import config"
   ```

## References

- [pgAdmin Documentation](https://www.pgadmin.org/docs/)
- [pgAdmin Configuration Guide](https://www.pgadmin.org/docs/pgadmin4/latest/config_py.html)
- [Keycloak OpenID Connect](https://www.keycloak.org/docs/latest/securing_apps/)
- [Project Keycloak Integration Guide](../keycloak/README.md)

