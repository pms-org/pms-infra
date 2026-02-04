#!/bin/bash

# Quick Verification Script
# This script verifies that all changes are correctly implemented

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================"
echo "PMS Environment Contract Verification"
echo "========================================"
echo ""

# Function to check if file contains string
check_file_contains() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    
    if grep -q "$pattern" "$file" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $description"
        return 0
    else
        echo -e "${RED}✗${NC} $description"
        return 1
    fi
}

# Function to check if file does NOT contain string
check_file_not_contains() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    
    if ! grep -q "$pattern" "$file" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $description"
        return 0
    else
        echo -e "${RED}✗${NC} $description (found: $pattern)"
        return 1
    fi
}

echo "Checking Application Code Compliance..."
echo "----------------------------------------"

# Auth - should already be compliant
check_file_contains "pms-auth/src/main/resources/application.yaml" 'DB_HOST' "Auth uses DB_HOST"
check_file_contains "pms-auth/src/main/resources/application.yaml" 'DB_USERNAME' "Auth uses DB_USERNAME"
check_file_contains "pms-auth/src/main/resources/application.yaml" 'DB_PASSWORD' "Auth uses DB_PASSWORD"

# API Gateway - should use canonical Redis vars
check_file_contains "pms-apigateway/src/main/resources/application.yaml" 'REDIS_HOST' "API Gateway uses REDIS_HOST"
check_file_contains "pms-apigateway/src/main/resources/application.yaml" 'REDIS_PORT' "API Gateway uses REDIS_PORT"
check_file_not_contains "pms-apigateway/src/main/resources/application.yaml" 'SPRING_REDIS_HOST' "API Gateway removed SPRING_REDIS_HOST"

# Trade Capture - should use canonical names
check_file_contains "pms-trade-capture/src/main/resources/application.yaml" 'DB_USERNAME' "Trade Capture uses DB_USERNAME"
check_file_contains "pms-trade-capture/src/main/resources/application.yaml" 'RABBITMQ_HOST' "Trade Capture uses RABBITMQ_HOST"
check_file_contains "pms-trade-capture/src/main/resources/application.yaml" 'RABBITMQ_USERNAME' "Trade Capture uses RABBITMQ_USERNAME"
check_file_contains "pms-trade-capture/src/main/resources/application.yaml" 'INCOMING_TRADES_TOPIC' "Trade Capture uses INCOMING_TRADES_TOPIC"
check_file_not_contains "pms-trade-capture/src/main/resources/application.yaml" 'DATASOURCE_USER' "Trade Capture removed DATASOURCE_USER"
check_file_not_contains "pms-trade-capture/src/main/resources/application.yaml" 'RABBIT_STREAM_HOST' "Trade Capture removed RABBIT_STREAM_HOST"

# Validation - should use canonical names
check_file_contains "pms-validation/src/main/resources/application.yml" 'DB_HOST' "Validation uses DB_HOST"
check_file_contains "pms-validation/src/main/resources/application.yml" 'VALIDATION_CONSUMER_GROUP' "Validation uses VALIDATION_CONSUMER_GROUP"
check_file_not_contains "pms-validation/src/main/resources/application.yml" 'DB_URL' "Validation removed DB_URL"
check_file_not_contains "pms-validation/src/main/resources/application.yml" 'KAFKA_CONSUMER_GROUP_ID' "Validation removed KAFKA_CONSUMER_GROUP_ID"

echo ""
echo "Checking Helm Chart Compliance..."
echo "----------------------------------------"

# Check that global config exists in platform
check_file_contains "pms-infra/k8s/pms-platform/values.yaml" 'DB_HOST: postgres' "Platform has global DB_HOST"
check_file_contains "pms-infra/k8s/pms-platform/values.yaml" 'REDIS_HOST: redis' "Platform has global REDIS_HOST"
check_file_contains "pms-infra/k8s/pms-platform/values.yaml" 'RABBITMQ_HOST: rabbitmq' "Platform has global RABBITMQ_HOST"

# Check that global externalsecret exists
check_file_contains "pms-infra/k8s/pms-platform/templates/global-externalsecret.yaml" 'name: pms-global-secrets' "Global ExternalSecret exists"
check_file_contains "pms-infra/k8s/pms-platform/templates/global-externalsecret.yaml" 'secretKey: DB_USERNAME' "Global ExternalSecret has DB_USERNAME"
check_file_contains "pms-infra/k8s/pms-platform/templates/global-externalsecret.yaml" 'secretKey: RABBITMQ_PASSWORD' "Global ExternalSecret has RABBITMQ_PASSWORD"

# Check service charts removed duplicates
check_file_not_contains "pms-infra/k8s/charts/services/auth/values.yaml" 'SPRING_DATASOURCE_URL' "Auth removed duplicate DB config"
check_file_not_contains "pms-infra/k8s/charts/services/simulation/values.yaml" 'SPRING_RABBITMQ_HOST' "Simulation removed duplicate RabbitMQ config"
check_file_not_contains "pms-infra/k8s/charts/services/trade-capture/values.yaml" 'SPRING_KAFKA_BOOTSTRAP_SERVERS' "Trade Capture removed duplicate Kafka config"
check_file_not_contains "pms-infra/k8s/charts/services/validation/values.yaml" 'REDIS_HOST: redis' "Validation removed duplicate Redis config"

# Check deployment templates inject global resources
check_file_contains "pms-infra/k8s/charts/services/auth/templates/deployment.yaml" 'name: pms-global-config' "Auth deployment uses global config"
check_file_contains "pms-infra/k8s/charts/services/auth/templates/deployment.yaml" 'name: pms-global-secrets' "Auth deployment uses global secrets"
check_file_contains "pms-infra/k8s/charts/services/simulation/templates/deployment.yaml" 'name: pms-global-config' "Simulation deployment uses global config"
check_file_contains "pms-infra/k8s/charts/services/trade-capture/templates/deployment.yaml" 'name: pms-global-secrets' "Trade Capture deployment uses global secrets"

echo ""
echo "Checking AWS Update Script..."
echo "----------------------------------------"

check_file_contains "pms-infra/scripts/update-aws-secrets.sh" 'create_or_update_secret "pms/\${ENV}/database"' "AWS script updates database secrets"
check_file_contains "pms-infra/scripts/update-aws-secrets.sh" 'create_or_update_secret "pms/\${ENV}/rabbitmq"' "AWS script updates RabbitMQ secrets"
check_file_contains "pms-infra/scripts/update-aws-secrets.sh" 'AUTH_JWT_SECRET' "AWS script uses canonical auth secret name"

echo ""
echo "========================================"
echo "Verification Complete!"
echo "========================================"
echo ""
echo -e "${GREEN}If all checks passed, you're ready to deploy!${NC}"
echo ""
echo "Next steps:"
echo "1. Review and update placeholder secrets in update-aws-secrets.sh"
echo "2. Run: ./pms-infra/scripts/update-aws-secrets.sh"
echo "3. Deploy platform: helm upgrade --install pms-platform ./pms-infra/k8s/pms-platform"
echo "4. Deploy services: helm upgrade --install <service> ./pms-infra/k8s/charts/services/<service>"
echo ""
