# pgAdmin Quick Reference Card

## Quick Commands

```bash
# Start pgAdmin
docker-compose up -d pgadmin

# Stop pgAdmin
docker-compose stop pgadmin

# Restart pgAdmin
docker restart ai_infra_pgadmin

# View logs
docker logs -f ai_infra_pgadmin

# Check health
docker inspect ai_infra_pgadmin | grep Health

# Verify configuration
./scripts/verify-pgadmin.sh

# Recreate container (after config changes)
docker-compose stop pgadmin && docker-compose rm -f pgadmin && docker-compose up -d pgadmin
```

## Access URLs

- **Web Interface:** http://localhost/pgadmin/
- **Login Endpoint:** http://localhost/pgadmin/login
- **Health Check:** http://localhost/pgadmin/misc/ping

## Default Credentials

```
Email: admin@example.com
Password: admin
```

⚠️ **Change these in production!**

## Configuration Files

| File | Purpose | Location |
|------|---------|----------|
| `config_distro.py` | Distribution-level config | `/docker/pgadmin/config_distro.py` |
| `config_local.py` | Local customizations | `/docker/pgadmin/config_local.py` |
| `servers.json` | Pre-configured servers | `/docker/pgadmin/servers.json` |
| `docker-compose.yml` | Container config | `/docker-compose.yml` |

## Environment Variables

```bash
# Core Settings
PGADMIN_DEFAULT_EMAIL=admin@example.com
PGADMIN_DEFAULT_PASSWORD=admin
PGADMIN_LOG_LEVEL=INFO

# Gunicorn
GUNICORN_TIMEOUT=60

# Keycloak OAuth2
PGADMIN_OAUTH2_CLIENT_ID=pgadmin-client
PGADMIN_OAUTH2_CLIENT_SECRET=your-secret
KEYCLOAK_URL=http://keycloak:8080
KEYCLOAK_REALM=infra-admin
```

## Common Issues

### Container won't start
```bash
# Check logs
docker logs ai_infra_pgadmin | tail -50

# Common causes:
# 1. NameError: internal not defined → Check config_distro.py syntax
# 2. Permission denied → Check LOG_FILE setting
# 3. Gunicorn timeout → Check GUNICORN_TIMEOUT env var
```

### Health check failing
```bash
# Test endpoint directly
curl -I http://localhost/pgadmin/login

# Should return: HTTP/1.1 200 OK
```

### Can't login
```bash
# Check default credentials
docker exec ai_infra_pgadmin cat /pgadmin4/config_local.py | grep DEFAULT

# Reset admin password (inside container)
docker exec -it ai_infra_pgadmin python3 /pgadmin4/setup.py
```

## Troubleshooting Checklist

- [ ] Container is running: `docker ps | grep pgadmin`
- [ ] Container is healthy: `docker inspect ai_infra_pgadmin | grep Health`
- [ ] No errors in logs: `docker logs ai_infra_pgadmin | grep ERROR`
- [ ] Config files mounted: `docker exec ai_infra_pgadmin ls -la /pgadmin4/config_*.py`
- [ ] HTTP endpoint responds: `curl http://localhost/pgadmin/login`
- [ ] Postgres is running: `docker ps | grep postgres`

## Backup & Restore

### Backup
```bash
docker exec ai_infra_pgadmin tar czf - /var/lib/pgadmin > pgadmin-backup-$(date +%Y%m%d).tar.gz
```

### Restore
```bash
cat pgadmin-backup-20251206.tar.gz | docker exec -i ai_infra_pgadmin tar xzf -
docker restart ai_infra_pgadmin
```

## Monitoring

**Grafana Dashboard:** http://localhost/monitoring/grafana/  
**Dashboard Name:** "pgAdmin Audit"

**Key Metrics:**
- Login attempts (success/failure)
- Query execution count
- User actions
- Error rate

## Security Checklist

- [ ] Changed default credentials
- [ ] HTTPS enabled in production
- [ ] OAuth2 configured with Keycloak
- [ ] Config files mounted read-only
- [ ] Regular security updates
- [ ] Audit logs reviewed regularly

## Documentation

- **Full Documentation:** `/docker/pgadmin/README.md`
- **Fix Details:** `/PGADMIN-STARTUP-FIX.md`
- **Completion Summary:** `/PGADMIN-FIX-COMPLETE.md`

## Support

**Run diagnostics:**
```bash
./scripts/verify-pgadmin.sh
```

**Get detailed logs:**
```bash
docker logs ai_infra_pgadmin > pgadmin-logs.txt
```

**Check configuration:**
```bash
docker exec ai_infra_pgadmin python3 -c "import config; print('OK')"
```

---

*Last Updated: December 6, 2025*

