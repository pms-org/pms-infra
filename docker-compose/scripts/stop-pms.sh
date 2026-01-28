#!/bin/bash

# =============================================================================
# PMS Organization - Docker Compose Stop Script
# =============================================================================
# Gracefully stops all PMS services
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
echo -e "${BLUE}║         PMS Organization - Docker Compose Shutdown             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Set Docker Compose command
if docker compose version &> /dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

# Parse arguments
MODE="${1:-graceful}"

case "$MODE" in
    graceful)
        echo -e "${BLUE}▶ Gracefully stopping all services...${NC}"
        $DOCKER_COMPOSE down
        echo -e "${GREEN}✓ All services stopped${NC}"
        ;;
    
    clean)
        echo -e "${YELLOW}▶ Stopping all services and removing volumes...${NC}"
        read -p "This will delete all data. Are you sure? (yes/no): " confirm
        if [ "$confirm" == "yes" ]; then
            $DOCKER_COMPOSE down -v
            echo -e "${GREEN}✓ All services stopped and volumes removed${NC}"
        else
            echo -e "${RED}✗ Cancelled${NC}"
            exit 1
        fi
        ;;
    
    force)
        echo -e "${RED}▶ Force stopping all services...${NC}"
        $DOCKER_COMPOSE down --remove-orphans
        echo -e "${GREEN}✓ All services force stopped${NC}"
        ;;
    
    *)
        echo -e "${RED}✗ Invalid mode: $MODE${NC}"
        echo "Usage: $0 [graceful|clean|force]"
        echo ""
        echo "Modes:"
        echo "  graceful - Stop all services gracefully (default)"
        echo "  clean    - Stop all services and remove volumes (deletes data)"
        echo "  force    - Force stop and remove orphaned containers"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    PMS Stack Stopped                           ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
