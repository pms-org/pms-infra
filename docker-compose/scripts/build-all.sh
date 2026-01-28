#!/bin/bash

# =============================================================================
# PMS Organization - Build All Services Script
# =============================================================================
# Builds Docker images for all services in parallel to save time
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
echo -e "${BLUE}║         PMS Organization - Build All Services                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Set Docker Compose command
if docker compose version &> /dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

# Parse arguments
MODE="${1:-sequential}"
PARALLEL_JOBS="${2:-4}"

echo -e "${BLUE}▶ Build Configuration${NC}"
echo "Mode: $MODE"
echo "Parallel Jobs: $PARALLEL_JOBS"
echo ""

# Services to build
SERVICES=(
    "auth"
    "apigateway"
    "trade-capture"
    "validation"
    "simulation"
    "portfolio"
    "transactional"
    "analytics"
    "crosscutting"
    "rttm"
    "leaderboard"
    "ingestion"
    "frontend"
)

# Function to build a single service
build_service() {
    local service=$1
    echo -e "${BLUE}Building $service...${NC}"
    if $DOCKER_COMPOSE build "$service" 2>&1 | tee "logs/build-$service.log"; then
        echo -e "${GREEN}✓ $service built successfully${NC}"
        return 0
    else
        echo -e "${RED}✗ $service build failed${NC}"
        return 1
    fi
}

# Create logs directory
mkdir -p logs

case "$MODE" in
    sequential)
        echo -e "${BLUE}▶ Building services sequentially...${NC}"
        for service in "${SERVICES[@]}"; do
            build_service "$service"
        done
        ;;
    
    parallel)
        echo -e "${BLUE}▶ Building services in parallel (max $PARALLEL_JOBS jobs)...${NC}"
        echo -e "${YELLOW}⚠ Check logs/ directory for individual build logs${NC}"
        echo ""
        
        # Export function for parallel execution
        export -f build_service
        export DOCKER_COMPOSE
        export BLUE GREEN RED NC
        
        # Use GNU parallel if available, otherwise use xargs
        if command -v parallel &> /dev/null; then
            printf '%s\n' "${SERVICES[@]}" | parallel -j "$PARALLEL_JOBS" build_service
        else
            printf '%s\n' "${SERVICES[@]}" | xargs -P "$PARALLEL_JOBS" -I {} bash -c 'build_service "$@"' _ {}
        fi
        ;;
    
    specific)
        if [ -z "$2" ]; then
            echo -e "${RED}✗ Please specify service name${NC}"
            echo "Usage: $0 specific [service-name]"
            echo "Available services: ${SERVICES[*]}"
            exit 1
        fi
        build_service "$2"
        ;;
    
    *)
        echo -e "${RED}✗ Invalid mode: $MODE${NC}"
        echo "Usage: $0 [sequential|parallel|specific] [args]"
        echo ""
        echo "Modes:"
        echo "  sequential        - Build services one by one (default, slower but safer)"
        echo "  parallel [jobs]   - Build services in parallel (faster, requires more resources)"
        echo "  specific [name]   - Build a specific service"
        echo ""
        echo "Examples:"
        echo "  $0 sequential"
        echo "  $0 parallel 4"
        echo "  $0 specific trade-capture"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    Build Complete                              ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}💡 Next Steps:${NC}"
echo "   • Start services:  ./start-pms.sh"
echo "   • View images:     docker images | grep pms"
