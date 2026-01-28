#!/bin/bash

# =============================================================================
# PMS Organization - Docker Compose Startup Script
# =============================================================================
# This script starts the entire PMS stack with optimized resource usage
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
echo -e "${BLUE}║         PMS Organization - Docker Compose Startup              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to print section headers
print_header() {
    echo -e "\n${BLUE}▶ $1${NC}"
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print error messages
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Function to print warning messages
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Check if Docker is running
print_header "Checking Docker..."
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi
print_success "Docker is running"

# Check if Docker Compose is available
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null 2>&1; then
    print_error "Docker Compose is not installed. Please install it and try again."
    exit 1
fi
print_success "Docker Compose is available"

# Set Docker Compose command
if docker compose version &> /dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

# Create necessary directories
print_header "Creating directories..."
mkdir -p scripts
mkdir -p logs
print_success "Directories created"

# Create init-databases.sql if it doesn't exist
if [ ! -f "scripts/init-databases.sql" ]; then
    print_header "Creating database initialization script..."
    cat > scripts/init-databases.sql << 'EOF'
-- PMS Database Initialization Script
-- Creates all necessary databases and schemas

-- Main database is created by POSTGRES_DB env var
-- Create additional schemas if needed

CREATE SCHEMA IF NOT EXISTS trades;
CREATE SCHEMA IF NOT EXISTS portfolios;
CREATE SCHEMA IF NOT EXISTS analytics;
CREATE SCHEMA IF NOT EXISTS validation;
CREATE SCHEMA IF NOT EXISTS simulation;

-- Grant permissions
GRANT ALL PRIVILEGES ON SCHEMA trades TO pms;
GRANT ALL PRIVILEGES ON SCHEMA portfolios TO pms;
GRANT ALL PRIVILEGES ON SCHEMA analytics TO pms;
GRANT ALL PRIVILEGES ON SCHEMA validation TO pms;
GRANT ALL PRIVILEGES ON SCHEMA simulation TO pms;

-- Log initialization
SELECT 'PMS Database initialized successfully' AS status;
EOF
    print_success "Database initialization script created"
fi

# Create pgadmin-servers.json if it doesn't exist
if [ ! -f "scripts/pgadmin-servers.json" ]; then
    print_header "Creating PgAdmin configuration..."
    cat > scripts/pgadmin-servers.json << 'EOF'
{
  "Servers": {
    "1": {
      "Name": "PMS PostgreSQL",
      "Group": "PMS",
      "Host": "postgres",
      "Port": 5432,
      "MaintenanceDB": "pmsdb",
      "Username": "pms",
      "Password": "pms",
      "SSLMode": "prefer",
      "SSLCert": "<STORAGE_DIR>/.postgresql/postgresql.crt",
      "SSLKey": "<STORAGE_DIR>/.postgresql/postgresql.key",
      "SSLCompression": 0,
      "Timeout": 10,
      "UseSSHTunnel": 0,
      "TunnelPort": "22",
      "TunnelAuthentication": 0
    }
  }
}
EOF
    print_success "PgAdmin configuration created"
fi

# Parse command line arguments
MODE="${1:-full}"
BUILD_FLAG="${2:-}"

print_header "Startup Configuration"
echo "Mode: $MODE"
echo "Build: ${BUILD_FLAG:-no-build}"

# Function to start infrastructure services
start_infrastructure() {
    print_header "Starting Infrastructure Services (Phase 1)..."
    $DOCKER_COMPOSE up -d \
        postgres \
        redis \
        zookeeper \
        rabbitmq
    
    print_success "Infrastructure services starting..."
    
    print_header "Waiting for infrastructure to be healthy..."
    sleep 10
    
    # Wait for postgres
    echo -n "Waiting for PostgreSQL... "
    timeout=60
    while [ $timeout -gt 0 ]; do
        if docker exec pms-postgres pg_isready -U pms -d pmsdb > /dev/null 2>&1; then
            print_success "PostgreSQL is ready"
            break
        fi
        sleep 2
        timeout=$((timeout-2))
    done
    
    # Wait for Redis
    echo -n "Waiting for Redis... "
    timeout=60
    while [ $timeout -gt 0 ]; do
        if docker exec pms-redis redis-cli ping > /dev/null 2>&1; then
            print_success "Redis is ready"
            break
        fi
        sleep 2
        timeout=$((timeout-2))
    done
}

# Function to start messaging services
start_messaging() {
    print_header "Starting Messaging Services (Phase 2)..."
    $DOCKER_COMPOSE up -d \
        kafka \
        schema-registry
    
    print_success "Messaging services starting..."
    
    print_header "Waiting for messaging services to be healthy..."
    sleep 15
    
    # Wait for Kafka
    echo -n "Waiting for Kafka... "
    timeout=90
    while [ $timeout -gt 0 ]; do
        if docker exec pms-kafka kafka-broker-api-versions --bootstrap-server localhost:9092 > /dev/null 2>&1; then
            print_success "Kafka is ready"
            break
        fi
        sleep 3
        timeout=$((timeout-3))
    done
    
    # Initialize Kafka topics
    print_header "Initializing Kafka Topics..."
    $DOCKER_COMPOSE up kafka-init
    print_success "Kafka topics initialized"
}

# Function to start application services
start_applications() {
    print_header "Starting Application Services (Phase 3)..."
    
    if [ "$BUILD_FLAG" == "--build" ]; then
        print_warning "Building application images (this may take a while)..."
        $DOCKER_COMPOSE build \
            auth \
            apigateway \
            trade-capture \
            validation \
            simulation \
            portfolio \
            transactional \
            analytics \
            crosscutting \
            rttm \
            leaderboard \
            ingestion \
            frontend
        print_success "Application images built"
    fi
    
    # Start core services first
    print_header "Starting Core Services..."
    $DOCKER_COMPOSE up -d \
        auth \
        portfolio \
        transactional
    
    sleep 15
    
    # Start dependent services
    print_header "Starting Business Services..."
    $DOCKER_COMPOSE up -d \
        trade-capture \
        validation \
        simulation \
        analytics \
        crosscutting \
        rttm \
        leaderboard \
        ingestion
    
    sleep 10
    
    # Start API Gateway and Frontend
    print_header "Starting API Gateway and Frontend..."
    $DOCKER_COMPOSE up -d \
        apigateway \
        frontend
    
    print_success "Application services started"
}

# Function to start monitoring tools
start_monitoring() {
    print_header "Starting Monitoring Tools..."
    $DOCKER_COMPOSE up -d \
        kafka-ui \
        pgadmin
    
    print_success "Monitoring tools started"
}

# Main execution based on mode
case "$MODE" in
    infra)
        print_header "Starting Infrastructure Only..."
        start_infrastructure
        start_messaging
        start_monitoring
        ;;
    
    apps)
        print_header "Starting Applications Only (assuming infra is running)..."
        start_applications
        ;;
    
    full)
        print_header "Starting Full Stack..."
        start_infrastructure
        start_messaging
        start_applications
        start_monitoring
        ;;
    
    minimal)
        print_header "Starting Minimal Stack (infra + core apps)..."
        start_infrastructure
        start_messaging
        $DOCKER_COMPOSE up -d auth apigateway
        ;;
    
    *)
        print_error "Invalid mode: $MODE"
        echo "Usage: $0 [infra|apps|full|minimal] [--build]"
        echo ""
        echo "Modes:"
        echo "  infra   - Start infrastructure services only (postgres, redis, kafka, etc.)"
        echo "  apps    - Start application services only (assumes infra is running)"
        echo "  full    - Start everything (default)"
        echo "  minimal - Start minimal stack (infra + auth + apigateway)"
        echo ""
        echo "Options:"
        echo "  --build - Build images before starting"
        exit 1
        ;;
esac

# Display status
echo ""
print_header "Deployment Status"
$DOCKER_COMPOSE ps

# Display access information
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    PMS Stack Started                           ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}🌐 Application Services:${NC}"
echo "   • API Gateway:        http://localhost:8080"
echo "   • Auth Service:       http://localhost:8082"
echo "   • Trade Capture:      http://localhost:8083"
echo "   • Transactional:      http://localhost:8084"
echo "   • Validation:         http://localhost:8085"
echo "   • Analytics:          http://localhost:8086"
echo "   • Crosscutting:       http://localhost:8087"
echo "   • RTTM:               http://localhost:8088"
echo "   • Leaderboard:        http://localhost:8089"
echo "   • Simulation:         http://localhost:8090"
echo "   • Ingestion:          http://localhost:8091"
echo "   • Portfolio:          http://localhost:8095"
echo "   • Frontend:           http://localhost:4200"
echo ""
echo -e "${BLUE}🔧 Infrastructure Services:${NC}"
echo "   • PostgreSQL:         localhost:5432 (user: pms, password: pms, db: pmsdb)"
echo "   • Redis:              localhost:6379 (password: redis)"
echo "   • RabbitMQ UI:        http://localhost:15672 (user: rabbit-user, password: rabbitmq)"
echo "   • Kafka:              localhost:9092"
echo "   • Schema Registry:    http://localhost:8081"
echo ""
echo -e "${BLUE}📊 Management Tools:${NC}"
echo "   • Kafka UI:           http://localhost:9021"
echo "   • PgAdmin:            http://localhost:5050 (user: admin@pms.local, password: admin)"
echo ""
echo -e "${YELLOW}💡 Tips:${NC}"
echo "   • View logs:          docker-compose logs -f [service-name]"
echo "   • Stop all:           ./stop-pms.sh"
echo "   • Restart service:    docker-compose restart [service-name]"
echo "   • Check health:       docker-compose ps"
echo ""
print_success "PMS Stack is running!"
