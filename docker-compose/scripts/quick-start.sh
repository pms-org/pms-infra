#!/bin/bash

# =============================================================================
# PMS Organization - Quick Start Script
# =============================================================================
# One-command setup and start for the entire PMS stack
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

clear

echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════════════════╗
║                                                                           ║
║   ████████╗ ███╗   ███╗ ███████╗    ███████╗████████╗ █████╗  ██████╗██╗ ║
║   ██╔═══██║ ████╗ ████║ ██╔════╝    ██╔════╝╚══██╔══╝██╔══██╗██╔════╝██║ ║
║   ██████╔═╝ ██╔████╔██║ ███████╗    ███████╗   ██║   ███████║██║     ██║ ║
║   ██╔═══╝   ██║╚██╔╝██║ ╚════██║    ╚════██║   ██║   ██╔══██║██║     ██║ ║
║   ██║       ██║ ╚═╝ ██║ ███████║    ███████║   ██║   ██║  ██║╚██████╗██║ ║
║   ╚═╝       ╚═╝     ╚═╝ ╚══════╝    ╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝╚═╝ ║
║                                                                           ║
║              Portfolio Management System - Docker Compose                ║
║                         Quick Start Wizard                                ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo -e "${BLUE}This wizard will help you get the PMS stack up and running quickly.${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}STEP 1: Checking Prerequisites${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

prerequisites_ok=true

# Check Docker
echo -n "Checking Docker... "
if docker info > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Found${NC}"
else
    echo -e "${RED}✗ Not found or not running${NC}"
    prerequisites_ok=false
fi

# Check Docker Compose
echo -n "Checking Docker Compose... "
if docker compose version > /dev/null 2>&1 || docker-compose --version > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Found${NC}"
    if docker compose version &> /dev/null 2>&1; then
        DOCKER_COMPOSE="docker compose"
    else
        DOCKER_COMPOSE="docker-compose"
    fi
else
    echo -e "${RED}✗ Not found${NC}"
    prerequisites_ok=false
fi

# Check available memory
echo -n "Checking available memory... "
if command -v free &> /dev/null; then
    available_mem=$(free -g | awk '/^Mem:/{print $7}')
    if [ "$available_mem" -ge 4 ]; then
        echo -e "${GREEN}✓ ${available_mem}GB available${NC}"
    else
        echo -e "${YELLOW}⚠ ${available_mem}GB available (recommend 8GB+)${NC}"
    fi
elif command -v vm_stat &> /dev/null; then
    # macOS
    echo -e "${GREEN}✓ macOS detected${NC}"
else
    echo -e "${YELLOW}⚠ Unable to check${NC}"
fi

# Check disk space
echo -n "Checking disk space... "
available_disk=$(df -h . | awk 'NR==2 {print $4}')
echo -e "${GREEN}✓ ${available_disk} available${NC}"

if [ "$prerequisites_ok" = false ]; then
    echo ""
    echo -e "${RED}✗ Prerequisites check failed!${NC}"
    echo -e "${YELLOW}Please install Docker and Docker Compose before continuing.${NC}"
    exit 1
fi

echo ""
read -p "Press Enter to continue..."

# Select mode
clear
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}STEP 2: Select Deployment Mode${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "1) Full Stack       - All services (recommended for first-time setup)"
echo "2) Infrastructure   - Only databases and message brokers"
echo "3) Minimal         - Infrastructure + Auth + API Gateway"
echo "4) Custom          - Choose specific services"
echo ""
read -p "Select mode (1-4) [1]: " mode_choice
mode_choice=${mode_choice:-1}

case "$mode_choice" in
    1) MODE="full" ;;
    2) MODE="infra" ;;
    3) MODE="minimal" ;;
    4) MODE="custom" ;;
    *) MODE="full" ;;
esac

# Ask about building
echo ""
read -p "Build Docker images before starting? (y/N): " build_choice
if [[ "$build_choice" =~ ^[Yy]$ ]]; then
    BUILD_FLAG="--build"
else
    BUILD_FLAG=""
fi

# Make scripts executable
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}STEP 3: Preparing Scripts${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
chmod +x *.sh
echo -e "${GREEN}✓ Scripts are now executable${NC}"

# Create necessary directories
mkdir -p scripts logs
echo -e "${GREEN}✓ Created necessary directories${NC}"

# Summary
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}STEP 4: Deployment Summary${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Mode:${NC} $MODE"
echo -e "${BLUE}Build:${NC} ${BUILD_FLAG:-No build}"
echo ""

if [ "$MODE" == "full" ]; then
    echo -e "${CYAN}Services to be started:${NC}"
    echo "  • Infrastructure: PostgreSQL, Redis, RabbitMQ, Kafka, Schema Registry"
    echo "  • Applications: All 13 microservices"
    echo "  • Management: Kafka UI, PgAdmin"
    echo "  • Frontend: Angular app"
    echo ""
    echo -e "${YELLOW}⏱  Estimated time:${NC}"
    if [ -n "$BUILD_FLAG" ]; then
        echo "  • First time (with build): 15-20 minutes"
    else
        echo "  • With existing images: 3-5 minutes"
    fi
fi

echo ""
read -p "Ready to start? (Y/n): " start_choice
if [[ "$start_choice" =~ ^[Nn]$ ]]; then
    echo -e "${YELLOW}Cancelled by user${NC}"
    exit 0
fi

# Start deployment
clear
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}STEP 5: Starting Services${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ "$MODE" == "custom" ]; then
    echo -e "${BLUE}Starting custom mode with docker-compose...${NC}"
    $DOCKER_COMPOSE up -d $BUILD_FLAG
else
    ./start-pms.sh "$MODE" "$BUILD_FLAG"
fi

# Wait for services to stabilize
echo ""
echo -e "${BLUE}⏳ Waiting for services to stabilize (30 seconds)...${NC}"
sleep 30

# Run health check
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}STEP 6: Health Check${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

./health-check.sh

# Final summary
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                         🎉 SETUP COMPLETE! 🎉                              ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📚 Quick Reference:${NC}"
echo ""
echo -e "${BLUE}Main Services:${NC}"
echo "  • API Gateway:      http://localhost:8080"
echo "  • Frontend:         http://localhost:4200"
echo "  • RabbitMQ UI:      http://localhost:15672 (rabbit-user/rabbitmq)"
echo "  • Kafka UI:         http://localhost:9021"
echo "  • PgAdmin:          http://localhost:5050 (admin@pms.local/admin)"
echo ""
echo -e "${BLUE}Useful Commands:${NC}"
echo "  • Check health:     ./health-check.sh"
echo "  • View logs:        docker-compose logs -f [service-name]"
echo "  • Stop all:         ./stop-pms.sh"
echo "  • Restart service:  docker-compose restart [service-name]"
echo ""
echo -e "${BLUE}Documentation:${NC}"
echo "  • Full README:      cat DOCKER-COMPOSE-README.md"
echo "  • Service list:     docker-compose ps"
echo ""
echo -e "${YELLOW}💡 Tip: Keep this terminal open to see logs, or minimize it and use another terminal.${NC}"
echo ""
