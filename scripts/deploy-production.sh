#!/bin/bash

# Production Deployment Script for PMS Platform
# This script deploys the entire PMS platform to the EKS cluster
# with production-ready configurations

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
NAMESPACE="pms"
REGION="us-east-1"
CLUSTER_NAME="pms-dev"

echo "========================================"
echo "PMS Platform Production Deployment"
echo "========================================"
echo ""

# ============================================================================
# STEP 1: VERIFY PREREQUISITES
# ============================================================================

log_step "STEP 1: Verifying prerequisites..."

# Check kubectl connection
if ! kubectl cluster-info &> /dev/null; then
    log_error "Cannot connect to Kubernetes cluster"
    log_info "Run: aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME"
    exit 1
fi
log_info "✓ Connected to cluster: $(kubectl config current-context)"

# Check External Secrets Operator
if ! kubectl get clustersecretstore aws-secretsmanager &> /dev/null; then
    log_error "ClusterSecretStore 'aws-secretsmanager' not found"
    log_info "External Secrets Operator must be installed first"
    exit 1
fi
log_info "✓ External Secrets Operator ready"

# Check namespace
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    log_info "Creating namespace: $NAMESPACE"
    kubectl create namespace $NAMESPACE
fi
log_info "✓ Namespace '$NAMESPACE' ready"

# ============================================================================
# STEP 2: UPDATE HELM DEPENDENCIES
# ============================================================================

log_step "STEP 2: Updating Helm dependencies for umbrella chart..."

cd pms-infra/k8s/pms-platform
helm dependency update
cd ../../..

log_info "✓ Helm dependencies updated"

# ============================================================================
# STEP 3: DEPLOY ENTIRE PLATFORM VIA UMBRELLA CHART
# ============================================================================

log_step "STEP 3: Deploying entire platform via umbrella chart..."

helm upgrade --install pms-platform \
    ./pms-infra/k8s/pms-platform \
    --namespace $NAMESPACE \
    --create-namespace \
    --set global.environment=dev \
    --set global.namespace=$NAMESPACE \
    --set postgres.enabled=true \
    --set rabbitmq.enabled=true \
    --set redis.enabled=true \
    --set kafka.enabled=true \
    --set schemaRegistry.enabled=true \
    --set externalSecrets.enabled=false \
    --set apigateway.enabled=true \
    --set auth.enabled=true \
    --set simulation.enabled=true \
    --set tradeCapture.enabled=true \
    --set validation.enabled=true \
    --set apigateway.deployment.image.pullPolicy=Always \
    --set auth.deployment.image.pullPolicy=Always \
    --set simulation.deployment.image.pullPolicy=Always \
    --set tradeCapture.deployment.image.pullPolicy=Always \
    --set validation.deployment.image.pullPolicy=Always \
    --set apigateway.deployment.healthChecks.enabled=false \
    --set auth.deployment.healthChecks.enabled=false \
    --set simulation.deployment.healthChecks.enabled=false \
    --set tradeCapture.deployment.healthChecks.enabled=false \
    --set validation.deployment.healthChecks.enabled=false \
    --wait \
    --timeout 10m

if [ $? -eq 0 ]; then
    log_info "✓ Platform deployed successfully via umbrella chart"
else
    log_error "Platform deployment failed"
    kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | tail -20
    exit 1
fi

# ============================================================================
# STEP 4: VERIFY GLOBAL RESOURCES
# ============================================================================

log_step "STEP 4: Verifying global resources..."

# Wait for global configmap
if kubectl get configmap pms-global-config -n $NAMESPACE &> /dev/null; then
    log_info "✓ Global ConfigMap created"
else
    log_warn "Global ConfigMap not found"
fi

# Wait for global secrets to sync
log_info "Waiting for global ExternalSecret to sync..."
kubectl wait --for=condition=Ready externalsecret/pms-global-secrets \
    -n $NAMESPACE \
    --timeout=120s 2>/dev/null || log_warn "Timeout waiting for global secrets (check manually)"

if kubectl get secret pms-global-secrets -n $NAMESPACE &> /dev/null; then
    log_info "✓ Global secrets synced from AWS"
    
    # Show secret keys
    log_info "  Secret contains:"
    kubectl get secret pms-global-secrets -n $NAMESPACE -o json | \
        jq -r '.data | keys[]' | sed 's/^/    - /' 2>/dev/null || echo "    (jq not installed)"
else
    log_warn "Global secrets not yet created (check ExternalSecret status)"
    kubectl get externalsecret -n $NAMESPACE 2>/dev/null || true
fi

# ============================================================================
# STEP 5: VERIFY ALL DEPLOYMENTS
# ============================================================================

log_step "STEP 5: Verifying all deployments..."

# Infrastructure services
for service in postgres redis rabbitmq kafka schema-registry; do
    if kubectl get deployment $service -n $NAMESPACE &> /dev/null 2>&1 || \
       kubectl get statefulset $service -n $NAMESPACE &> /dev/null 2>&1; then
        log_info "✓ $service deployed"
    else
        log_warn "$service not found"
    fi
done

# Application services
for service in auth apigateway simulation trade-capture validation-service; do
    if kubectl get deployment $service -n $NAMESPACE &> /dev/null 2>&1; then
        log_info "✓ $service deployed"
        
        # Verify ExternalSecret
        if kubectl get externalsecret ${service}-secrets -n $NAMESPACE &> /dev/null 2>&1; then
            log_info "  ✓ ExternalSecret exists"
        fi
    else
        log_warn "$service not found"
    fi
done

# ============================================================================
# STEP 6: DEPLOYMENT VERIFICATION
# ============================================================================

log_step "STEP 6: Verifying deployment..."

echo ""
log_info "Helm Release:"
helm list -n $NAMESPACE

echo ""
log_info "Pod Status:"
kubectl get pods -n $NAMESPACE -o wide

echo ""
log_info "ConfigMaps:"
kubectl get configmap -n $NAMESPACE | grep -E "NAME|pms-global|auth-|simulation-|trade-|validation-|apigateway-"

echo ""
log_info "Secrets:"
kubectl get secret -n $NAMESPACE | grep -E "NAME|pms-global|auth-|simulation-|trade-|validation-|apigateway-"

echo ""
log_info "ExternalSecrets:"
kubectl get externalsecret -n $NAMESPACE

echo ""
log_info "Services:"
kubectl get svc -n $NAMESPACE

# ============================================================================
# STEP 7: HEALTH CHECK
# ============================================================================

log_step "STEP 7: Waiting for pods to be ready..."

log_info "Waiting for all pods to be ready (max 5 minutes)..."
kubectl wait --for=condition=Ready pods --all -n $NAMESPACE --timeout=300s || log_warn "Some pods not ready yet"

# Check for pod failures
FAILED_PODS=$(kubectl get pods -n $NAMESPACE --field-selector=status.phase!=Running,status.phase!=Succeeded 2>/dev/null | grep -v NAME | wc -l)
if [ "$FAILED_PODS" -gt 0 ]; then
    log_warn "There are $FAILED_PODS pod(s) not in Running state"
    log_warn "Check with: kubectl get pods -n $NAMESPACE | grep -v Running"
else
    log_info "✓ All pods are running successfully!"
fi

echo ""
echo "========================================"
echo "✅ DEPLOYMENT COMPLETE!"
echo "========================================"
echo ""

log_info "Deployment Summary:"
echo "  • Namespace: $NAMESPACE"
echo "  • Cluster: pms-dev (us-east-1)"
echo "  • Helm Release: pms-platform (umbrella chart)"
echo ""

log_info "Quick Commands:"
echo ""
echo "  # Watch pods:"
echo "  kubectl get pods -n $NAMESPACE -w"
echo ""
echo "  # Check logs:"
echo "  kubectl logs -n $NAMESPACE -l app=auth --tail=50"
echo "  kubectl logs -n $NAMESPACE -l app=apigateway --tail=50"
echo "  kubectl logs -n $NAMESPACE -l app=simulation --tail=50"
echo "  kubectl logs -n $NAMESPACE -l app=trade-capture --tail=50"
echo "  kubectl logs -n $NAMESPACE -l app=validation --tail=50"
echo ""
echo "  # Port forward to test:"
echo "  kubectl port-forward -n $NAMESPACE svc/apigateway 8080:8080"
echo ""
echo "  # Verify secrets synced:"
echo "  kubectl describe externalsecret pms-global-secrets -n $NAMESPACE"
echo "  kubectl get secret pms-global-secrets -n $NAMESPACE -o yaml"
echo ""
echo ""
echo "  # Check ExternalSecrets sync:"
echo "  kubectl describe externalsecret -n $NAMESPACE"
echo ""

log_info "To check for issues:"
echo "  kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'"
echo ""
