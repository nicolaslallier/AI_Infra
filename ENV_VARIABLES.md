# Environment Variables Documentation

This document provides detailed information about all environment variables used in the AI Infrastructure project.

## Table of Contents

- [Environment](#environment)
- [PostgreSQL Database](#postgresql-database)
- [Redis Cache](#redis-cache)
- [RabbitMQ Message Queue](#rabbitmq-message-queue)
- [Elasticsearch Search Engine](#elasticsearch-search-engine)
- [Monitoring Stack](#monitoring-stack)
- [Application Services](#application-services)
- [Security Configuration](#security-configuration)
- [External Services](#external-services)

---

## Environment

### ENVIRONMENT
- **Description**: Specifies the current environment
- **Values**: `development`, `staging`, `production`
- **Default**: `development`
- **Required**: Yes

### NODE_ENV
- **Description**: Node.js environment setting
- **Values**: `development`, `production`
- **Default**: `development`
- **Required**: Yes (for Node.js services)

---

## PostgreSQL Database

### POSTGRES_DB
- **Description**: Name of the PostgreSQL database
- **Default**: `app_db`
- **Required**: Yes
- **Format**: Alphanumeric with underscores

### POSTGRES_USER
- **Description**: PostgreSQL username
- **Default**: `postgres`
- **Required**: Yes
- **Security**: Change in production

### POSTGRES_PASSWORD
- **Description**: PostgreSQL password
- **Default**: `postgres`
- **Required**: Yes
- **Security**: Must be strong in production, minimum 16 characters

### POSTGRES_PORT
- **Description**: PostgreSQL port number
- **Default**: `5432`
- **Required**: Yes

### DATABASE_URL
- **Description**: Full PostgreSQL connection string
- **Format**: `postgresql://user:password@host:port/database`
- **Example**: `postgresql://postgres:postgres@postgres:5432/app_db`
- **Required**: Yes

---

## Redis Cache

### REDIS_PASSWORD
- **Description**: Redis authentication password
- **Default**: `redis`
- **Required**: Yes
- **Security**: Change in production

### REDIS_PORT
- **Description**: Redis port number
- **Default**: `6379`
- **Required**: Yes

### REDIS_URL
- **Description**: Full Redis connection string
- **Format**: `redis://:password@host:port/db`
- **Example**: `redis://:redis@redis:6379/0`
- **Required**: Yes

---

## RabbitMQ Message Queue

### RABBITMQ_USER
- **Description**: RabbitMQ username
- **Default**: `rabbitmq`
- **Required**: Yes

### RABBITMQ_PASSWORD
- **Description**: RabbitMQ password
- **Default**: `rabbitmq`
- **Required**: Yes
- **Security**: Change in production

### RABBITMQ_VHOST
- **Description**: RabbitMQ virtual host
- **Default**: `/`
- **Required**: Yes

### RABBITMQ_PORT
- **Description**: RabbitMQ AMQP port
- **Default**: `5672`
- **Required**: Yes

### RABBITMQ_MANAGEMENT_PORT
- **Description**: RabbitMQ management UI port
- **Default**: `15672`
- **Required**: Yes

### RABBITMQ_URL
- **Description**: Full RabbitMQ connection string
- **Format**: `amqp://user:password@host:port/vhost`
- **Example**: `amqp://rabbitmq:rabbitmq@rabbitmq:5672/`
- **Required**: Yes

---

## Elasticsearch Search Engine

### ELASTIC_PASSWORD
- **Description**: Elasticsearch built-in elastic user password
- **Default**: `elastic`
- **Required**: Yes
- **Security**: Must be strong in production

### ELASTICSEARCH_PORT
- **Description**: Elasticsearch HTTP port
- **Default**: `9200`
- **Required**: Yes

### ELASTICSEARCH_NODE_PORT
- **Description**: Elasticsearch transport port
- **Default**: `9300`
- **Required**: Yes

### ELASTICSEARCH_URL
- **Description**: Full Elasticsearch connection string
- **Format**: `http://username:password@host:port`
- **Example**: `http://elastic:elastic@elasticsearch:9200`
- **Required**: Yes

---

## Monitoring Stack

### PROMETHEUS_PORT
- **Description**: Prometheus web UI and API port
- **Default**: `9090`
- **Required**: Yes

### GRAFANA_PORT
- **Description**: Grafana web UI port
- **Default**: `3000`
- **Required**: Yes

### GRAFANA_USER
- **Description**: Grafana admin username
- **Default**: `admin`
- **Required**: Yes

### GRAFANA_PASSWORD
- **Description**: Grafana admin password
- **Default**: `admin`
- **Required**: Yes
- **Security**: Change immediately in production

### GRAFANA_PLUGINS
- **Description**: Comma-separated list of Grafana plugins to install
- **Example**: `grafana-clock-panel,grafana-simple-json-datasource`
- **Required**: No

### NODE_EXPORTER_PORT
- **Description**: Node Exporter metrics port
- **Default**: `9100`
- **Required**: Yes

### POSTGRES_EXPORTER_PORT
- **Description**: PostgreSQL Exporter metrics port
- **Default**: `9187`
- **Required**: Yes

### REDIS_EXPORTER_PORT
- **Description**: Redis Exporter metrics port
- **Default**: `9121`
- **Required**: Yes

---

## Application Services

### PYTHON_SERVICE_PORT
- **Description**: Python service HTTP port
- **Default**: `8000`
- **Required**: Yes

### NODEJS_SERVICE_PORT
- **Description**: Node.js service HTTP port
- **Default**: `3001`
- **Required**: Yes

### DEBUG
- **Description**: Enable debug mode for Python service
- **Values**: `true`, `false`
- **Default**: `false`
- **Required**: No

### LOG_LEVEL
- **Description**: Logging level
- **Values**: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL` (Python), `debug`, `info`, `warn`, `error` (Node.js)
- **Default**: `INFO` / `info`
- **Required**: Yes

### RELOAD
- **Description**: Enable auto-reload for Python service (development only)
- **Values**: `true`, `false`
- **Default**: `false`
- **Required**: No

---

## Security Configuration

### JWT_SECRET
- **Description**: Secret key for JWT token signing
- **Security**: Must be cryptographically random, minimum 32 characters
- **Required**: Yes
- **Generate**: `openssl rand -hex 32`

### JWT_ALGORITHM
- **Description**: Algorithm for JWT signing
- **Default**: `HS256`
- **Values**: `HS256`, `HS384`, `HS512`, `RS256`
- **Required**: Yes

### JWT_EXPIRATION
- **Description**: JWT token expiration time in seconds
- **Default**: `3600` (1 hour)
- **Required**: Yes

### API_KEY
- **Description**: API key for service authentication
- **Security**: Keep secret
- **Required**: Depends on implementation

---

## External Services

### AWS_ACCESS_KEY_ID
- **Description**: AWS access key for S3 and other services
- **Required**: Only if using AWS services
- **Security**: Never commit to repository

### AWS_SECRET_ACCESS_KEY
- **Description**: AWS secret access key
- **Required**: Only if using AWS services
- **Security**: Never commit to repository

### AWS_REGION
- **Description**: AWS region
- **Default**: `us-east-1`
- **Required**: Only if using AWS services

### S3_BUCKET_NAME
- **Description**: S3 bucket name for file storage
- **Required**: Only if using S3

### SENDGRID_API_KEY
- **Description**: SendGrid API key for email sending
- **Required**: Only if using SendGrid
- **Security**: Never commit to repository

### EMAIL_FROM
- **Description**: Default sender email address
- **Format**: Valid email address
- **Required**: If email functionality is used

### SENTRY_DSN
- **Description**: Sentry DSN for error tracking
- **Required**: Only if using Sentry
- **Format**: Full DSN URL

---

## CORS Configuration

### CORS_ORIGINS
- **Description**: Comma-separated list of allowed CORS origins
- **Example**: `http://localhost:3000,https://app.example.com`
- **Default**: `http://localhost:3000,http://localhost:8000`
- **Required**: Yes

### CORS_ALLOW_CREDENTIALS
- **Description**: Allow credentials in CORS requests
- **Values**: `true`, `false`
- **Default**: `true`
- **Required**: Yes

---

## Rate Limiting

### RATE_LIMIT_ENABLED
- **Description**: Enable rate limiting
- **Values**: `true`, `false`
- **Default**: `true`
- **Required**: No

### RATE_LIMIT_MAX_REQUESTS
- **Description**: Maximum number of requests per window
- **Default**: `100`
- **Required**: If rate limiting enabled

### RATE_LIMIT_WINDOW_MS
- **Description**: Time window for rate limiting in milliseconds
- **Default**: `60000` (1 minute)
- **Required**: If rate limiting enabled

---

## File Upload

### MAX_FILE_SIZE
- **Description**: Maximum file upload size in bytes
- **Default**: `10485760` (10 MB)
- **Required**: If file upload is enabled

### UPLOAD_DIR
- **Description**: Directory for temporary file uploads
- **Default**: `/tmp/uploads`
- **Required**: If file upload is enabled

---

## Backup Configuration

### BACKUP_ENABLED
- **Description**: Enable automatic backups
- **Values**: `true`, `false`
- **Default**: `true`
- **Required**: No

### BACKUP_SCHEDULE
- **Description**: Cron expression for backup schedule
- **Default**: `0 2 * * *` (2 AM daily)
- **Format**: Cron expression
- **Required**: If backups enabled

### BACKUP_RETENTION_DAYS
- **Description**: Number of days to retain backups
- **Default**: `7`
- **Required**: If backups enabled

---

## Best Practices

1. **Never commit `.env` file**: Always use `.env.example` as a template
2. **Use strong passwords**: Minimum 16 characters for production
3. **Rotate secrets regularly**: Change passwords and keys periodically
4. **Use environment-specific values**: Different secrets for dev/staging/prod
5. **Validate on startup**: Services should validate required environment variables
6. **Document changes**: Update this file when adding new variables
7. **Use secret management**: Consider using HashiCorp Vault, AWS Secrets Manager, etc. for production

---

## Troubleshooting

### Missing Environment Variables
If a service fails to start due to missing environment variables:
1. Check `.env` file exists
2. Verify all required variables are set
3. Ensure no typos in variable names
4. Check docker-compose reads the `.env` file

### Connection Issues
If services can't connect to each other:
1. Verify service names in connection strings match docker-compose service names
2. Check network configuration in docker-compose
3. Ensure ports are not conflicting
4. Verify credentials are correct

### Permission Issues
If you encounter permission errors:
1. Ensure volume permissions are correct
2. Check user/group IDs in Dockerfiles
3. Verify file ownership in mounted volumes

