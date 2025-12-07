# MinIO Configuration

This directory contains configuration files for the MinIO object storage cluster.

## Files

### minio-config.env
Environment variable template for MinIO server configuration. This file defines:
- Root credentials (admin access)
- Keycloak OIDC integration settings
- Prometheus metrics configuration
- Audit logging settings
- Browser and console settings

### policy-templates/
IAM policy definitions for different service accounts:

#### backup-service-policy.json
Read/write access to the `backups-postgresql` bucket for automated backup services.

#### readonly-policy.json
Read-only access to `logs-exports` and `app-files` buckets for monitoring and application access.

#### admin-policy.json
Full administrative access to all buckets and resources.

## Usage

### Applying Policies
Use the management scripts in `scripts/minio/` to create service accounts and assign policies:

```bash
# Create a service account for PostgreSQL backups
./scripts/minio/create-service-account.sh backup-service

# Assign the backup policy
./scripts/minio/assign-policy.sh backup-service backup-service-policy
```

## Security Notes

1. **Root Credentials**: Change `MINIO_ROOT_PASSWORD` in production
2. **Keycloak Secret**: Generate `MINIO_IDENTITY_OPENID_CLIENT_SECRET` from Keycloak console
3. **Service Accounts**: Use separate service accounts with minimal permissions
4. **Encryption**: Enable server-side encryption for sensitive buckets
5. **Audit Logs**: All operations are logged to Loki for compliance

## Network Access

MinIO cluster is accessible through:
- S3 API: `http://localhost/storage/` (via NGINX)
- Console UI: `http://localhost/minio-console/` (via NGINX)

Direct access to MinIO nodes is restricted to the `storage-net` network.

