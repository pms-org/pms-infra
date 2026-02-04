#!/bin/bash
# Kustomize Refactoring Verification Script

echo "====================================="
echo "PMS Kustomize Structure Verification"
echo "====================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0

# Test function
test_command() {
    local description="$1"
    local command="$2"
    local expected="$3"
    
    echo -n "Testing: $description... "
    
    result=$(eval "$command" 2>&1)
    
    if echo "$result" | grep -q "$expected"; then
        echo -e "${GREEN}✓ PASSED${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        echo "  Expected: $expected"
        echo "  Got: $result"
        ((FAILED++))
        return 1
    fi
}

echo "1. Base Layer Tests"
echo "-------------------"

test_command "Base kustomization exists" "test -f k8s/base/kustomization.yaml && echo 'exists'" "exists"
test_command "Simulation deployment refactored" "grep -q 'envFrom:' k8s/base/apps/simulation/deployment.yaml && echo 'refactored'" "refactored"
test_command "Validation deployment refactored" "grep -q 'envFrom:' k8s/base/apps/validation/deployment.yaml && echo 'refactored'" "refactored"
test_command "Postgres deployment refactored" "grep -q 'envFrom:' k8s/base/infra/postgres/deployment.yaml && echo 'refactored'" "refactored"

echo ""
echo "2. Properties and Env Files"
echo "---------------------------"

test_command "Simulation properties created" "test -f k8s/base/apps/simulation/simulation.properties && echo 'exists'" "exists"
test_command "Simulation env created" "test -f k8s/base/apps/simulation/simulation.env && echo 'exists'" "exists"
test_command "Validation properties created" "test -f k8s/base/apps/validation/validation.properties && echo 'exists'" "exists"
test_command "Validation env created" "test -f k8s/base/apps/validation/validation.env && echo 'exists'" "exists"
test_command "Postgres env created" "test -f k8s/base/infra/postgres/postgres.env && echo 'exists'" "exists"
test_command "RabbitMQ env created" "test -f k8s/base/infra/rabbitmq/rabbitmq.env && echo 'exists'" "exists"
test_command "Schema Registry properties created" "test -f k8s/base/infra/schema-registry/schema-registry.properties && echo 'exists'" "exists"

echo ""
echo "3. Dev Overlay Tests"
echo "--------------------"

test_command "Dev kustomization exists" "test -f k8s/overlays/dev/kustomization.yaml && echo 'exists'" "exists"
test_command "Dev ingress exists" "test -f k8s/overlays/dev/ingress.yaml && echo 'exists'" "exists"
test_command "Dev has configMapGenerator" "grep -q 'configMapGenerator:' k8s/overlays/dev/kustomization.yaml && echo 'has-generator'" "has-generator"
test_command "Dev has secretGenerator" "grep -q 'secretGenerator:' k8s/overlays/dev/kustomization.yaml && echo 'has-generator'" "has-generator"

echo ""
echo "4. Prod Overlay Tests"
echo "---------------------"

test_command "Prod kustomization exists" "test -f k8s/overlays/prod/kustomization.yaml && echo 'exists'" "exists"
test_command "Prod simulation secrets exist" "test -f k8s/overlays/prod/simulation-secrets.env && echo 'exists'" "exists"
test_command "Prod has resource patches" "grep -q 'resources:' k8s/overlays/prod/kustomization.yaml && echo 'has-resources'" "has-resources"
test_command "Prod sets replicas to 5" "grep -q 'value: 5' k8s/overlays/prod/kustomization.yaml && echo 'has-5-replicas'" "has-5-replicas"

echo ""
echo "5. Kustomize Build Tests"
echo "------------------------"

if command -v kubectl &> /dev/null; then
    test_command "Dev overlay builds successfully" "kubectl kustomize k8s/overlays/dev > /dev/null 2>&1 && echo 'builds'" "builds"
    test_command "Prod overlay builds successfully" "kubectl kustomize k8s/overlays/prod > /dev/null 2>&1 && echo 'builds'" "builds"
    
    # Count resources
    DEV_RESOURCES=$(kubectl kustomize k8s/overlays/dev 2>/dev/null | grep -c "^kind:")
    PROD_RESOURCES=$(kubectl kustomize k8s/overlays/prod 2>/dev/null | grep -c "^kind:")
    
    test_command "Dev generates expected resources" "echo $DEV_RESOURCES" "3[0-9]"
    test_command "Prod generates expected resources" "echo $PROD_RESOURCES" "3[0-9]"
    
    # Check for ConfigMaps with hash suffixes
    test_command "Dev generates ConfigMaps with hash" "kubectl kustomize k8s/overlays/dev 2>/dev/null | grep 'simulation-config-' | head -1 | awk '{print \$2}' | grep -q '-' && echo 'has-hash'" "has-hash"
    test_command "Dev generates Secrets with hash" "kubectl kustomize k8s/overlays/dev 2>/dev/null | grep 'simulation-secrets-' | head -1 | awk '{print \$2}' | grep -q '-' && echo 'has-hash'" "has-hash"
    
    # Verify replicas in prod
    PROD_REPLICAS=$(kubectl kustomize k8s/overlays/prod 2>/dev/null | grep -A 3 "name: simulation$" | grep "replicas:" | awk '{print $2}')
    test_command "Prod has 5 replicas for simulation" "echo $PROD_REPLICAS" "5"
    
    # Verify resource limits in prod
    test_command "Prod has resource limits" "kubectl kustomize k8s/overlays/prod 2>/dev/null | grep -A 5 'resources:' | grep -q 'limits:' && echo 'has-limits'" "has-limits"
else
    echo -e "${YELLOW}⚠ kubectl not found - skipping build tests${NC}"
fi

echo ""
echo "6. Documentation Tests"
echo "----------------------"

test_command "Main README exists" "test -f k8s/README.md && echo 'exists'" "exists"
test_command "Migration guide exists" "test -f MIGRATION_GUIDE.md && echo 'exists'" "exists"
test_command "Summary document exists" "test -f KUSTOMIZE_REFACTOR_SUMMARY.md && echo 'exists'" "exists"

echo ""
echo "====================================="
echo "Summary"
echo "====================================="
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed! Your Kustomize structure is production-ready.${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed. Please review the errors above.${NC}"
    exit 1
fi
