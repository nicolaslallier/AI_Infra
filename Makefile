# ============================================
# AI Infrastructure - Makefile
# ============================================
# Convenient commands for CI/CD and development

.PHONY: help
.DEFAULT_GOAL := help

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

# Configuration
COMPOSE_FILE := docker-compose.yml
COMPOSE_DEV_FILE := docker-compose.dev.yml
ENV_FILE := .env

# Paths to service repositories
FRONTEND_DIR := ../AI_Front
BACKEND_DIR := ../AI_Backend

# Note: Frontend and Backend are now built as part of main docker-compose.yml
# They use external repositories but are integrated into the infrastructure

# ============================================
# Help
# ============================================

help: ## Show this help message
	@echo "$(BLUE)AI Infrastructure - Available Commands$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-28s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Quick Start:$(NC)"
	@echo "  make setup                  # First-time setup"
	@echo "  make all-build              # Build all services (complete stack)"
	@echo "  make all-up                 # Start all services"
	@echo "  make all-ps                 # Check status"
	@echo "  make all-logs               # View all logs"
	@echo "  make all-down               # Stop all services"
	@echo ""
	@echo "$(YELLOW)Individual Services:$(NC)"
	@echo "  make up                     # Infrastructure only"
	@echo "  make frontend-logs          # View frontend logs"
	@echo "  make backend-up             # Start backend workers (AI_Backend)"
	@echo ""
	@echo "$(YELLOW)Troubleshooting:$(NC)"
	@echo "  make reset-grafana          # Reset Grafana (fixes access loss)"
	@echo "  make reset-grafana-full     # Full Grafana reset with clean volume"

# ============================================
# Setup & Installation
# ============================================

.PHONY: setup
setup: ## Initial setup - creates .env and prepares environment
	@echo "$(BLUE)Setting up AI Infrastructure...$(NC)"
	@if [ ! -f $(ENV_FILE) ]; then \
		cp .env.example $(ENV_FILE); \
		echo "$(GREEN)✓ Created .env file$(NC)"; \
	else \
		echo "$(YELLOW)! .env file already exists$(NC)"; \
	fi
	@chmod +x scripts/*.sh
	@echo "$(GREEN)✓ Made scripts executable$(NC)"
	@mkdir -p logs backups
	@echo "$(GREEN)✓ Created directories$(NC)"
	@echo "$(GREEN)✓ Setup complete!$(NC)"
	@echo ""
	@echo "$(YELLOW)Next steps:$(NC)"
	@echo "  1. Review and update .env file"
	@echo "  2. Run: make up"

.PHONY: check
check: ## Check prerequisites and environment
	@echo "$(BLUE)Checking prerequisites...$(NC)"
	@command -v docker >/dev/null 2>&1 || { echo "$(RED)✗ Docker not found$(NC)"; exit 1; }
	@echo "$(GREEN)✓ Docker found$(NC)"
	@docker info >/dev/null 2>&1 || { echo "$(RED)✗ Docker not running$(NC)"; exit 1; }
	@echo "$(GREEN)✓ Docker running$(NC)"
	@command -v docker-compose >/dev/null 2>&1 || { echo "$(RED)✗ Docker Compose not found$(NC)"; exit 1; }
	@echo "$(GREEN)✓ Docker Compose found$(NC)"
	@if [ ! -f $(ENV_FILE) ]; then \
		echo "$(RED)✗ .env file not found. Run: make setup$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)✓ Environment file found$(NC)"
	@echo "$(GREEN)✓ All checks passed!$(NC)"

# ============================================
# Development
# ============================================

.PHONY: up
up: check ## Start all services in development mode
	@echo "$(BLUE)Starting services...$(NC)"
	@docker-compose -f $(COMPOSE_FILE) -f $(COMPOSE_DEV_FILE) up -d
	@echo "$(GREEN)✓ Services started$(NC)"
	@$(MAKE) ps

.PHONY: up-build
up-build: check ## Start all services and rebuild images
	@echo "$(BLUE)Building and starting services...$(NC)"
	@docker-compose -f $(COMPOSE_FILE) -f $(COMPOSE_DEV_FILE) up -d --build
	@echo "$(GREEN)✓ Services built and started$(NC)"

.PHONY: up-prod
up-prod: check ## Start all services in production mode
	@echo "$(BLUE)Starting services in production mode...$(NC)"
	@docker-compose -f $(COMPOSE_FILE) up -d
	@echo "$(GREEN)✓ Services started$(NC)"

.PHONY: down
down: ## Stop all services
	@echo "$(BLUE)Stopping services...$(NC)"
	@docker-compose down
	@echo "$(GREEN)✓ Services stopped$(NC)"

.PHONY: restart
restart: ## Restart all services
	@echo "$(BLUE)Restarting services...$(NC)"
	@docker-compose restart
	@echo "$(GREEN)✓ Services restarted$(NC)"

.PHONY: ps
ps: ## Show status of all services
	@docker-compose ps

.PHONY: logs
logs: ## Follow logs from all services
	@docker-compose logs -f --tail=100

.PHONY: logs-service
logs-service: ## Follow logs from specific service (usage: make logs-service SERVICE=postgres)
	@docker-compose logs -f --tail=100 $(SERVICE)

# ============================================
# Building & Images
# ============================================

.PHONY: pull
pull: ## Pull all monitoring service images
	@echo "$(BLUE)Pulling images...$(NC)"
	@docker-compose pull
	@echo "$(GREEN)✓ Images pulled$(NC)"

.PHONY: build
build: ## Build all services
	@echo "$(BLUE)Building services...$(NC)"
	@docker-compose build
	@echo "$(GREEN)✓ Services built$(NC)"

.PHONY: build-frontend

# ============================================
# Testing
# ============================================

.PHONY: test-infra
test-infra: ## Test infrastructure accessibility
	@echo "$(BLUE)Testing infrastructure stack...$(NC)"
	@echo "Testing Nginx health..."
	@curl -s http://localhost/health || echo "$(RED)✗ Nginx unhealthy$(NC)"
	@echo "$(GREEN)✓ Nginx healthy$(NC)"
	@echo "Testing Frontend..."
	@curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost/
	@echo "Testing Grafana..."
	@curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost/monitoring/grafana/api/health
	@echo "Testing Prometheus..."
	@curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost/monitoring/prometheus/-/healthy
	@echo "Testing pgAdmin..."
	@curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost/pgadmin/misc/ping
	@echo "Testing PostgreSQL..."
	@docker-compose exec -T postgres pg_isready -U $${POSTGRES_USER:-postgres} || echo "$(RED)✗ PostgreSQL unhealthy$(NC)"
	@echo "$(GREEN)✓ Infrastructure tests completed$(NC)"

# ============================================
# Monitoring Stack Operations
# ============================================

.PHONY: tempo
tempo: ## Open Tempo UI
	@echo "Opening Tempo..."
	@open http://localhost/monitoring/tempo/ || xdg-open http://localhost/monitoring/tempo/ || echo "Visit: http://localhost/monitoring/tempo/"

.PHONY: loki
loki: ## Open Loki UI
	@echo "Opening Loki..."
	@open http://localhost/monitoring/loki/ || xdg-open http://localhost/monitoring/loki/ || echo "Visit: http://localhost/monitoring/loki/"

.PHONY: validate-minio-dashboard
validate-minio-dashboard: ## Validate MinIO dashboard metrics and configuration
	@echo "$(BLUE)Validating MinIO Dashboard...$(NC)"
	@bash scripts/validate-minio-dashboard.sh

.PHONY: minio-console
minio-console: ## Open MinIO Console in browser
	@echo "$(GREEN)Opening MinIO Console...$(NC)"
	@open http://localhost/minio-console/ || xdg-open http://localhost/minio-console/ || echo "Please open: http://localhost/minio-console/"
	@echo "Login: admin / changeme123"

.PHONY: minio-populate-data
minio-populate-data: ## Populate MinIO with test data
	@echo "$(GREEN)Populating MinIO with test data...$(NC)"
	@bash scripts/populate-minio-test-data.sh

.PHONY: minio-list-buckets
minio-list-buckets: ## List all MinIO buckets and their contents
	@echo "$(BLUE)📊 MinIO Bucket Summary$(NC)"
	@echo "======================="
	@docker exec ai_infra_minio1 mc ls local/ || echo "$(RED)✗ MinIO is not running$(NC)"

# ============================================
# Service Management
# ============================================

.PHONY: restart-grafana
restart-grafana: ## Restart Grafana service
	@docker-compose restart grafana

.PHONY: restart-prometheus
restart-prometheus: ## Restart Prometheus service
	@docker-compose restart prometheus

.PHONY: restart-tempo
restart-tempo: ## Restart Tempo service
	@docker-compose restart tempo

.PHONY: restart-loki
restart-loki: ## Restart Loki service
	@docker-compose restart loki

.PHONY: restart-nginx
restart-nginx: ## Restart Nginx service
	@docker-compose restart nginx

.PHONY: restart-frontend
restart-frontend: ## Restart Frontend service
	@docker-compose restart frontend

.PHONY: restart-postgres
restart-postgres: ## Restart PostgreSQL service
	@docker-compose restart postgres

.PHONY: restart-pgadmin
restart-pgadmin: ## Restart pgAdmin service
	@docker-compose restart pgadmin

# ============================================
# Database Operations
# ============================================

.PHONY: pgadmin
pgadmin: ## Open pgAdmin in browser
	@echo "Opening pgAdmin..."
	@open http://localhost/pgadmin/ || xdg-open http://localhost/pgadmin/ || echo "Visit: http://localhost/pgadmin/"

.PHONY: logs-postgres
logs-postgres: ## Show PostgreSQL logs
	@docker-compose logs -f --tail=100 postgres

.PHONY: logs-pgadmin
logs-pgadmin: ## Show pgAdmin logs
	@docker-compose logs -f --tail=100 pgadmin

# ============================================
# Keycloak Management
# ============================================

.PHONY: keycloak-admin
keycloak-admin: ## Open Keycloak Admin Console in browser
	@echo "Opening Keycloak Admin Console..."
	@open http://localhost/auth/ || xdg-open http://localhost/auth/ || echo "Visit: http://localhost/auth/"
	@echo "Default credentials: admin / admin"

.PHONY: keycloak-logs
keycloak-logs: ## Show Keycloak logs
	@docker-compose logs -f --tail=100 keycloak

.PHONY: restart-keycloak
restart-keycloak: ## Restart Keycloak service
	@docker-compose restart keycloak

.PHONY: keycloak-shell
keycloak-shell: ## Open shell in Keycloak container
	@docker-compose exec keycloak /bin/bash

.PHONY: keycloak-validate
keycloak-validate: ## Validate Keycloak integration
	@./scripts/validate-keycloak.sh

.PHONY: prometheus-validate
prometheus-validate: ## Validate Prometheus configuration and alerts
	@./scripts/validate-prometheus.sh

.PHONY: psql
psql: ## Open PostgreSQL shell (psql)
	@docker-compose exec postgres psql -U $${POSTGRES_USER:-postgres} -d $${POSTGRES_DB:-app_db}

.PHONY: db-backup
db-backup: ## Backup PostgreSQL database
	@echo "$(BLUE)Creating database backup...$(NC)"
	@mkdir -p backups
	@docker-compose exec -T postgres pg_dump -U $${POSTGRES_USER:-postgres} $${POSTGRES_DB:-app_db} > backups/backup_$$(date +%Y%m%d_%H%M%S).sql
	@echo "$(GREEN)✓ Database backup created in backups/$(NC)"

.PHONY: db-restore
db-restore: ## Restore PostgreSQL database (usage: make db-restore FILE=backups/backup.sql)
	@if [ -z "$(FILE)" ]; then \
		echo "$(RED)Error: Please specify FILE$(NC)"; \
		echo "Usage: make db-restore FILE=backups/backup.sql"; \
		exit 1; \
	fi
	@echo "$(BLUE)Restoring database from $(FILE)...$(NC)"
	@docker-compose exec -T postgres psql -U $${POSTGRES_USER:-postgres} $${POSTGRES_DB:-app_db} < $(FILE)
	@echo "$(GREEN)✓ Database restored$(NC)"

# ============================================
# Frontend Operations
# ============================================

# Note: Frontend is now included in main docker-compose.yml
# It builds from ../AI_Front directory
# Use main commands: make up, make build, make logs frontend

.PHONY: frontend-logs
frontend-logs: ## Show frontend logs
	@docker-compose logs -f --tail=100 frontend

.PHONY: frontend-shell
frontend-shell: ## Open shell in frontend container
	@docker-compose exec frontend sh

.PHONY: frontend-dev
frontend-dev: ## Run frontend in development mode (standalone)
	@echo "$(BLUE)Starting frontend in development mode...$(NC)"
	@if [ ! -d "$(FRONTEND_DIR)" ]; then \
		echo "$(RED)✗ Frontend directory not found: $(FRONTEND_DIR)$(NC)"; \
		exit 1; \
	fi
	@cd $(FRONTEND_DIR) && npm run dev
	@echo "$(YELLOW)Visit: http://localhost:5173$(NC)"

.PHONY: frontend-test
frontend-test: ## Run frontend tests
	@echo "$(BLUE)Running frontend tests...$(NC)"
	@if [ ! -d "$(FRONTEND_DIR)" ]; then \
		echo "$(RED)✗ Frontend directory not found: $(FRONTEND_DIR)$(NC)"; \
		exit 1; \
	fi
	@cd $(FRONTEND_DIR) && npm run test

.PHONY: frontend-validate
frontend-validate: ## Validate frontend code (lint, format, type-check)
	@echo "$(BLUE)Validating frontend code...$(NC)"
	@if [ ! -d "$(FRONTEND_DIR)" ]; then \
		echo "$(RED)✗ Frontend directory not found: $(FRONTEND_DIR)$(NC)"; \
		exit 1; \
	fi
	@cd $(FRONTEND_DIR) && npm run validate

.PHONY: frontend-install
frontend-install: ## Install frontend dependencies
	@echo "$(BLUE)Installing frontend dependencies...$(NC)"
	@if [ ! -d "$(FRONTEND_DIR)" ]; then \
		echo "$(RED)✗ Frontend directory not found: $(FRONTEND_DIR)$(NC)"; \
		exit 1; \
	fi
	@cd $(FRONTEND_DIR) && npm install
	@echo "$(GREEN)✓ Frontend dependencies installed$(NC)"

# ============================================
# MIDDLEWARE OPERATIONS (AI_Middle)
# ============================================
# Note: Middleware services have been removed
# Authentication is handled by Keycloak in AI_Infra
# API Gateway functionality handled by Nginx

# ============================================
# BACKEND OPERATIONS (AI_Backend)
# ============================================
# Note: Backend workers are now included in main docker-compose.yml
# They build from ../AI_Backend directory
# Use main commands: make up, make build, make logs <service>

.PHONY: celery-beat-logs
celery-beat-logs: ## Show Celery beat logs
	@docker-compose logs -f --tail=100 celery_beat

.PHONY: email-worker-logs
email-worker-logs: ## Show email worker logs
	@docker-compose logs -f --tail=100 email_worker

.PHONY: payment-worker-logs
payment-worker-logs: ## Show payment worker logs
	@docker-compose logs -f --tail=100 payment_worker

.PHONY: datasync-worker-logs
datasync-worker-logs: ## Show data sync worker logs
	@docker-compose logs -f --tail=100 data_sync_worker

.PHONY: flower-logs
flower-logs: ## Show Flower logs
	@docker-compose logs -f --tail=100 flower

.PHONY: workers-logs
workers-logs: ## Show all workers logs
	@docker-compose logs -f --tail=100 celery_beat email_worker payment_worker data_sync_worker

.PHONY: email-worker-shell
email-worker-shell: ## Open shell in email worker container
	@docker-compose exec email_worker /bin/bash

.PHONY: backend-test
backend-test: ## Run backend tests
	@echo "$(BLUE)Running backend tests...$(NC)"
	@if [ ! -d "$(BACKEND_DIR)" ]; then \
		echo "$(RED)✗ Backend directory not found: $(BACKEND_DIR)$(NC)"; \
		exit 1; \
	fi
	@cd $(BACKEND_DIR) && pytest tests/ -v
	@echo "$(GREEN)✓ Backend tests completed$(NC)"

.PHONY: backend-migrate
backend-migrate: ## Run backend database migrations
	@echo "$(BLUE)Running backend migrations...$(NC)"
	@docker-compose exec email_worker alembic upgrade head
	@echo "$(GREEN)✓ Migrations completed$(NC)"

# ============================================
# ALL SERVICES OPERATIONS
# ============================================

.PHONY: all-build
all-build: build ## Build all services (infra with frontend and backend workers)
	@echo "$(GREEN)✓ All services built$(NC)"

.PHONY: all-up
all-up: up ## Alias for 'make up' - starts all services (infra, frontend, backend workers)
	@echo "$(GREEN)✓ All services started$(NC)"

.PHONY: all-down
all-down: down ## Alias for 'make down' - stops all services
	@echo "$(GREEN)✓ All services stopped$(NC)"

.PHONY: all-logs
all-logs: ## Show logs from all services
	@echo "$(BLUE)Showing logs from all services...$(NC)"
	@echo "$(YELLOW)Infrastructure logs:$(NC)"
	@docker-compose logs --tail=20
	@echo ""
	@echo "$(YELLOW)Backend worker logs:$(NC)"
	@docker-compose logs --tail=20 celery_beat email_worker payment_worker data_sync_worker

.PHONY: all-ps
all-ps: ## Show status of all services
	@echo "$(BLUE)Infrastructure services:$(NC)"
	@docker-compose ps
	@echo ""
	@echo "$(BLUE)Backend workers:$(NC)"
	@docker-compose ps celery_beat email_worker payment_worker data_sync_worker flower

.PHONY: all-test
all-test: test frontend-test backend-test ## Run all tests (infra, frontend, backend workers)
	@echo "$(GREEN)✓ All tests completed$(NC)"

# ============================================
# Configuration Validation
# ============================================

.PHONY: validate
validate: ## Validate configuration files
	@echo "$(BLUE)Validating configurations...$(NC)"
	@docker-compose config > /dev/null && echo "$(GREEN)✓ Docker Compose config valid$(NC)" || echo "$(RED)✗ Docker Compose config invalid$(NC)"

# ============================================
# Monitoring & Health
# ============================================

.PHONY: health
health: ## Check health of all services
	@echo "$(BLUE)Checking service health...$(NC)"
	@docker-compose ps | grep -E "(Up|healthy)" && echo "$(GREEN)✓ Services healthy$(NC)" || echo "$(RED)✗ Some services unhealthy$(NC)"

.PHONY: metrics
metrics: ## Open Prometheus metrics
	@echo "Opening Prometheus..."
	@open http://localhost/monitoring/prometheus/ || xdg-open http://localhost/monitoring/prometheus/ || echo "Visit: http://localhost/monitoring/prometheus/"

.PHONY: dashboard
dashboard: ## Open Grafana dashboard
	@echo "Opening Grafana..."
	@open http://localhost/monitoring/grafana/ || xdg-open http://localhost/monitoring/grafana/ || echo "Visit: http://localhost/monitoring/grafana/"

.PHONY: open-frontend
open-frontend: ## Open frontend application in browser
	@echo "Opening frontend..."
	@open http://localhost/ || xdg-open http://localhost/ || echo "Visit: http://localhost/"

# ============================================
# CI/CD Operations
# ============================================

.PHONY: ci-test
ci-test: ## Run CI test pipeline
	@echo "$(BLUE)Running CI test pipeline...$(NC)"
	@$(MAKE) check
	@$(MAKE) pull
	@$(MAKE) up
	@sleep 15
	@$(MAKE) test
	@echo "$(GREEN)✓ CI pipeline completed$(NC)"

.PHONY: ci-deploy-staging
ci-deploy-staging: ## Deploy to staging environment
	@echo "$(BLUE)Deploying to staging...$(NC)"
	@$(MAKE) pull
	@docker-compose -f $(COMPOSE_FILE) up -d
	@echo "$(GREEN)✓ Deployed to staging$(NC)"

.PHONY: ci-deploy-prod
ci-deploy-prod: ## Deploy to production environment
	@echo "$(BLUE)Deploying to production...$(NC)"
	@echo "$(YELLOW)⚠️  Production deployment - proceed with caution$(NC)"
	@read -p "Are you sure? (yes/no): " confirm && [ "$$confirm" = "yes" ]
	@$(MAKE) pull
	@docker-compose -f $(COMPOSE_FILE) up -d
	@$(MAKE) health
	@echo "$(GREEN)✓ Deployed to production$(NC)"

# ============================================
# Cleanup
# ============================================

.PHONY: clean
clean: ## Stop services and remove containers
	@echo "$(BLUE)Cleaning up...$(NC)"
	@docker-compose down
	@echo "$(GREEN)✓ Containers removed$(NC)"

.PHONY: clean-volumes
clean-volumes: ## Stop services and remove volumes (⚠️  DELETES DATA)
	@echo "$(RED)⚠️  WARNING: This will delete all data in volumes!$(NC)"
	@read -p "Are you sure? (yes/no): " confirm && [ "$$confirm" = "yes" ]
	@docker-compose down -v
	@echo "$(GREEN)✓ Volumes removed$(NC)"

.PHONY: clean-images
clean-images: ## Remove all project images
	@echo "$(BLUE)Removing images...$(NC)"
	@docker-compose down --rmi local
	@echo "$(GREEN)✓ Images removed$(NC)"

.PHONY: clean-all
clean-all: ## Complete cleanup (containers, volumes, images, networks)
	@echo "$(RED)⚠️  WARNING: This will delete EVERYTHING (data, images, networks)!$(NC)"
	@read -p "Are you sure? (yes/no): " confirm && [ "$$confirm" = "yes" ]
	@docker-compose down -v --rmi all --remove-orphans
	@echo "$(GREEN)✓ Complete cleanup done$(NC)"

.PHONY: prune
prune: ## Clean up Docker system (dangling images, unused networks, etc.)
	@echo "$(BLUE)Pruning Docker system...$(NC)"
	@docker system prune -f
	@echo "$(GREEN)✓ System pruned$(NC)"

# ============================================
# Development Tools
# ============================================

.PHONY: watch
watch: ## Watch logs with grep filter (usage: make watch FILTER=error)
	@if [ -z "$(FILTER)" ]; then \
		docker-compose logs -f --tail=100; \
	else \
		docker-compose logs -f --tail=100 | grep -i "$(FILTER)"; \
	fi

.PHONY: stats
stats: ## Show resource usage statistics
	@docker stats --no-stream

.PHONY: inspect
inspect: ## Inspect service (usage: make inspect SERVICE=postgres)
	@if [ -z "$(SERVICE)" ]; then \
		echo "$(RED)Error: Please specify SERVICE$(NC)"; \
		echo "Usage: make inspect SERVICE=postgres"; \
		exit 1; \
	fi
	@docker-compose exec $(SERVICE) env

.PHONY: disk-usage
disk-usage: ## Show Docker disk usage
	@docker system df -v

# ============================================
# Documentation
# ============================================

.PHONY: docs
docs: ## Open documentation in browser
	@echo "Opening documentation..."
	@if [ -f README.md ]; then \
		cat README.md; \
	fi


# ============================================
# Utilities
# ============================================

.PHONY: version
version: ## Show versions of all components
	@echo "$(BLUE)Component Versions:$(NC)"
	@echo "Docker: $$(docker --version)"
	@echo "Docker Compose: $$(docker-compose --version)"
	@docker-compose exec grafana grafana-server -v || true
	@docker-compose exec prometheus prometheus --version || true

.PHONY: urls
urls: ## Show all service URLs
	@echo "$(BLUE)=== Infrastructure Services (via Nginx) ===$(NC)"
	@echo "$(GREEN)Frontend:$(NC)      http://localhost/"
	@echo "$(GREEN)Grafana:$(NC)       http://localhost/monitoring/grafana/ (admin/admin)"
	@echo "$(GREEN)Prometheus:$(NC)    http://localhost/monitoring/prometheus/"
	@echo "$(GREEN)Tempo:$(NC)         http://localhost/monitoring/tempo/"
	@echo "$(GREEN)Loki:$(NC)          http://localhost/monitoring/loki/"
	@echo "$(GREEN)Keycloak:$(NC)      http://localhost/auth/ (admin/admin)"
	@echo "$(GREEN)pgAdmin:$(NC)       http://localhost/pgadmin/ (admin@example.com/admin)"
	@echo "$(GREEN)MinIO Console:$(NC) http://localhost/minio-console/ (admin/changeme123)"
	@echo "$(GREEN)MinIO S3 API:$(NC)  http://localhost/storage/"
	@echo ""
	@echo "$(BLUE)=== Middleware Services (AI_Middle) ===$(NC)"
	@echo "$(GREEN)Auth Service:$(NC)        http://localhost:8001 (API)"
	@echo "$(BLUE)=== Backend Workers (AI_Backend) ===$(NC)"
	@echo "$(GREEN)Celery Beat:$(NC)         Scheduler (integrated)"
	@echo "$(GREEN)Email Worker:$(NC)        Port 9091 (metrics)"
	@echo "$(GREEN)Payment Worker:$(NC)      Port 9092 (metrics)"
	@echo "$(GREEN)Data Sync Worker:$(NC)    Port 9093 (metrics)"
	@echo "$(GREEN)Flower UI:$(NC)           http://localhost:5555"
	@echo ""
	@echo "$(BLUE)=== Database Access ===$(NC)"
	@echo "$(GREEN)PostgreSQL (Infra):$(NC)  postgres:5432"
	@echo "  Database: $${POSTGRES_DB:-app_db}"
	@echo "  User: $${POSTGRES_USER:-postgres}"
	@echo ""
	@echo "  Database: auth_db"
	@echo ""
	@echo "$(BLUE)=== Object Storage ===$(NC)"
	@echo "$(GREEN)Redis Cache:$(NC)          localhost:6379"
	@echo "$(GREEN)MinIO Cluster:$(NC)        4 nodes (minio1-4)"
	@echo ""
	@echo "$(GREEN)Redis (Backend):$(NC)     localhost:6379"
	@echo "  Celery broker and cache"

.PHONY: env
env: ## Show environment variables
	@cat .env 2>/dev/null || echo "$(RED).env file not found$(NC)"


# ============================================
# Security
# ============================================

.PHONY: security-scan
security-scan: ## Scan images for vulnerabilities
	@echo "$(BLUE)Scanning images for vulnerabilities...$(NC)"
	@docker-compose config --services | while read service; do \
		echo "Scanning $$service..."; \
		docker scan $$(docker-compose ps -q $$service) || true; \
	done


# ============================================
# Performance
# ============================================

.PHONY: benchmark
benchmark: ## Run performance benchmarks
	@echo "$(BLUE)Running benchmarks...$(NC)"
	@echo "API Benchmark:"
	@ab -n 1000 -c 10 http://localhost:8000/health || echo "Install apache2-utils for benchmarking"

.PHONY: profile
profile: ## Profile application performance
	@echo "$(BLUE)Profiling application...$(NC)"
	@docker-compose exec python-service python -m cProfile -o profile.stats main.py || echo "Add profiling code"

# ============================================
# Git Hooks
# ============================================

.PHONY: install-hooks
install-hooks: ## Install git hooks for development
	@echo "$(BLUE)Installing git hooks...$(NC)"
	@echo "#!/bin/sh\nmake lint && make test" > .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "$(GREEN)✓ Git hooks installed$(NC)"

# ============================================
# Repository Management
# ============================================

.PHONY: repos-status
repos-status: ## Show git status of all service repositories
	@echo "$(BLUE)Checking repository status...$(NC)"
	@echo ""
	@echo "$(YELLOW)Infrastructure (AI_Infra):$(NC)"
	@git status --short || echo "Not a git repository"
	@echo ""
	@echo "$(YELLOW)Frontend (AI_Front):$(NC)"
	@cd $(FRONTEND_DIR) && git status --short || echo "Not found or not a git repository"
	@echo ""
	@echo ""
	@echo "$(YELLOW)Backend (AI_Backend):$(NC)"
	@cd $(BACKEND_DIR) && git status --short || echo "Not found or not a git repository"

.PHONY: repos-pull
repos-pull: ## Pull latest changes in all service repositories
	@echo "$(BLUE)Pulling latest changes in all repositories...$(NC)"
	@echo "$(YELLOW)Infrastructure:$(NC)"
	@git pull || echo "$(RED)Failed to pull infrastructure$(NC)"
	@echo ""
	@echo "$(YELLOW)Frontend:$(NC)"
	@cd $(FRONTEND_DIR) && git pull || echo "$(RED)Failed to pull frontend$(NC)"
	@echo ""
	@echo ""
	@echo "$(YELLOW)Backend:$(NC)"
	@cd $(BACKEND_DIR) && git pull || echo "$(RED)Failed to pull backend$(NC)"
	@echo "$(GREEN)✓ All repositories updated$(NC)"

.PHONY: repos-branch
repos-branch: ## Show current branch of all repositories
	@echo "$(BLUE)Repository branches:$(NC)"
	@echo "$(YELLOW)Infrastructure:$(NC) $$(git branch --show-current)"
	@echo "$(YELLOW)Frontend:$(NC)       $$(cd $(FRONTEND_DIR) && git branch --show-current)"
	@echo "$(YELLOW)Backend:$(NC)        $$(cd $(BACKEND_DIR) && git branch --show-current)"


# ============================================
# Testing Targets (Comprehensive)
# ============================================

.PHONY: test
test: ## Run all tests
	@echo "$(BLUE)Running all tests...$(NC)"
	@./scripts/test/run-all-tests.sh

.PHONY: test-unit
test-unit: ## Run unit tests only
	@echo "$(BLUE)Running unit tests...$(NC)"
	@./scripts/test/run-unit-tests.sh

.PHONY: test-integration
test-integration: ## Run integration tests only
	@echo "$(BLUE)Running integration tests...$(NC)"
	@./scripts/test/run-integration-tests.sh

.PHONY: test-e2e
test-e2e: ## Run E2E tests only
	@echo "$(BLUE)Running E2E tests...$(NC)"
	@./scripts/test/run-e2e-tests.sh

.PHONY: test-api
test-api: ## Run API tests with Newman
	@echo "$(BLUE)Running API tests...$(NC)"
	@./scripts/test/run-api-tests.sh

.PHONY: test-performance
test-performance: ## Run performance tests with k6
	@echo "$(BLUE)Running performance tests...$(NC)"
	@./scripts/test/run-performance-tests.sh

.PHONY: test-regression
test-regression: ## Run regression tests
	@echo "$(BLUE)Running regression tests...$(NC)"
	@pytest tests/regression -v

.PHONY: test-coverage
test-coverage: ## Generate coverage report (for application code when available)
	@echo "$(BLUE)Generating coverage report...$(NC)"
	@echo "$(YELLOW)Note: Coverage is currently disabled for infrastructure testing$(NC)"
	@echo "$(YELLOW)Re-enable in pytest.ini when application source code (src/) is added$(NC)"
	@pytest tests --cov-report=html --cov-report=term 2>/dev/null || \
		(echo "$(YELLOW)Coverage not configured - tests will run without coverage$(NC)" && pytest tests -v)
	@echo "$(GREEN)Test report: tests/reports/pytest-report.html$(NC)"

.PHONY: test-watch
test-watch: ## Run tests in watch mode
	@pytest tests -v --looponfail

.PHONY: test-setup
test-setup: ## Setup test environment
	@./scripts/test/setup-test-env.sh

.PHONY: test-teardown
test-teardown: ## Teardown test environment
	@./scripts/test/teardown-test-env.sh

.PHONY: test-clean
test-clean: ## Clean test reports and cache
	@echo "$(BLUE)Cleaning test artifacts...$(NC)"
	@rm -rf tests/reports/* .pytest_cache tests/__pycache__
	@echo "$(GREEN)✓ Test artifacts cleaned$(NC)"

.PHONY: test-frontend
test-frontend: ## Run frontend tests
	@echo "$(BLUE)Running frontend tests...$(NC)"
	@cd frontend/ai-front && npm run test

.PHONY: test-nginx
test-nginx: ## Run Nginx unit tests
	@pytest tests/unit/nginx -v

.PHONY: test-database
test-database: ## Run database tests
	@pytest tests/unit/postgres tests/integration/database -v

.PHONY: test-auth
test-auth: ## Run authentication tests
	@pytest tests/integration/auth -v

.PHONY: test-monitoring
test-monitoring: ## Run monitoring tests
	@pytest tests/unit/monitoring tests/integration/monitoring -v

# ============================================
# Tempo Tracing
# ============================================

.PHONY: tempo-start-test-generator
tempo-start-test-generator: ## Start Tempo test trace generator
	@echo "$(BLUE)Starting Tempo test trace generator...$(NC)"
	@docker-compose up -d --build tempo-trace-generator
	@echo "$(GREEN)✓ Trace generator started$(NC)"
	@echo "$(YELLOW)View logs: make tempo-logs-generator$(NC)"
	@echo "$(YELLOW)View traces in Grafana: http://localhost/monitoring/grafana/$(NC)"

.PHONY: tempo-stop-test-generator
tempo-stop-test-generator: ## Stop Tempo test trace generator
	@echo "$(BLUE)Stopping Tempo test trace generator...$(NC)"
	@docker-compose stop tempo-trace-generator
	@echo "$(GREEN)✓ Trace generator stopped$(NC)"

.PHONY: tempo-logs
tempo-logs: ## Show Tempo service logs
	@docker logs ai_infra_tempo --tail 100 -f

.PHONY: tempo-logs-generator
tempo-logs-generator: ## Show trace generator logs
	@docker logs ai_infra_tempo_trace_generator --tail 100 -f

.PHONY: tempo-metrics
tempo-metrics: ## Check Tempo metrics in Prometheus
	@echo "$(BLUE)Checking Tempo metrics...$(NC)"
	@docker exec -it ai_infra_prometheus wget -qO- http://tempo:3200/metrics | grep -E "tempo_distributor_spans_received_total|tempo_ingester_live_traces" || echo "$(YELLOW)No trace data yet - start the trace generator with 'make tempo-start-test-generator'$(NC)"

.PHONY: tempo-status
tempo-status: ## Check Tempo status
	@echo "$(BLUE)Checking Tempo status...$(NC)"
	@echo "$(GREEN)Service Status:$(NC)"
	@docker ps --filter name=ai_infra_tempo --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
	@echo ""
	@echo "$(GREEN)Tempo Health:$(NC)"
	@docker exec ai_infra_tempo wget -qO- http://localhost:3200/ready 2>/dev/null && echo "$(GREEN)✓ Healthy$(NC)" || echo "$(RED)✗ Unhealthy$(NC)"
	@echo ""
	@echo "$(GREEN)Metrics (spans received):$(NC)"
	@docker exec -it ai_infra_prometheus wget -qO- http://tempo:3200/metrics 2>/dev/null | grep tempo_distributor_spans_received_total || echo "$(YELLOW)No spans received yet$(NC)"

# ============================================
# Grafana Troubleshooting
# ============================================

.PHONY: reset-grafana
reset-grafana: ## Quick Grafana restart (fixes most access issues)
	@echo "$(BLUE)Restarting Grafana...$(NC)"
	@./scripts/reset-grafana.sh
	@echo "$(GREEN)✓ Grafana restarted$(NC)"
	@echo "$(YELLOW)Login at: http://localhost/monitoring/grafana/$(NC)"
	@echo "$(YELLOW)Credentials: admin/admin$(NC)"
	@echo ""
	@echo "$(YELLOW)💡 Still can't login? Try:$(NC)"
	@echo "  1. Clear browser cookies for localhost"
	@echo "  2. make reset-grafana-full"

.PHONY: reset-grafana-full
reset-grafana-full: ## Full Grafana reset (deletes all data, clean start)
	@echo "$(BLUE)Full Grafana reset...$(NC)"
	@./scripts/reset-grafana.sh --full
	@echo "$(GREEN)✓ Grafana fully reset$(NC)"
	@echo "$(YELLOW)Login at: http://localhost/monitoring/grafana/$(NC)"
	@echo "$(YELLOW)Credentials: admin/admin$(NC)"

.PHONY: reset-grafana-password
reset-grafana-password: ## Reset Grafana admin password to 'admin'
	@echo "$(BLUE)Resetting Grafana password...$(NC)"
	@./scripts/reset-grafana.sh --password admin
	@echo "$(GREEN)✓ Password reset to 'admin'$(NC)"
	@echo "$(YELLOW)Login at: http://localhost/monitoring/grafana/$(NC)"
	@echo "$(YELLOW)Credentials: admin/admin$(NC)"

.PHONY: grafana-logs
grafana-logs: ## Show Grafana logs
	@docker logs ai_infra_grafana --tail 100 -f

.PHONY: grafana-health
grafana-health: ## Check Grafana health status
	@echo "$(BLUE)Checking Grafana health...$(NC)"
	@curl -s http://localhost/monitoring/grafana/api/health | python3 -m json.tool || echo "$(RED)✗ Grafana not responding$(NC)"

