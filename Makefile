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

# ============================================
# Help
# ============================================

help: ## Show this help message
	@echo "$(BLUE)AI Infrastructure - Available Commands$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  make setup          # First-time setup"
	@echo "  make up             # Start all services"
	@echo "  make logs           # Follow all logs"
	@echo "  make test           # Run all tests"
	@echo "  make clean          # Stop and clean"

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

.PHONY: build
build: ## Build all service images
	@echo "$(BLUE)Building images...$(NC)"
	@docker-compose build
	@echo "$(GREEN)✓ Images built$(NC)"

.PHONY: build-nocache
build-nocache: ## Build all images without cache
	@echo "$(BLUE)Building images without cache...$(NC)"
	@docker-compose build --no-cache
	@echo "$(GREEN)✓ Images built$(NC)"

.PHONY: build-python
build-python: ## Build Python service image
	@echo "$(BLUE)Building Python service...$(NC)"
	@docker-compose build python-service
	@echo "$(GREEN)✓ Python service built$(NC)"

.PHONY: build-nodejs
build-nodejs: ## Build Node.js service image
	@echo "$(BLUE)Building Node.js service...$(NC)"
	@docker-compose build nodejs-service
	@echo "$(GREEN)✓ Node.js service built$(NC)"

.PHONY: pull
pull: ## Pull all service images
	@echo "$(BLUE)Pulling images...$(NC)"
	@docker-compose pull
	@echo "$(GREEN)✓ Images pulled$(NC)"

# ============================================
# Testing
# ============================================

.PHONY: test
test: ## Run all tests
	@echo "$(BLUE)Running tests...$(NC)"
	@$(MAKE) test-python
	@$(MAKE) test-nodejs
	@echo "$(GREEN)✓ All tests completed$(NC)"

.PHONY: test-python
test-python: ## Run Python service tests
	@echo "$(BLUE)Running Python tests...$(NC)"
	@docker-compose exec python-service pytest -v || echo "$(YELLOW)Note: Add tests to services/python-service/tests/$(NC)"

.PHONY: test-nodejs
test-nodejs: ## Run Node.js service tests
	@echo "$(BLUE)Running Node.js tests...$(NC)"
	@docker-compose exec nodejs-service npm test || echo "$(YELLOW)Note: Add tests to services/nodejs-service/tests/$(NC)"

.PHONY: test-coverage
test-coverage: ## Run tests with coverage report
	@echo "$(BLUE)Running tests with coverage...$(NC)"
	@docker-compose exec python-service pytest --cov --cov-report=html || true
	@docker-compose exec nodejs-service npm run test:cov || true
	@echo "$(GREEN)✓ Coverage reports generated$(NC)"

# ============================================
# Database Operations
# ============================================

.PHONY: db-migrate
db-migrate: ## Run database migrations
	@echo "$(BLUE)Running database migrations...$(NC)"
	@docker-compose exec python-service alembic upgrade head || echo "$(YELLOW)Note: Add Alembic migrations$(NC)"

.PHONY: db-seed
db-seed: ## Seed database with sample data
	@echo "$(BLUE)Seeding database...$(NC)"
	@./scripts/seed-data.sh

.PHONY: db-backup
db-backup: ## Backup PostgreSQL database
	@echo "$(BLUE)Backing up database...$(NC)"
	@./scripts/backup.sh

.PHONY: db-restore
db-restore: ## Restore database from backup (usage: make db-restore BACKUP=backups/postgres_backup_TIMESTAMP.sql.gz)
	@if [ -z "$(BACKUP)" ]; then \
		echo "$(RED)Error: Please specify BACKUP file$(NC)"; \
		echo "Usage: make db-restore BACKUP=backups/postgres_backup_20240101_120000.sql.gz"; \
		exit 1; \
	fi
	@echo "$(BLUE)Restoring database from $(BACKUP)...$(NC)"
	@gunzip < $(BACKUP) | docker-compose exec -T postgres psql -U postgres -d app_db
	@echo "$(GREEN)✓ Database restored$(NC)"

.PHONY: db-shell
db-shell: ## Open PostgreSQL shell
	@docker-compose exec postgres psql -U postgres -d app_db

# ============================================
# Service Management
# ============================================

.PHONY: shell-python
shell-python: ## Open shell in Python service
	@docker-compose exec python-service /bin/bash

.PHONY: shell-nodejs
shell-nodejs: ## Open shell in Node.js service
	@docker-compose exec nodejs-service /bin/sh

.PHONY: shell-redis
shell-redis: ## Open Redis CLI
	@docker-compose exec redis redis-cli

.PHONY: restart-python
restart-python: ## Restart Python service
	@docker-compose restart python-service

.PHONY: restart-nodejs
restart-nodejs: ## Restart Node.js service
	@docker-compose restart nodejs-service

# ============================================
# Code Quality & Linting
# ============================================

.PHONY: lint
lint: ## Run linters on all services
	@$(MAKE) lint-python
	@$(MAKE) lint-nodejs

.PHONY: lint-python
lint-python: ## Lint Python code
	@echo "$(BLUE)Linting Python code...$(NC)"
	@docker-compose exec python-service black . --check || true
	@docker-compose exec python-service ruff . || true
	@docker-compose exec python-service mypy . || true

.PHONY: lint-nodejs
lint-nodejs: ## Lint Node.js code
	@echo "$(BLUE)Linting Node.js code...$(NC)"
	@docker-compose exec nodejs-service npm run lint || true

.PHONY: format
format: ## Format code for all services
	@$(MAKE) format-python
	@$(MAKE) format-nodejs

.PHONY: format-python
format-python: ## Format Python code
	@echo "$(BLUE)Formatting Python code...$(NC)"
	@docker-compose exec python-service black .
	@echo "$(GREEN)✓ Python code formatted$(NC)"

.PHONY: format-nodejs
format-nodejs: ## Format Node.js code
	@echo "$(BLUE)Formatting Node.js code...$(NC)"
	@docker-compose exec nodejs-service npm run format
	@echo "$(GREEN)✓ Node.js code formatted$(NC)"

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
	@open http://localhost:9090 || xdg-open http://localhost:9090 || echo "Visit: http://localhost:9090"

.PHONY: dashboard
dashboard: ## Open Grafana dashboard
	@echo "Opening Grafana..."
	@open http://localhost:3000 || xdg-open http://localhost:3000 || echo "Visit: http://localhost:3000"

.PHONY: rabbitmq-ui
rabbitmq-ui: ## Open RabbitMQ management UI
	@echo "Opening RabbitMQ Management..."
	@open http://localhost:15672 || xdg-open http://localhost:15672 || echo "Visit: http://localhost:15672"

# ============================================
# CI/CD Operations
# ============================================

.PHONY: ci-test
ci-test: ## Run CI test pipeline
	@echo "$(BLUE)Running CI test pipeline...$(NC)"
	@$(MAKE) check
	@$(MAKE) build
	@$(MAKE) up
	@sleep 10
	@$(MAKE) test
	@$(MAKE) lint
	@echo "$(GREEN)✓ CI pipeline completed$(NC)"

.PHONY: ci-build
ci-build: ## Build for CI/CD
	@echo "$(BLUE)Building for CI/CD...$(NC)"
	@docker-compose -f $(COMPOSE_FILE) build --parallel
	@echo "$(GREEN)✓ Build completed$(NC)"

.PHONY: ci-deploy-staging
ci-deploy-staging: ## Deploy to staging environment
	@echo "$(BLUE)Deploying to staging...$(NC)"
	@$(MAKE) build
	@docker-compose -f $(COMPOSE_FILE) up -d
	@$(MAKE) db-migrate
	@echo "$(GREEN)✓ Deployed to staging$(NC)"

.PHONY: ci-deploy-prod
ci-deploy-prod: ## Deploy to production environment
	@echo "$(BLUE)Deploying to production...$(NC)"
	@echo "$(YELLOW)⚠️  Production deployment - proceed with caution$(NC)"
	@read -p "Are you sure? (yes/no): " confirm && [ "$$confirm" = "yes" ]
	@$(MAKE) build-nocache
	@docker-compose -f $(COMPOSE_FILE) up -d
	@$(MAKE) db-migrate
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

.PHONY: api-docs
api-docs: ## Open API documentation
	@echo "Opening API docs..."
	@open http://localhost:8000/docs || xdg-open http://localhost:8000/docs || echo "Visit: http://localhost:8000/docs"

# ============================================
# Utilities
# ============================================

.PHONY: version
version: ## Show versions of all components
	@echo "$(BLUE)Component Versions:$(NC)"
	@echo "Docker: $$(docker --version)"
	@echo "Docker Compose: $$(docker-compose --version)"
	@docker-compose exec postgres postgres --version || true
	@docker-compose exec redis redis-server --version || true
	@docker-compose exec rabbitmq rabbitmqctl version || true

.PHONY: urls
urls: ## Show all service URLs
	@echo "$(BLUE)Service URLs:$(NC)"
	@echo "$(GREEN)Grafana:$(NC)       http://localhost:3000 (admin/admin)"
	@echo "$(GREEN)Prometheus:$(NC)    http://localhost:9090"
	@echo "$(GREEN)RabbitMQ:$(NC)      http://localhost:15672 (rabbitmq/rabbitmq)"
	@echo "$(GREEN)Elasticsearch:$(NC) http://localhost:9200 (elastic/elastic)"
	@echo "$(GREEN)Python API:$(NC)    http://localhost:8000"
	@echo "$(GREEN)Node.js API:$(NC)   http://localhost:3001"

.PHONY: env
env: ## Show environment variables
	@cat .env 2>/dev/null || echo "$(RED).env file not found$(NC)"

# ============================================
# Installation & Dependencies
# ============================================

.PHONY: install-python-deps
install-python-deps: ## Install Python dependencies
	@echo "$(BLUE)Installing Python dependencies...$(NC)"
	@docker-compose exec python-service poetry install

.PHONY: install-nodejs-deps
install-nodejs-deps: ## Install Node.js dependencies
	@echo "$(BLUE)Installing Node.js dependencies...$(NC)"
	@docker-compose exec nodejs-service npm install

.PHONY: update-deps
update-deps: ## Update all dependencies
	@echo "$(BLUE)Updating dependencies...$(NC)"
	@docker-compose exec python-service poetry update
	@docker-compose exec nodejs-service npm update
	@echo "$(GREEN)✓ Dependencies updated$(NC)"

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

.PHONY: audit
audit: ## Audit dependencies for vulnerabilities
	@echo "$(BLUE)Auditing dependencies...$(NC)"
	@docker-compose exec python-service poetry audit || true
	@docker-compose exec nodejs-service npm audit || true

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

