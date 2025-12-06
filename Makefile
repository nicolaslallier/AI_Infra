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

.PHONY: pull
pull: ## Pull all monitoring service images
	@echo "$(BLUE)Pulling images...$(NC)"
	@docker-compose pull
	@echo "$(GREEN)✓ Images pulled$(NC)"

# ============================================
# Testing
# ============================================

.PHONY: test
test: ## Test monitoring stack accessibility
	@echo "$(BLUE)Testing monitoring stack...$(NC)"
	@echo "Testing Nginx health..."
	@curl -s http://localhost/health || echo "$(RED)✗ Nginx unhealthy$(NC)"
	@echo "$(GREEN)✓ Nginx healthy$(NC)"
	@echo "Testing Grafana..."
	@curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost/grafana/api/health
	@echo "Testing Prometheus..."
	@curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost/prometheus/-/healthy
	@echo "$(GREEN)✓ Monitoring stack tests completed$(NC)"

# ============================================
# Monitoring Stack Operations
# ============================================

.PHONY: tempo
tempo: ## Open Tempo UI
	@echo "Opening Tempo..."
	@open http://localhost/tempo/ || xdg-open http://localhost/tempo/ || echo "Visit: http://localhost/tempo/"

.PHONY: loki
loki: ## Open Loki UI
	@echo "Opening Loki..."
	@open http://localhost/loki/ || xdg-open http://localhost/loki/ || echo "Visit: http://localhost/loki/"

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
	@open http://localhost/prometheus/ || xdg-open http://localhost/prometheus/ || echo "Visit: http://localhost/prometheus/"

.PHONY: dashboard
dashboard: ## Open Grafana dashboard
	@echo "Opening Grafana..."
	@open http://localhost/grafana/ || xdg-open http://localhost/grafana/ || echo "Visit: http://localhost/grafana/"

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
	@echo "$(BLUE)Service URLs (via Nginx):$(NC)"
	@echo "$(GREEN)Main Entry:$(NC)    http://localhost/"
	@echo "$(GREEN)Grafana:$(NC)       http://localhost/grafana/ (admin/admin)"
	@echo "$(GREEN)Prometheus:$(NC)    http://localhost/prometheus/"
	@echo "$(GREEN)Tempo:$(NC)         http://localhost/tempo/"
	@echo "$(GREEN)Loki:$(NC)          http://localhost/loki/"
	@echo ""
	@echo "$(BLUE)Direct Access (not through Nginx):$(NC)"
	@echo "$(GREEN)Tempo OTLP:$(NC)    grpc://localhost:4317, http://localhost:4318"
	@echo "$(GREEN)Loki:$(NC)          http://localhost:3100"
	@echo "$(GREEN)Tempo:$(NC)         http://localhost:3200"

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

