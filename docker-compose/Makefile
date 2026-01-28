# =============================================================================
# PMS Docker Compose - Makefile
# =============================================================================
# Convenient commands for managing PMS Docker Compose environment
# =============================================================================

.PHONY: help init up down restart logs health build clean purge

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Default target
.DEFAULT_GOAL := help

## help: Show this help message
help:
	@echo "$(BLUE)PMS Docker Compose - Available Commands$(NC)"
	@echo ""
	@echo "$(YELLOW)Setup & Initialization:$(NC)"
	@echo "  make init              - Initialize environment (first time setup)"
	@echo "  make setup             - Run interactive setup wizard"
	@echo ""
	@echo "$(YELLOW)Start/Stop Services:$(NC)"
	@echo "  make up                - Start all services"
	@echo "  make up-infra          - Start infrastructure only"
	@echo "  make up-core           - Start core services"
	@echo "  make up-business       - Start business services"
	@echo "  make up-build          - Build and start all services"
	@echo "  make down              - Stop all services (keep data)"
	@echo "  make down-clean        - Stop all services and remove volumes"
	@echo "  make restart           - Restart all services"
	@echo ""
	@echo "$(YELLOW)Management:$(NC)"
	@echo "  make logs              - Show logs for all services"
	@echo "  make logs-[service]    - Show logs for specific service (e.g., make logs-kafka)"
	@echo "  make health            - Check health of all services"
	@echo "  make ps                - Show running services"
	@echo "  make stats             - Show resource usage"
	@echo ""
	@echo "$(YELLOW)Building:$(NC)"
	@echo "  make build             - Build all service images"
	@echo "  make build-[service]   - Build specific service"
	@echo "  make rebuild           - Rebuild all services without cache"
	@echo ""
	@echo "$(YELLOW)Cleanup:$(NC)"
	@echo "  make clean             - Remove stopped containers and unused images"
	@echo "  make purge             - Complete cleanup (WARNING: removes all data)"
	@echo "  make prune             - Prune Docker system"
	@echo ""
	@echo "$(YELLOW)Database:$(NC)"
	@echo "  make db-shell          - Connect to PostgreSQL"
	@echo "  make db-backup         - Backup database"
	@echo "  make db-restore        - Restore database from backup"
	@echo ""
	@echo "$(YELLOW)Access Tools:$(NC)"
	@echo "  make kafka-ui          - Open Kafka UI in browser"
	@echo "  make pgadmin           - Open PgAdmin in browser"
	@echo "  make api-gateway       - Open API Gateway in browser"
	@echo "  make frontend          - Open Frontend in browser"

## init: Initialize environment for first time
init:
	@echo "$(BLUE)Initializing PMS Docker Compose environment...$(NC)"
	@mkdir -p scripts logs
	@cp .env.example .env 2>/dev/null || true
	@chmod +x scripts/*.sh 2>/dev/null || true
	@echo "$(GREEN)✓ Environment initialized$(NC)"
	@echo "$(YELLOW)Next steps:$(NC)"
	@echo "  1. Review .env file and customize if needed"
	@echo "  2. Run 'make up' or 'make setup' to start services"

## setup: Run interactive setup wizard
setup:
	@chmod +x scripts/quick-start.sh
	@./scripts/quick-start.sh

## up: Start all services
up:
	@echo "$(BLUE)Starting PMS services...$(NC)"
	@docker compose up -d
	@echo "$(GREEN)✓ Services started$(NC)"
	@echo "Run 'make health' to check service health"

## up-infra: Start infrastructure services only
up-infra:
	@echo "$(BLUE)Starting infrastructure services...$(NC)"
	@docker compose --profile infra up -d
	@echo "$(GREEN)✓ Infrastructure started$(NC)"

## up-core: Start core services
up-core:
	@echo "$(BLUE)Starting core services...$(NC)"
	@docker compose --profile infra --profile core up -d
	@echo "$(GREEN)✓ Core services started$(NC)"

## up-business: Start business services
up-business:
	@echo "$(BLUE)Starting business services...$(NC)"
	@docker compose --profile infra --profile core --profile business up -d
	@echo "$(GREEN)✓ Business services started$(NC)"

## up-build: Build and start all services
up-build:
	@echo "$(BLUE)Building and starting PMS services...$(NC)"
	@docker compose up -d --build
	@echo "$(GREEN)✓ Services built and started$(NC)"

## down: Stop all services
down:
	@echo "$(BLUE)Stopping PMS services...$(NC)"
	@docker compose down
	@echo "$(GREEN)✓ Services stopped$(NC)"

## down-clean: Stop services and remove volumes
down-clean:
	@echo "$(RED)WARNING: This will remove all data!$(NC)"
	@read -p "Are you sure? (yes/no): " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		docker compose down -v; \
		echo "$(GREEN)✓ Services stopped and volumes removed$(NC)"; \
	else \
		echo "$(YELLOW)Cancelled$(NC)"; \
	fi

## restart: Restart all services
restart:
	@echo "$(BLUE)Restarting PMS services...$(NC)"
	@docker compose restart
	@echo "$(GREEN)✓ Services restarted$(NC)"

## logs: Show logs for all services
logs:
	@docker compose logs -f

## logs-[service]: Show logs for specific service
logs-%:
	@docker compose logs -f $*

## health: Check health of all services
health:
	@chmod +x scripts/health-check.sh
	@./scripts/health-check.sh

## ps: Show running services
ps:
	@docker compose ps

## stats: Show resource usage
stats:
	@docker stats --no-stream

## build: Build all service images
build:
	@echo "$(BLUE)Building all service images...$(NC)"
	@docker compose build
	@echo "$(GREEN)✓ All images built$(NC)"

## build-[service]: Build specific service
build-%:
	@echo "$(BLUE)Building $* service...$(NC)"
	@docker compose build $*
	@echo "$(GREEN)✓ $* built$(NC)"

## rebuild: Rebuild all services without cache
rebuild:
	@echo "$(BLUE)Rebuilding all services...$(NC)"
	@docker compose build --no-cache
	@echo "$(GREEN)✓ All services rebuilt$(NC)"

## clean: Remove stopped containers and unused images
clean:
	@echo "$(BLUE)Cleaning up...$(NC)"
	@docker compose down --remove-orphans
	@docker system prune -f
	@echo "$(GREEN)✓ Cleanup complete$(NC)"

## purge: Complete cleanup (removes all data)
purge:
	@echo "$(RED)WARNING: This will remove all PMS Docker resources!$(NC)"
	@read -p "Are you sure? (yes/no): " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		docker compose down -v --remove-orphans; \
		docker volume rm pms-postgres-data pms-redis-data pms-kafka-data pms-rabbitmq-data pms-zookeeper-data pms-zookeeper-logs 2>/dev/null || true; \
		docker system prune -af; \
		echo "$(GREEN)✓ Complete purge done$(NC)"; \
	else \
		echo "$(YELLOW)Cancelled$(NC)"; \
	fi

## prune: Prune Docker system
prune:
	@docker system prune -af --volumes

## db-shell: Connect to PostgreSQL
db-shell:
	@docker exec -it pms-postgres psql -U pms -d pmsdb

## db-backup: Backup database
db-backup:
	@mkdir -p backups
	@docker exec pms-postgres pg_dump -U pms pmsdb > backups/pms-backup-$$(date +%Y%m%d-%H%M%S).sql
	@echo "$(GREEN)✓ Database backed up to backups/$(NC)"

## db-restore: Restore database from backup
db-restore:
	@echo "Available backups:"
	@ls -lh backups/*.sql 2>/dev/null || echo "No backups found"
	@read -p "Enter backup file path: " backup; \
	docker exec -i pms-postgres psql -U pms -d pmsdb < $$backup
	@echo "$(GREEN)✓ Database restored$(NC)"

## kafka-ui: Open Kafka UI in browser
kafka-ui:
	@echo "Opening Kafka UI..."
	@command -v xdg-open >/dev/null && xdg-open http://localhost:9021 || \
	 command -v open >/dev/null && open http://localhost:9021 || \
	 echo "Please open http://localhost:9021 in your browser"

## pgadmin: Open PgAdmin in browser
pgadmin:
	@echo "Opening PgAdmin..."
	@command -v xdg-open >/dev/null && xdg-open http://localhost:5050 || \
	 command -v open >/dev/null && open http://localhost:5050 || \
	 echo "Please open http://localhost:5050 in your browser"

## api-gateway: Open API Gateway in browser
api-gateway:
	@echo "Opening API Gateway..."
	@command -v xdg-open >/dev/null && xdg-open http://localhost:8080 || \
	 command -v open >/dev/null && open http://localhost:8080 || \
	 echo "Please open http://localhost:8080 in your browser"

## frontend: Open Frontend in browser
frontend:
	@echo "Opening Frontend..."
	@command -v xdg-open >/dev/null && xdg-open http://localhost:4200 || \
	 command -v open >/dev/null && open http://localhost:4200 || \
	 echo "Please open http://localhost:4200 in your browser"
