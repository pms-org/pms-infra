#!/bin/bash
# Financial-Grade Startup Dependencies - Validation Script
# This script validates the implementation of the parallel wait pattern

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "======================================================================="
echo "PMS Financial Platform - Startup Dependencies Validation"
echo "======================================================================="
echo ""

# Function to print success
success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Function to print error
error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to print warning
warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "k8s/charts/platform/pms-library/Chart.yaml" ]; then
    error "Must run from pms-infra root directory"
    exit 1
fi

echo "Step 1: Validating PMS Library Chart"
echo "---------------------------------------------------------------------"

# Check library chart exists
if [ -f "k8s/charts/platform/pms-library/Chart.yaml" ]; then
    success "pms-library Chart.yaml exists"
else
    error "pms-library Chart.yaml not found"
    exit 1
fi

# Check templates exist
if [ -f "k8s/charts/platform/pms-library/templates/_wait.tpl" ]; then
    success "Wait container template exists"
else
    error "Wait container template not found"
    exit 1
fi

if [ -f "k8s/charts/platform/pms-library/templates/_migration.tpl" ]; then
    success "Migration job template exists"
else
    error "Migration job template not found"
    exit 1
fi

if [ -f "k8s/charts/platform/pms-library/templates/_helpers.tpl" ]; then
    success "Helper templates exist"
else
    error "Helper templates not found"
    exit 1
fi

echo ""
echo "Step 2: Validating Trade Capture Service"
echo "---------------------------------------------------------------------"

cd k8s/charts/services/trade-capture

# Check Chart.yaml has library dependency
if grep -q "pms-library" Chart.yaml; then
    success "Chart.yaml includes pms-library dependency"
else
    error "Chart.yaml missing pms-library dependency"
    exit 1
fi

# Check values.yaml has dependencies list
if grep -q "^dependencies:" values.yaml; then
    success "values.yaml has dependencies configuration"
else
    error "values.yaml missing dependencies configuration"
    exit 1
fi

# Check deployment template uses library helper
if grep -q "pms.waitContainer" templates/deployment.yaml; then
    success "deployment.yaml uses pms.waitContainer helper"
else
    error "deployment.yaml not using pms.waitContainer helper"
    exit 1
fi

# Check migration configuration
if grep -q "^migration:" values.yaml; then
    success "values.yaml has migration configuration"
else
    warning "values.yaml missing migration configuration (optional)"
fi

# Check migration job template
if [ -f "templates/migration-job.yaml" ]; then
    success "migration-job.yaml template exists"
else
    warning "migration-job.yaml template not found (optional)"
fi

echo ""
echo "Step 3: Building Helm Dependencies"
echo "---------------------------------------------------------------------"

# Build dependencies
if helm dependency build > /dev/null 2>&1; then
    success "Helm dependencies built successfully"
else
    error "Failed to build Helm dependencies"
    exit 1
fi

# Check charts directory was created
if [ -d "charts" ]; then
    success "charts/ directory created"
else
    error "charts/ directory not created"
    exit 1
fi

echo ""
echo "Step 4: Template Validation"
echo "---------------------------------------------------------------------"

# Test template rendering
if helm template . --debug > /tmp/trade-capture-template.yaml 2>&1; then
    success "Helm template renders without errors"
else
    error "Helm template rendering failed"
    cat /tmp/trade-capture-template.yaml
    exit 1
fi

# Check for strict-startup-check container in output
if grep -q "strict-startup-check" /tmp/trade-capture-template.yaml; then
    success "Init container 'strict-startup-check' found in rendered template"
else
    error "Init container not found in rendered template"
    exit 1
fi

# Check for dependency checks in output
if grep -q "CHECK] Dependency: postgresql" /tmp/trade-capture-template.yaml; then
    success "PostgreSQL dependency check found"
else
    error "PostgreSQL dependency check not found"
    exit 1
fi

if grep -q "CHECK] Dependency: kafka" /tmp/trade-capture-template.yaml; then
    success "Kafka dependency check found"
else
    error "Kafka dependency check not found"
    exit 1
fi

# Count number of old-style init containers in Deployment (should be 0)
# Note: Migration jobs may have wait-for-database, which is expected
OLD_INIT_IN_DEPLOYMENT=$(grep -A 100 "kind: Deployment" /tmp/trade-capture-template.yaml | grep -c "name: wait-for-" || true)
if [ "$OLD_INIT_IN_DEPLOYMENT" -eq 0 ]; then
    success "No old-style init containers in Deployment"
else
    error "Found $OLD_INIT_IN_DEPLOYMENT old-style init containers in Deployment - cleanup needed"
    exit 1
fi

# Migration job should have wait-for-database (this is expected)
MIGRATION_WAIT=$(grep -c "name: wait-for-database" /tmp/trade-capture-template.yaml || true)
if [ "$MIGRATION_WAIT" -eq 1 ]; then
    success "Migration job has database wait container (expected)"
elif [ "$MIGRATION_WAIT" -eq 0 ]; then
    warning "Migration job missing (may be disabled)"
else
    warning "Multiple migration wait containers found"
fi

echo ""
echo "Step 5: Checking Labels and Standards"
echo "---------------------------------------------------------------------"

# Check for standard labels
if grep -q "app.kubernetes.io/part-of: pms-platform" /tmp/trade-capture-template.yaml; then
    success "Standard labels applied"
else
    error "Standard labels not found"
    exit 1
fi

# Check for health probes
if grep -q "livenessProbe:" /tmp/trade-capture-template.yaml; then
    success "Liveness probe configured"
else
    warning "Liveness probe not configured"
fi

if grep -q "readinessProbe:" /tmp/trade-capture-template.yaml; then
    success "Readiness probe configured"
else
    warning "Readiness probe not configured"
fi

if grep -q "startupProbe:" /tmp/trade-capture-template.yaml; then
    success "Startup probe configured"
else
    warning "Startup probe not configured"
fi

# Check for security context
if grep -q "runAsNonRoot: true" /tmp/trade-capture-template.yaml; then
    success "Security context configured"
else
    warning "Security context not configured"
fi

echo ""
echo "Step 6: Analyzing Init Container Configuration"
echo "---------------------------------------------------------------------"

# Extract and display the init container config
echo "Init Container Configuration:"
echo ""
grep -A 50 "initContainers:" /tmp/trade-capture-template.yaml | head -60 || true

echo ""
echo "Step 7: Summary"
echo "---------------------------------------------------------------------"

# Count dependencies
DEP_COUNT=$(grep -c "CHECK] Dependency:" /tmp/trade-capture-template.yaml || true)
echo "Total dependencies configured: $DEP_COUNT"

# List dependencies
echo "Dependencies:"
grep "CHECK] Dependency:" /tmp/trade-capture-template.yaml | sed 's/.*\[CHECK\] Dependency: /  - /' || true

echo ""
echo "======================================================================="
echo -e "${GREEN}✓ Validation Complete!${NC}"
echo "======================================================================="
echo ""
echo "Next Steps:"
echo "  1. Test in local Kind cluster"
echo "  2. Deploy to dev environment"
echo "  3. Apply to other services (auth, simulation, validation, apigateway)"
echo "  4. Monitor init container logs"
echo "  5. Update team documentation"
echo ""
echo "Testing Commands:"
echo "  # Deploy to Kind"
echo "  helm install trade-capture ."
echo ""
echo "  # Watch init container logs"
echo "  kubectl logs -f <pod-name> -c strict-startup-check"
echo ""
echo "  # Check pod status"
echo "  kubectl get pods -l app.kubernetes.io/name=trade-capture"
echo ""

cd - > /dev/null

exit 0
