#!/bin/bash

# Build and Push Docker Images to niishantdev repository
# This script builds all PMS microservices and pushes them to Docker Hub

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
DOCKER_REPO="niishantdev"
TAG="latest"
WORKSPACE="/mnt/c/Developer/pms-org"

# Service definitions: directory_name:image_name
declare -A SERVICES=(
    ["pms-apigateway"]="pms-apigateway"
    ["pms-auth"]="pms-auth"
    ["pms-portfolio"]="pms-portfolio"
    ["PMS-Transactional"]="pms-transactional"
    ["pms-trade-capture"]="pms-trade-capture"
    ["pms-validation"]="pms-validation"
    ["pms-simulation"]="pms-simulation"
    ["pms-analytics"]="pms-analytics"
    ["pms-rttm"]="pms-rttm"
    ["pms-leaderboard"]="pms-leaderboard"
    ["pms-ingestion"]="pms-ingestion"
    ["pms-crosscutting"]="pms-crosscutting"
    ["pms-frontend"]="pms-frontend"
)

echo "========================================"
echo "PMS Docker Image Build & Push"
echo "========================================"
echo "Repository: ${DOCKER_REPO}"
echo "Tag: ${TAG}"
echo "Total Services: ${#SERVICES[@]}"
echo "========================================"
echo ""

# Check if logged into Docker Hub
log_step "Checking Docker Hub authentication..."
if ! docker info | grep -q "Username"; then
    log_warn "Not logged into Docker Hub"
    log_info "Please login to Docker Hub:"
    docker login
fi
log_info "✓ Docker Hub authentication verified"

# Track success/failure
SUCCESSFUL=()
FAILED=()

# Build and push each service
for service_dir in "${!SERVICES[@]}"; do
    service_name="${SERVICES[$service_dir]}"
    image_name="${DOCKER_REPO}/${service_name}:${TAG}"
    service_path="${WORKSPACE}/${service_dir}"
    
    echo ""
    log_step "Processing: ${service_name}"
    log_info "Directory: ${service_dir}"
    log_info "Image: ${image_name}"
    
    # Check if directory exists
    if [ ! -d "$service_path" ]; then
        log_error "Directory not found: $service_path"
        FAILED+=("$service_name - directory not found")
        continue
    fi
    
    # Check if Dockerfile exists
    dockerfile="${service_path}/Dockerfile"
    if [ ! -f "$dockerfile" ]; then
        # Check for validation service special case
        if [ -f "${service_path}/docker/Dockerfile" ]; then
            dockerfile="${service_path}/docker/Dockerfile"
            log_info "Using alternative Dockerfile: docker/Dockerfile"
        else
            log_error "Dockerfile not found in: $service_path"
            FAILED+=("$service_name - Dockerfile not found")
            continue
        fi
    fi
    
    # Build the image
    log_info "Building image..."
    if docker build -t "$image_name" -f "$dockerfile" "$service_path"; then
        log_info "✓ Build successful"
        
        # Push the image
        log_info "Pushing image to Docker Hub..."
        if docker push "$image_name"; then
            log_info "✓ Push successful"
            SUCCESSFUL+=("$service_name")
        else
            log_error "✗ Push failed"
            FAILED+=("$service_name - push failed")
        fi
    else
        log_error "✗ Build failed"
        FAILED+=("$service_name - build failed")
    fi
done

# Summary
echo ""
echo "========================================"
echo "DEPLOYMENT SUMMARY"
echo "========================================"
echo ""

if [ ${#SUCCESSFUL[@]} -gt 0 ]; then
    log_info "Successfully built and pushed (${#SUCCESSFUL[@]}):"
    for service in "${SUCCESSFUL[@]}"; do
        echo "  ✓ ${service}"
    done
fi

echo ""

if [ ${#FAILED[@]} -gt 0 ]; then
    log_error "Failed (${#FAILED[@]}):"
    for service in "${FAILED[@]}"; do
        echo "  ✗ ${service}"
    done
    echo ""
    exit 1
fi

echo ""
log_info "All images built and pushed successfully!"
log_info "Total: ${#SUCCESSFUL[@]} services"
echo ""
log_step "Next steps:"
echo "  1. Deploy to Kubernetes: ./scripts/deploy-production.sh"
echo "  2. Or use Docker Compose: cd docker-compose && docker-compose up -d"
echo ""
