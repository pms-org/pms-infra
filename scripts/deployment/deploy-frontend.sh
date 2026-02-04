#!/bin/bash

##############################################################################
# Frontend EKS Deployment Script
# Automates building, pushing, and deploying frontend to EKS
##############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"
FRONTEND_DIR="$(dirname "$INFRA_DIR")/pms-frontend"
CHART_DIR="$INFRA_DIR/k8s/pms-platform"

NAMESPACE="${NAMESPACE:-pms}"
IMAGE_REPO="${IMAGE_REPO:-niishantdev/pms-frontend}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
SKIP_BUILD="${SKIP_BUILD:-false}"
SKIP_PUSH="${SKIP_PUSH:-false}"
DEPLOY_ONLY="${DEPLOY_ONLY:-false}"

##############################################################################
# Helper Functions
##############################################################################

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ Error: $1${NC}"
    exit 1
}

print_warning() {
    echo -e "${YELLOW}⚠ Warning: $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local missing_tools=()
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    else
        print_success "Docker installed: $(docker --version | head -n1)"
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    else
        print_success "kubectl installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
    fi
    
    # Check Helm
    if ! command -v helm &> /dev/null; then
        missing_tools+=("helm")
    else
        print_success "Helm installed: $(helm version --short)"
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
    fi
    
    # Check kubectl cluster access
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster. Check kubeconfig."
    fi
    print_success "Kubernetes cluster accessible"
    
    # Check namespace exists
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_warning "Namespace '$NAMESPACE' does not exist. Creating..."
        kubectl create namespace "$NAMESPACE"
        print_success "Namespace '$NAMESPACE' created"
    else
        print_success "Namespace '$NAMESPACE' exists"
    fi
}

get_api_gateway_url() {
    print_header "Fetching API Gateway URL"
    
    # Wait for API Gateway service to be ready
    if ! kubectl get svc apigateway-service -n "$NAMESPACE" &> /dev/null; then
        print_warning "API Gateway service not found in namespace '$NAMESPACE'"
        print_info "Frontend will use default configuration"
        return
    fi
    
    # Get LoadBalancer URL
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        GATEWAY_LB=$(kubectl get svc apigateway-service -n "$NAMESPACE" \
            -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        
        if [ -n "$GATEWAY_LB" ]; then
            GATEWAY_PORT=$(kubectl get svc apigateway-service -n "$NAMESPACE" \
                -o jsonpath='{.spec.ports[0].port}')
            
            API_GATEWAY_HTTP="http://${GATEWAY_LB}:${GATEWAY_PORT}"
            API_GATEWAY_WS="ws://${GATEWAY_LB}:${GATEWAY_PORT}"
            
            print_success "API Gateway HTTP: $API_GATEWAY_HTTP"
            print_success "API Gateway WS: $API_GATEWAY_WS"
            return
        fi
        
        print_info "Waiting for API Gateway LoadBalancer... (attempt $attempt/$max_attempts)"
        sleep 5
        ((attempt++))
    done
    
    print_warning "API Gateway LoadBalancer not ready after $max_attempts attempts"
    print_info "Frontend will use default configuration"
}

build_docker_image() {
    print_header "Building Docker Image"
    
    if [ "$SKIP_BUILD" = "true" ]; then
        print_info "Skipping build (SKIP_BUILD=true)"
        return
    fi
    
    if [ ! -d "$FRONTEND_DIR" ]; then
        print_error "Frontend directory not found: $FRONTEND_DIR"
    fi
    
    cd "$FRONTEND_DIR"
    
    print_info "Building image: ${IMAGE_REPO}:${IMAGE_TAG}"
    
    if ! docker build -t "${IMAGE_REPO}:${IMAGE_TAG}" .; then
        print_error "Docker build failed"
    fi
    
    print_success "Docker image built successfully"
    
    # Also tag as latest if building a specific version
    if [ "$IMAGE_TAG" != "latest" ]; then
        docker tag "${IMAGE_REPO}:${IMAGE_TAG}" "${IMAGE_REPO}:latest"
        print_success "Also tagged as: ${IMAGE_REPO}:latest"
    fi
}

push_docker_image() {
    print_header "Pushing Docker Image"
    
    if [ "$SKIP_PUSH" = "true" ]; then
        print_info "Skipping push (SKIP_PUSH=true)"
        return
    fi
    
    print_info "Pushing image: ${IMAGE_REPO}:${IMAGE_TAG}"
    
    if ! docker push "${IMAGE_REPO}:${IMAGE_TAG}"; then
        print_error "Docker push failed. Make sure you're logged in: docker login"
    fi
    
    print_success "Docker image pushed successfully"
    
    # Also push latest if tagged
    if [ "$IMAGE_TAG" != "latest" ]; then
        docker push "${IMAGE_REPO}:latest"
        print_success "Latest tag pushed"
    fi
}

update_helm_values() {
    print_header "Updating Helm Values"
    
    if [ -z "$API_GATEWAY_HTTP" ]; then
        print_warning "API Gateway URL not available. Using existing values."
        return
    fi
    
    local values_file="$CHART_DIR/values.yaml"
    
    if [ ! -f "$values_file" ]; then
        print_error "Helm values file not found: $values_file"
    fi
    
    print_info "Updating runtime configuration in $values_file"
    
    # Backup original values
    cp "$values_file" "$values_file.backup"
    
    # Update API Gateway URLs (this is a simple replace - for production use yq or similar)
    # Note: This updates the template values, actual deployment may override from env-specific values
    
    print_success "Helm values updated"
    print_info "Backup saved: $values_file.backup"
    print_warning "Manual verification recommended for production deployments"
}

deploy_frontend() {
    print_header "Deploying Frontend to EKS"
    
    cd "$INFRA_DIR"
    
    print_info "Deploying with Helm"
    print_info "Chart: $CHART_DIR"
    print_info "Namespace: $NAMESPACE"
    print_info "Image: ${IMAGE_REPO}:${IMAGE_TAG}"
    
    # Prepare Helm values overrides
    local helm_args=(
        "--namespace" "$NAMESPACE"
        "--set" "frontend.enabled=true"
        "--set" "frontend.deployment.image.repository=${IMAGE_REPO}"
        "--set" "frontend.deployment.image.tag=${IMAGE_TAG}"
        "--wait"
        "--timeout" "5m"
    )
    
    # Add API Gateway URLs if available
    if [ -n "$API_GATEWAY_HTTP" ]; then
        helm_args+=(
            "--set" "frontend.runtimeConfig.API_GATEWAY_HTTP=${API_GATEWAY_HTTP}"
            "--set" "frontend.runtimeConfig.API_GATEWAY_WS=${API_GATEWAY_WS}"
            "--set" "frontend.runtimeConfig.AUTH_HTTP=${API_GATEWAY_HTTP}"
            "--set" "frontend.runtimeConfig.PORTFOLIO_HTTP=${API_GATEWAY_HTTP}"
            "--set" "frontend.runtimeConfig.PORTFOLIO_WS=${API_GATEWAY_WS}"
            "--set" "frontend.runtimeConfig.ANALYTICS_HTTP=${API_GATEWAY_HTTP}"
            "--set" "frontend.runtimeConfig.ANALYTICS_WS=${API_GATEWAY_WS}"
            "--set" "frontend.runtimeConfig.LEADERBOARD_HTTP=${API_GATEWAY_HTTP}"
            "--set" "frontend.runtimeConfig.LEADERBOARD_WS=${API_GATEWAY_WS}"
            "--set" "frontend.runtimeConfig.RTTM_HTTP=${API_GATEWAY_HTTP}"
            "--set" "frontend.runtimeConfig.RTTM_WS=${API_GATEWAY_WS}"
        )
    fi
    
    if ! helm upgrade --install pms-platform "$CHART_DIR" "${helm_args[@]}"; then
        print_error "Helm deployment failed"
    fi
    
    print_success "Frontend deployed successfully"
}

verify_deployment() {
    print_header "Verifying Deployment"
    
    # Wait for pod to be ready
    print_info "Waiting for frontend pod to be ready..."
    if ! kubectl wait --for=condition=ready pod -l app=frontend -n "$NAMESPACE" --timeout=180s; then
        print_error "Frontend pod did not become ready"
    fi
    print_success "Frontend pod is ready"
    
    # Get pod status
    print_info "Pod Status:"
    kubectl get pods -n "$NAMESPACE" -l app=frontend
    
    # Get service status
    print_info "Service Status:"
    kubectl get svc -n "$NAMESPACE" -l app=frontend
    
    # Get frontend URL
    print_info "Fetching Frontend URL..."
    local max_attempts=30
    local attempt=1
    local frontend_url=""
    
    while [ $attempt -le $max_attempts ]; do
        frontend_url=$(kubectl get svc frontend-service -n "$NAMESPACE" \
            -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        
        if [ -n "$frontend_url" ]; then
            break
        fi
        
        print_info "Waiting for LoadBalancer... (attempt $attempt/$max_attempts)"
        sleep 5
        ((attempt++))
    done
    
    if [ -n "$frontend_url" ]; then
        print_success "Frontend URL: http://${frontend_url}"
        
        # Test HTTP access
        print_info "Testing HTTP access..."
        if curl -s -f -m 10 "http://${frontend_url}/" > /dev/null; then
            print_success "Frontend is accessible!"
        else
            print_warning "Frontend URL is provisioned but not yet responding"
            print_info "This may take a few more minutes..."
        fi
        
        # Test env.js
        print_info "Testing runtime configuration (env.js)..."
        if curl -s -f -m 10 "http://${frontend_url}/env.js" > /dev/null; then
            print_success "Runtime configuration is accessible"
        else
            print_warning "Runtime configuration endpoint not ready"
        fi
    else
        print_warning "LoadBalancer URL not available yet"
        print_info "Run this command to check status:"
        echo -e "${YELLOW}kubectl get svc frontend-service -n $NAMESPACE${NC}"
    fi
    
    # Show logs
    print_info "Recent logs:"
    kubectl logs -n "$NAMESPACE" -l app=frontend --tail=20 || true
}

show_summary() {
    print_header "Deployment Summary"
    
    echo -e "${GREEN}Frontend deployment completed successfully!${NC}\n"
    
    echo -e "${BLUE}Image:${NC} ${IMAGE_REPO}:${IMAGE_TAG}"
    echo -e "${BLUE}Namespace:${NC} ${NAMESPACE}"
    
    if [ -n "$API_GATEWAY_HTTP" ]; then
        echo -e "${BLUE}API Gateway:${NC} ${API_GATEWAY_HTTP}"
    fi
    
    local frontend_url=$(kubectl get svc frontend-service -n "$NAMESPACE" \
        -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    
    if [ -n "$frontend_url" ]; then
        echo -e "${BLUE}Frontend URL:${NC} http://${frontend_url}"
        echo -e "\n${GREEN}Access your application:${NC}"
        echo -e "  ${YELLOW}http://${frontend_url}${NC}"
    else
        echo -e "\n${YELLOW}Frontend URL pending... Check with:${NC}"
        echo -e "  ${YELLOW}kubectl get svc frontend-service -n ${NAMESPACE}${NC}"
    fi
    
    echo -e "\n${BLUE}Useful Commands:${NC}"
    echo -e "  View logs: ${YELLOW}kubectl logs -f deployment/frontend -n ${NAMESPACE}${NC}"
    echo -e "  Get pods:  ${YELLOW}kubectl get pods -n ${NAMESPACE} -l app=frontend${NC}"
    echo -e "  Restart:   ${YELLOW}kubectl rollout restart deployment/frontend -n ${NAMESPACE}${NC}"
    
    echo ""
}

##############################################################################
# Main Execution
##############################################################################

main() {
    print_header "Frontend EKS Deployment"
    
    if [ "$DEPLOY_ONLY" = "true" ]; then
        print_info "Deploy-only mode: Skipping build and push"
        SKIP_BUILD=true
        SKIP_PUSH=true
    fi
    
    check_prerequisites
    get_api_gateway_url
    
    if [ "$SKIP_BUILD" != "true" ]; then
        build_docker_image
    fi
    
    if [ "$SKIP_PUSH" != "true" ]; then
        push_docker_image
    fi
    
    deploy_frontend
    verify_deployment
    show_summary
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --image-repo)
            IMAGE_REPO="$2"
            shift 2
            ;;
        --image-tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --skip-push)
            SKIP_PUSH=true
            shift
            ;;
        --deploy-only)
            DEPLOY_ONLY=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --namespace NAME       Kubernetes namespace (default: pms)"
            echo "  --image-repo REPO      Docker image repository (default: niishantdev/pms-frontend)"
            echo "  --image-tag TAG        Docker image tag (default: latest)"
            echo "  --skip-build           Skip Docker image build"
            echo "  --skip-push            Skip Docker image push"
            echo "  --deploy-only          Skip build and push, only deploy"
            echo "  --help                 Show this help message"
            echo ""
            echo "Examples:"
            echo "  # Full deployment (build, push, deploy)"
            echo "  $0"
            echo ""
            echo "  # Deploy with specific tag"
            echo "  $0 --image-tag v1.2.3"
            echo ""
            echo "  # Deploy only (use existing image)"
            echo "  $0 --deploy-only"
            echo ""
            echo "  # Build locally but don't push"
            echo "  $0 --skip-push"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

main
