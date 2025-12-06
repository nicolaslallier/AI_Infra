# AI Infrastructure

A production-ready, multi-service Docker infrastructure for AI applications with comprehensive monitoring, caching, message queuing, and search capabilities.

## 🏗️ Architecture Overview

This infrastructure provides a complete stack for building scalable AI applications:

- **Frontend**: Vue 3 SPA with TypeScript and Tailwind CSS
- **Identity & Access**: Keycloak for SSO, authentication, and RBAC
- **Database**: PostgreSQL 16 with pgAdmin web interface
- **Cache**: Redis 7 with persistence and clustering support
- **Message Queue**: RabbitMQ 3 with management UI
- **Search Engine**: Elasticsearch 8 with security enabled
- **Monitoring**: Prometheus + Grafana + Tempo + Loki with pre-configured dashboards
- **Application Services**: Python (FastAPI) + Node.js (TypeScript) microservices

### Network Architecture

Services are organized across isolated Docker networks following the principle of least privilege:

- `frontend-net`: Vue.js SPA, nginx reverse proxy, and pgAdmin UI
- `backend-net`: Application microservices (Python, Node.js)
- `database-net`: PostgreSQL database, pgAdmin, and postgres-exporter
- `monitoring-net`: Observability stack (Prometheus, Grafana, Tempo, Loki)

## 🚀 Quick Start

### Prerequisites

- Docker 20.10+
- Docker Compose 2.0+
- 8GB RAM minimum (16GB recommended)
- 20GB free disk space

### Initial Setup

1. **Clone and configure environment**:
```bash
cp .env.example .env
# Edit .env with your configuration
```

2. **Start all services**:
```bash
./scripts/start.sh
```

3. **Verify services are running**:
```bash
docker-compose ps
```

### Access Services

Once started, access the services at:

| Service | URL | Credentials |
|---------|-----|-------------|
| **Frontend Application** | http://localhost/ | - |
| **Keycloak Admin Console** | http://localhost/auth/ | admin / admin |
| **pgAdmin (Database UI)** | http://localhost/pgadmin/ | admin@example.com / admin OR Keycloak SSO |
| **Monitoring Dashboard** | http://localhost/monitoring/grafana/ | admin / admin |
| Prometheus | http://localhost/monitoring/prometheus/ | - |
| Tempo | http://localhost/monitoring/tempo/ | - |
| Loki | http://localhost/monitoring/loki/ | - |
| RabbitMQ Management | http://localhost:15672 | rabbitmq / rabbitmq |
| Elasticsearch | http://localhost:9200 | elastic / elastic |
| Python API | http://localhost:8000 | - |
| Node.js API | http://localhost:3001 | - |

**Note**: All monitoring services, Keycloak, and pgAdmin are accessible through nginx reverse proxy.

**Keycloak Test Users**:
- admin-dba / ChangeMe123! (DBA role)
- devops-user / ChangeMe123! (DevOps role)

## 📁 Project Structure

```
AI_Infra/
├── frontend/                    # Frontend application
│   └── ai-front/               # Vue 3 SPA (Git submodule)
├── docker/                      # Docker configurations
│   ├── nginx/                  # Nginx reverse proxy config
│   ├── postgres/               # PostgreSQL setup
│   │   ├── init/              # Initialization scripts
│   │   └── conf/              # Configuration files
│   ├── redis/                 # Redis configuration
│   ├── rabbitmq/              # RabbitMQ setup
│   ├── elasticsearch/         # Elasticsearch config
│   ├── prometheus/            # Prometheus configuration
│   │   └── alerts/            # Alert rules
│   ├── grafana/               # Grafana setup
│   │   ├── provisioning/      # Datasources & dashboards
│   │   └── dashboards/        # Pre-built dashboards
│   ├── tempo/                 # Tempo (distributed tracing)
│   ├── loki/                  # Loki (log aggregation)
│   ├── python-service/        # Python microservice
│   └── nodejs-service/        # Node.js microservice
├── scripts/                    # Utility scripts
│   ├── start.sh               # Start services
│   ├── stop.sh                # Stop services
│   ├── logs.sh                # View logs
│   ├── backup.sh              # Backup databases
│   └── seed-data.sh           # Load sample data
├── services/                   # Application code (to be added)
│   ├── python-service/
│   └── nodejs-service/
├── docker-compose.yml         # Main compose file
├── docker-compose.dev.yml     # Development overrides
├── .env.example               # Environment template
├── .cursorrules               # AI coding assistant rules
└── README.md                  # This file
```

## 🗄️ Database Management

### PostgreSQL Access

The infrastructure includes PostgreSQL 16 as the primary database with pgAdmin for web-based administration.

#### Connection Details

**Internal Connection (from application services)**:
```
Host: postgres
Port: 5432
Database: app_db
User: postgres
Password: <from POSTGRES_PASSWORD in .env>
Connection String: postgresql://postgres:password@postgres:5432/app_db
```

**Security Note**: PostgreSQL is only accessible on the internal `database-net` network (172.23.0.0/24). It is NOT exposed to external networks for security.

#### pgAdmin Web Interface

Access pgAdmin at: http://localhost/pgadmin/

1. Login with credentials from `.env`:
   - Email: `PGADMIN_DEFAULT_EMAIL` (default: admin@example.com)
   - Password: `PGADMIN_DEFAULT_PASSWORD` (default: admin)

2. The PostgreSQL server is pre-configured:
   - Server name: "AI Infrastructure PostgreSQL"
   - Connection details already set up
   - Just enter the PostgreSQL password when prompted

#### Database Operations

**Open PostgreSQL shell (psql)**:
```bash
make psql
```

**Backup database**:
```bash
make db-backup
```
Backups are saved to `backups/backup_YYYYMMDD_HHMMSS.sql`

**Restore database**:
```bash
make db-restore FILE=backups/backup_20231201_120000.sql
```

**View PostgreSQL logs**:
```bash
make logs-postgres
```

**View pgAdmin logs**:
```bash
make logs-pgadmin
```

**Open pgAdmin in browser**:
```bash
make pgadmin
```

### Database Monitoring

PostgreSQL metrics are automatically collected and available in Grafana:

1. Open Grafana: http://localhost/monitoring/grafana/
2. Navigate to "PostgreSQL Overview" dashboard
3. View metrics including:
   - Active connections
   - Transaction rate (commits/rollbacks)
   - Cache hit ratio
   - Query performance
   - Database locks
   - I/O activity

### Database Configuration

PostgreSQL is configured with production-ready settings:
- Max connections: 200
- Shared buffers: 256MB
- Effective cache size: 1GB
- Query logging for queries > 1 second
- Connection/disconnection logging
- Failed authentication logging
- SCRAM-SHA-256 password encryption

Configuration files:
- `docker/postgres/postgresql.conf` - Main configuration
- `docker/postgres/pg_hba.conf` - Client authentication

## 🛠️ Usage

### Starting Services

Start all services:
```bash
./scripts/start.sh
```

Start in production mode:
```bash
./scripts/start.sh --prod
```

Start specific services:
```bash
./scripts/start.sh -s postgres redis
```

Rebuild and start:
```bash
./scripts/start.sh --build
```

### Stopping Services

Stop all services:
```bash
./scripts/stop.sh
```

Stop and remove volumes (⚠️ deletes data):
```bash
./scripts/stop.sh --volumes
```

Complete cleanup:
```bash
./scripts/stop.sh --clean
```

### Viewing Logs

Follow all service logs:
```bash
./scripts/logs.sh
```

View specific service logs:
```bash
./scripts/logs.sh -s postgres
```

Show last 50 lines without following:
```bash
./scripts/logs.sh -t 50 --no-follow
```

### Database Backups

Create backup:
```bash
./scripts/backup.sh
```

Backup with custom retention:
```bash
./scripts/backup.sh --retention 30
```

Restore from backup:
```bash
gunzip < backups/postgres_backup_TIMESTAMP.sql.gz | \
  docker-compose exec -T postgres psql -U postgres -d app_db
```

## 🔧 Configuration

### Environment Variables

All configuration is managed through environment variables. See [ENV_VARIABLES.md](ENV_VARIABLES.md) for detailed documentation.

Key variables to configure:

- **Database**: `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`
- **Redis**: `REDIS_PASSWORD`
- **RabbitMQ**: `RABBITMQ_USER`, `RABBITMQ_PASSWORD`
- **Elasticsearch**: `ELASTIC_PASSWORD`
- **Security**: `JWT_SECRET`

### Service Configuration

Each service has dedicated configuration files in the `docker/` directory:

- PostgreSQL: `docker/postgres/conf/postgresql.conf`
- Redis: `docker/redis/redis.conf`
- RabbitMQ: `docker/rabbitmq/rabbitmq.conf`
- Elasticsearch: `docker/elasticsearch/config/elasticsearch.yml`
- Prometheus: `docker/prometheus/prometheus.yml`

## 📊 Monitoring

### Prometheus

Metrics collection is configured for all services. Access Prometheus at http://localhost:9090.

Available metrics:
- System metrics (CPU, memory, disk)
- PostgreSQL metrics (connections, queries, locks)
- Redis metrics (memory, keys, commands)
- RabbitMQ metrics (queues, messages, connections)
- Application metrics (requests, latency, errors)

### Grafana

Pre-configured dashboards are available at http://localhost:3000:

- **System Overview**: CPU, memory, and disk usage
- **PostgreSQL Dashboard**: Database performance metrics
- **Redis Dashboard**: Cache hit rates and memory usage
- **RabbitMQ Dashboard**: Queue depths and message rates

### Alerts

Alert rules are defined in `docker/prometheus/alerts/`. Alerts include:

- Service down notifications
- High memory/CPU usage
- Database connection exhaustion
- Redis memory limits
- RabbitMQ queue buildup

## 🔐 Security

### Production Deployment

Before deploying to production:

1. **Change all default passwords** in `.env`
2. **Generate strong JWT secret**: `openssl rand -hex 32`
3. **Enable SSL/TLS** for all external connections
4. **Configure firewall rules** to restrict access
5. **Set up secret management** (Vault, AWS Secrets Manager)
6. **Enable audit logging** for all services
7. **Configure backup retention** and test restore procedures
8. **Set up monitoring alerts** and on-call procedures

### Network Security

- Services communicate over isolated Docker networks
- Sensitive services (databases) are not exposed externally
- Use environment-specific network policies
- Implement API gateway for external access

## 🧪 Development

### Adding a New Service

1. Create Dockerfile in `docker/your-service/`
2. Add service definition to `docker-compose.yml`
3. Configure environment variables in `.env.example`
4. Add to appropriate Docker network(s)
5. Configure health checks and resource limits
6. Update documentation

### Local Development

For development with hot-reload:

```bash
./scripts/start.sh -f  # Run in foreground
```

Or use development compose file:

```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up
```

### Testing

Run tests for Python service:
```bash
docker-compose exec python-service pytest
```

Run tests for Node.js service:
```bash
docker-compose exec nodejs-service npm test
```

## 📖 Additional Documentation

- [Keycloak Integration Guide](KEYCLOAK_INTEGRATION.md) - Complete SSO and authentication setup
- [Environment Variables](ENV_VARIABLES.md) - Complete environment variable reference
- [Architecture Documentation](ARCHITECTURE.md) - Detailed system architecture
- [Nginx DNS Resolution](docker/README-NGINX-DNS.md) - Dynamic DNS resolution and service discovery
- [Database Implementation](DATABASE_IMPLEMENTATION.md) - Database setup and configuration
- [Logging Infrastructure](docker/README-LOGGING.md) - Centralized logging with Loki and Promtail
- [Cursor Rules](.cursorrules) - AI coding assistant configuration

## 🐛 Troubleshooting

### Services Won't Start

1. Check Docker is running: `docker info`
2. Verify port availability: `lsof -i :5432,6379,5672,9200`
3. Check logs: `./scripts/logs.sh`
4. Ensure sufficient resources: `docker system df`

### Nginx DNS Resolution Issues

If Nginx fails to start with "host not found in upstream" errors:
1. **Cause**: This is normal - Nginx now uses runtime DNS resolution
2. **Solution**: Services will become available as they start up
3. **Verification**: Check that services are healthy: `docker-compose ps`
4. **Details**: See [Nginx DNS Resolution Guide](docker/README-NGINX-DNS.md)

The infrastructure is designed to handle services starting in any order. Nginx will automatically discover services as they become available.

### Database Connection Errors

1. Verify PostgreSQL is healthy: `docker-compose ps postgres`
2. Check database logs: `./scripts/logs.sh -s postgres`
3. Verify credentials in `.env`
4. Test connection: `docker-compose exec postgres psql -U postgres`

### Memory Issues

1. Check Docker resource limits: Docker Desktop → Resources
2. Review service memory limits in `docker-compose.yml`
3. Monitor usage: `docker stats`

### Performance Issues

1. Check Grafana dashboards for bottlenecks
2. Review slow query logs in PostgreSQL
3. Monitor Redis memory usage and hit rates
4. Check RabbitMQ queue depths
5. Review application logs for errors

## 🤝 Contributing

1. Follow the coding standards defined in `.cursorrules`
2. Write tests for all new features
3. Update documentation
4. Use conventional commit messages
5. Request architectural review for major changes

## 📝 License

This project is licensed under the MIT License.

## 🆘 Support

For issues and questions:
1. Check [Troubleshooting](#troubleshooting) section
2. Review service-specific documentation
3. Check Docker and service logs
4. Create an issue with detailed information

---

**Built with ❤️ for scalable AI applications**

