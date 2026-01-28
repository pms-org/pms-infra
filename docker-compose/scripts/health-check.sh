#!/bin/bash

# =============================================================================
# PMS Organization - Health Check Script
# =============================================================================
# Checks the health of all PMS services
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║            PMS Organization - Health Check                     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Set Docker Compose command
if docker compose version &> /dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

# Function to check service health
check_service() {
    local service=$1
    local url=$2
    local name=$3
    
    if curl -f -s "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $name"
        return 0
    else
        echo -e "${RED}✗${NC} $name"
        return 1
    fi
}

# Function to check container status
check_container() {
    local container=$1
    local name=$2
    
    if docker ps --filter "name=$container" --filter "status=running" | grep -q "$container"; then
        local health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")
        if [ "$health" == "healthy" ]; then
            echo -e "${GREEN}✓${NC} $name (healthy)"
            return 0
        elif [ "$health" == "none" ]; then
            echo -e "${YELLOW}•${NC} $name (running, no health check)"
            return 0
        else
            echo -e "${YELLOW}•${NC} $name ($health)"
            return 1
        fi
    else
        echo -e "${RED}✗${NC} $name (not running)"
        return 1
    fi
}

total=0
healthy=0

echo -e "${BLUE}Infrastructure Services:${NC}"
check_container "pms-postgres" "PostgreSQL" && healthy=$((healthy+1))
total=$((total+1))
check_container "pms-redis" "Redis" && healthy=$((healthy+1))
total=$((total+1))
check_container "pms-rabbitmq" "RabbitMQ" && healthy=$((healthy+1))
total=$((total+1))
check_container "pms-zookeeper" "Zookeeper" && healthy=$((healthy+1))
total=$((total+1))
check_container "pms-kafka" "Kafka" && healthy=$((healthy+1))
total=$((total+1))
check_container "pms-schema-registry" "Schema Registry" && healthy=$((healthy+1))
total=$((total+1))

echo ""
echo -e "${BLUE}Application Services:${NC}"
check_service "http://localhost:8080/actuator/health" "API Gateway" && healthy=$((healthy+1))
total=$((total+1))
check_service "http://localhost:8082/actuator/health" "Auth Service" && healthy=$((healthy+1))
total=$((total+1))
check_service "http://localhost:8083/actuator/health" "Trade Capture" && healthy=$((healthy+1))
total=$((total+1))
check_service "http://localhost:8084/actuator/health" "Transactional" && healthy=$((healthy+1))
total=$((total+1))
check_service "http://localhost:8085/actuator/health" "Validation" && healthy=$((healthy+1))
total=$((total+1))
check_service "http://localhost:8086/actuator/health" "Analytics" && healthy=$((healthy+1))
total=$((total+1))
check_service "http://localhost:8087/actuator/health" "Crosscutting" && healthy=$((healthy+1))
total=$((total+1))
check_service "http://localhost:8088/actuator/health" "RTTM" && healthy=$((healthy+1))
total=$((total+1))
check_service "http://localhost:8089/actuator/health" "Leaderboard" && healthy=$((healthy+1))
total=$((total+1))
check_service "http://localhost:8090/actuator/health" "Simulation" && healthy=$((healthy+1))
total=$((total+1))
check_service "http://localhost:8091/actuator/health" "Ingestion" && healthy=$((healthy+1))
total=$((total+1))
check_service "http://localhost:8095/actuator/health" "Portfolio" && healthy=$((healthy+1))
total=$((total+1))

echo ""
echo -e "${BLUE}Management Tools:${NC}"
check_container "pms-kafka-ui" "Kafka UI" && healthy=$((healthy+1))
total=$((total+1))
check_container "pms-pgadmin" "PgAdmin" && healthy=$((healthy+1))
total=$((total+1))

echo ""
echo -e "${BLUE}Summary:${NC}"
percentage=$((healthy * 100 / total))
if [ $percentage -eq 100 ]; then
    echo -e "${GREEN}✓ All services healthy: $healthy/$total ($percentage%)${NC}"
elif [ $percentage -ge 80 ]; then
    echo -e "${YELLOW}⚠ Most services healthy: $healthy/$total ($percentage%)${NC}"
else
    echo -e "${RED}✗ Many services unhealthy: $healthy/$total ($percentage%)${NC}"
fi

echo ""
echo -e "${BLUE}Container Status:${NC}"
$DOCKER_COMPOSE ps

echo ""
echo -e "${YELLOW}💡 Tips:${NC}"
echo "   • View logs for failing service:  docker-compose logs -f [service-name]"
echo "   • Restart a service:              docker-compose restart [service-name]"
echo "   • Rebuild a service:              docker-compose up -d --build [service-name]"
