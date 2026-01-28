#!/bin/bash

# Deploy PMS Platform to Kubernetes with Updated Images
# This script deploys all services to the Kubernetes cluster

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
NAMESPACE="${NAMESPACE:-pms}"
REGION="${REGION:-us-east-1}"
CLUSTER_NAME="${CLUSTER_NAME:-pms-dev}"
ENVIRONMENT="${ENVIRONMENT:-dev}"

echo "========================================"
echo "PMS Platform Cloud Deployment"
echo "========================================"
echo "Namespace: ${NAMESPACE}"
echo "Environment: ${ENVIRONMENT}"
echo "Cluster: ${CLUSTER_NAME}"
echo "Region: ${REGION}"
echo "========================================"
echo ""

# ============================================================================
# STEP 1: VERIFY PREREQUISITES
# ============================================================================

log_step "STEP 1: Verifying prerequisites..."

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl is not installed"
    exit 1
fi
log_info "✓ kubectl installed"

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    log_error "helm is not installed"
    exit 1
fi
log_info "✓ helm installed"

# Check kubectl connection
log_info "Connecting to cluster..."
if ! kubectl cluster-info &> /dev/null; then
    log_warn "Cannot connect to Kubernetes cluster"
    log_info "Attempting to configure kubeconfig..."
    
    if command -v aws &> /dev/null; then
        aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME
        if ! kubectl cluster-info &> /dev/null; then
            log_error "Failed to connect to cluster"
            exit 1
        fi
    else
        log_error "AWS CLI not installed and cannot connect to cluster"
        exit 1
    fi
fi
log_info "✓ Connected to cluster: $(kubectl config current-context)"

# Check namespace
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    log_info "Creating namespace: $NAMESPACE"
    kubectl create namespace $NAMESPACE
fi
log_info "✓ Namespace '$NAMESPACE' ready"

# ============================================================================
# STEP 2: DEPLOY INFRASTRUCTURE SERVICES
# ============================================================================

log_step "STEP 2: Deploying infrastructure services..."

cd "$(dirname "$0")/../k8s/pms-platform" || exit 1

# Update Helm dependencies
log_info "Updating Helm dependencies..."
helm dependency update

# ============================================================================
# STEP 3: DEPLOY PLATFORM WITH UMBRELLA CHART
# ============================================================================

log_step "STEP 3: Deploying PMS platform..."

helm upgrade --install pms-platform . \
    --namespace $NAMESPACE \
    --create-namespace \
    --set global.environment=$ENVIRONMENT \
    --set global.namespace=$NAMESPACE \
    --set global.imagePullPolicy=Always \
    --set postgres.enabled=true \
    --set rabbitmq.enabled=true \
    --set redis.enabled=true \
    --set kafka.enabled=true \
    --set schemaRegistry.enabled=true \
    --set apigateway.enabled=true \
    --set auth.enabled=true \
    --set portfolio.enabled=true \
    --set transactional.enabled=true \
    --set simulation.enabled=true \
    --set tradeCapture.enabled=true \
    --set validation.enabled=true \
    --set analytics.enabled=true \
    --set rttm.enabled=true \
    --set leaderboard.enabled=true \
    --set frontend.enabled=true \
    --set apigateway.deployment.image.tag=latest \
    --set auth.deployment.image.tag=latest \
    --set portfolio.deployment.image.tag=latest \
    --set transactional.deployment.image.tag=latest \
    --set simulation.deployment.image.tag=latest \
    --set tradeCapture.deployment.image.tag=latest \
    --set validation.deployment.image.tag=latest \
    --set analytics.deployment.image.tag=latest \
    --set rttm.deployment.image.tag=latest \
    --set leaderboard.deployment.image.tag=latest \
    --set frontend.deployment.image.tag=latest \
    --timeout 15m \
    --wait

log_info "✓ Platform deployed successfully"

# ============================================================================
# STEP 4: VERIFY DEPLOYMENT
# ============================================================================

log_step "STEP 4: Verifying deployment..."

echo ""
log_info "Checking pod status..."
kubectl get pods -n $NAMESPACE

echo ""
log_info "Checking services..."
kubectl get services -n $NAMESPACE

echo ""
log_info "Checking deployments..."
kubectl get deployments -n $NAMESPACE

# ============================================================================
# STEP 5: DISPLAY NEXT STEPS
# ============================================================================

echo ""
echo "========================================"
echo "DEPLOYMENT COMPLETE"
echo "========================================"
echo ""
log_info "Next steps:"
echo "  1. Monitor pods: kubectl get pods -n $NAMESPACE -w"
echo "  2. View logs: kubectl logs -f <pod-name> -n $NAMESPACE"
echo "  3. Port forward API Gateway: kubectl port-forward svc/pms-apigateway 8080:8080 -n $NAMESPACE"
echo "  4. Check ingress: kubectl get ingress -n $NAMESPACE"
echo ""
log_info "To check deployment status:"
echo "  ./scripts/quick-status.sh"
echo ""
