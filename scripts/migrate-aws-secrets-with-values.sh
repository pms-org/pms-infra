#!/bin/bash

# AWS Secrets Manager Migration Script with Real Values
# This script retrieves existing secrets from AWS and local .env files,
# then updates them to match the canonical env-contract.md structure

set -e
set -u

# Configuration
ENV="dev"
AWS_REGION="${AWS_REGION:-us-east-1}"
BACKUP_DIR="./secrets-backup-$(date +%Y%m%d-%H%M%S)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Create backup directory
mkdir -p "$BACKUP_DIR"
log_info "Created backup directory: $BACKUP_DIR"

# Function to get secret value from AWS
get_aws_secret() {
    local secret_name="$1"
    local result=$(aws secretsmanager get-secret-value \
        --secret-id "$secret_name" \
        --region "$AWS_REGION" \
        --query 'SecretString' \
        --output text 2>/dev/null || echo "")
    echo "$result"
}

# Function to extract JSON value
get_json_value() {
    local json="$1"
    local key="$2"
    echo "$json" | jq -r ".$key // empty"
}

# Function to create or update secret
create_or_update_secret() {
    local secret_name="$1"
    local secret_value="$2"
    
    log_info "Processing: $secret_name"
    
    # Backup if exists
    local existing=$(get_aws_secret "$secret_name")
    if [ -n "$existing" ]; then
        echo "$existing" > "$BACKUP_DIR/${secret_name//\//_}.json"
        log_info "  ✓ Backed up existing secret"
        
        # Update
        aws secretsmanager put-secret-value \
            --secret-id "$secret_name" \
            --secret-string "$secret_value" \
            --region "$AWS_REGION" > /dev/null
        log_info "  ✓ Updated secret"
    else
        # Create new
        aws secretsmanager create-secret \
            --name "$secret_name" \
            --secret-string "$secret_value" \
            --region "$AWS_REGION" > /dev/null
        log_info "  ✓ Created new secret"
    fi
}

echo "========================================"
echo "PMS Secrets Migration to Canonical Names"
echo "========================================"
echo ""

# ============================================================================
# STEP 1: RETRIEVE EXISTING SECRETS FROM AWS
# ============================================================================

log_step "STEP 1: Retrieving existing secrets from AWS Secrets Manager..."

# Infrastructure secrets
db_secret=$(get_aws_secret "pms/${ENV}/database")
kafka_secret=$(get_aws_secret "pms/${ENV}/kafka")
rabbitmq_secret=$(get_aws_secret "pms/${ENV}/rabbitmq")
redis_secret=$(get_aws_secret "pms/${ENV}/redis")
schema_registry_secret=$(get_aws_secret "pms/${ENV}/schema-registry")

# Application secrets
auth_secret=$(get_aws_secret "pms/${ENV}/auth" || echo "")
simulation_secret=$(get_aws_secret "pms/${ENV}/simulation")
trade_capture_secret=$(get_aws_secret "pms/${ENV}/trade-capture")
validation_secret=$(get_aws_secret "pms/${ENV}/validation")

log_info "Retrieved all existing secrets from AWS"

# ============================================================================
# STEP 2: EXTRACT VALUES FROM EXISTING SECRETS
# ============================================================================

log_step "STEP 2: Extracting values from existing secrets..."

# Database values
POSTGRES_PASSWORD=$(get_json_value "$db_secret" "POSTGRES_PASSWORD")
DB_USERNAME="${POSTGRES_PASSWORD:-pms}"  # Default from local .env
DB_PASSWORD="${POSTGRES_PASSWORD:-pms}"

# RabbitMQ values
RABBITMQ_DEFAULT_USER=$(get_json_value "$rabbitmq_secret" "RABBITMQ_DEFAULT_USER")
RABBITMQ_DEFAULT_PASS=$(get_json_value "$rabbitmq_secret" "RABBITMQ_DEFAULT_PASS")
RABBITMQ_USERNAME="${RABBITMQ_DEFAULT_USER:-guest}"
RABBITMQ_PASSWORD="${RABBITMQ_DEFAULT_PASS:-guest}"

# Redis values
REDIS_PASSWORD=$(get_json_value "$redis_secret" "REDIS_PASSWORD")
REDIS_PASSWORD="${REDIS_PASSWORD:-redis}"

# Kafka values
KAFKA_ADMIN_PASSWORD=$(get_json_value "$kafka_secret" "KAFKA_ADMIN_PASSWORD")
KAFKA_USER_PASSWORD=$(get_json_value "$kafka_secret" "KAFKA_USER_PASSWORD")
KAFKA_ADMIN_PASSWORD="${KAFKA_ADMIN_PASSWORD:-kafka}"
KAFKA_USER_PASSWORD="${KAFKA_USER_PASSWORD:-kafka}"

# Schema Registry values
SCHEMA_REGISTRY_API_KEY=$(get_json_value "$schema_registry_secret" "SCHEMA_REGISTRY_API_KEY")
SCHEMA_REGISTRY_API_SECRET=$(get_json_value "$schema_registry_secret" "SCHEMA_REGISTRY_API_SECRET")
SCHEMA_REGISTRY_API_KEY="${SCHEMA_REGISTRY_API_KEY:-registry-key-here}"
SCHEMA_REGISTRY_API_SECRET="${SCHEMA_REGISTRY_API_SECRET:-registry-secret-here}"

# Auth service values
if [ -z "$auth_secret" ]; then
    log_warn "Auth secret doesn't exist, will create with defaults"
    AUTH_JWT_SECRET="auth-jwt-secret-$(openssl rand -hex 32)"
else
    AUTH_JWT_SECRET=$(get_json_value "$auth_secret" "JWT_SECRET")
    if [ -z "$AUTH_JWT_SECRET" ]; then
        AUTH_JWT_SECRET=$(get_json_value "$auth_secret" "AUTH_JWT_SECRET")
    fi
    AUTH_JWT_SECRET="${AUTH_JWT_SECRET:-auth-jwt-secret-$(openssl rand -hex 32)}"
fi

# Simulation service values
SIMULATION_API_KEY=$(get_json_value "$simulation_secret" "SIMULATION_API_KEY")
SIMULATION_JWT_SECRET=$(get_json_value "$simulation_secret" "SIMULATION_JWT_SECRET")
SIMULATION_API_KEY="${SIMULATION_API_KEY:-sim-api-key-123}"
SIMULATION_JWT_SECRET="${SIMULATION_JWT_SECRET:-sim-jwt-secret-456}"

# Trade Capture service values
TRADE_CAPTURE_API_KEY=$(get_json_value "$trade_capture_secret" "TRADE_CAPTURE_API_KEY")
TRADE_CAPTURE_JWT_SECRET=$(get_json_value "$trade_capture_secret" "TRADE_CAPTURE_JWT_SECRET")
TRADE_CAPTURE_API_KEY="${TRADE_CAPTURE_API_KEY:-tc-api-key-123}"
TRADE_CAPTURE_JWT_SECRET="${TRADE_CAPTURE_JWT_SECRET:-tc-jwt-secret-456}"

# Validation service values
VALIDATION_API_KEY=$(get_json_value "$validation_secret" "VALIDATION_API_KEY")
VALIDATION_JWT_SECRET=$(get_json_value "$validation_secret" "VALIDATION_JWT_SECRET")
VALIDATION_API_KEY="${VALIDATION_API_KEY:-val-api-key-123}"
VALIDATION_JWT_SECRET="${VALIDATION_JWT_SECRET:-val-jwt-secret-456}"

log_info "Extracted all values from existing secrets"

# ============================================================================
# STEP 3: CREATE/UPDATE GLOBAL SECRETS WITH CANONICAL NAMES
# ============================================================================

log_step "STEP 3: Creating/updating global secrets with canonical names..."

# Database - Add canonical property names
create_or_update_secret "pms/${ENV}/database" "{
  \"POSTGRES_PASSWORD\": \"$POSTGRES_PASSWORD\",
  \"DB_USERNAME\": \"$DB_USERNAME\",
  \"DB_PASSWORD\": \"$DB_PASSWORD\"
}"

# RabbitMQ - Add canonical property names
create_or_update_secret "pms/${ENV}/rabbitmq" "{
  \"RABBITMQ_DEFAULT_USER\": \"$RABBITMQ_DEFAULT_USER\",
  \"RABBITMQ_DEFAULT_PASS\": \"$RABBITMQ_DEFAULT_PASS\",
  \"RABBITMQ_USERNAME\": \"$RABBITMQ_USERNAME\",
  \"RABBITMQ_PASSWORD\": \"$RABBITMQ_PASSWORD\"
}"

# Redis - No changes needed
create_or_update_secret "pms/${ENV}/redis" "{
  \"REDIS_PASSWORD\": \"$REDIS_PASSWORD\"
}"

# Kafka - No changes needed
create_or_update_secret "pms/${ENV}/kafka" "{
  \"KAFKA_ADMIN_PASSWORD\": \"$KAFKA_ADMIN_PASSWORD\",
  \"KAFKA_USER_PASSWORD\": \"$KAFKA_USER_PASSWORD\"
}"

# Schema Registry - No changes needed
create_or_update_secret "pms/${ENV}/schema-registry" "{
  \"SCHEMA_REGISTRY_API_KEY\": \"$SCHEMA_REGISTRY_API_KEY\",
  \"SCHEMA_REGISTRY_API_SECRET\": \"$SCHEMA_REGISTRY_API_SECRET\"
}"

# ============================================================================
# STEP 4: CREATE/UPDATE SERVICE-SPECIFIC SECRETS (CANONICAL ONLY)
# ============================================================================

log_step "STEP 4: Creating/updating service-specific secrets..."

# Auth - Only AUTH_JWT_SECRET
create_or_update_secret "pms/${ENV}/auth" "{
  \"AUTH_JWT_SECRET\": \"$AUTH_JWT_SECRET\"
}"

# Simulation - Only service-specific secrets (no DB, no RabbitMQ)
create_or_update_secret "pms/${ENV}/simulation" "{
  \"SIMULATION_API_KEY\": \"$SIMULATION_API_KEY\",
  \"SIMULATION_JWT_SECRET\": \"$SIMULATION_JWT_SECRET\"
}"

# Trade Capture - Only service-specific secrets
create_or_update_secret "pms/${ENV}/trade-capture" "{
  \"TRADE_CAPTURE_API_KEY\": \"$TRADE_CAPTURE_API_KEY\",
  \"TRADE_CAPTURE_JWT_SECRET\": \"$TRADE_CAPTURE_JWT_SECRET\"
}"

# Validation - Only service-specific secrets
create_or_update_secret "pms/${ENV}/validation" "{
  \"VALIDATION_API_KEY\": \"$VALIDATION_API_KEY\",
  \"VALIDATION_JWT_SECRET\": \"$VALIDATION_JWT_SECRET\"
}"

# ============================================================================
# STEP 5: VERIFICATION
# ============================================================================

log_step "STEP 5: Verifying all secrets..."

verify_secret() {
    local secret_name="$1"
    local result=$(get_aws_secret "$secret_name")
    if [ -n "$result" ]; then
        log_info "  ✓ $secret_name"
        return 0
    else
        log_error "  ✗ $secret_name MISSING"
        return 1
    fi
}

verify_secret "pms/${ENV}/database"
verify_secret "pms/${ENV}/rabbitmq"
verify_secret "pms/${ENV}/redis"
verify_secret "pms/${ENV}/kafka"
verify_secret "pms/${ENV}/schema-registry"
verify_secret "pms/${ENV}/auth"
verify_secret "pms/${ENV}/simulation"
verify_secret "pms/${ENV}/trade-capture"
verify_secret "pms/${ENV}/validation"

# ============================================================================
# STEP 6: GENERATE UPDATED secrets.env FILE
# ============================================================================

log_step "STEP 6: Generating updated secrets.env file..."

cat > "pms-infra/secrets.env.new" <<EOF
# PMS Infrastructure - AWS Secrets Manager Reference (CANONICAL)
# Generated: $(date +"%B %d, %Y")
# All secrets migrated to canonical env-contract.md structure

# ============================================================================
# GLOBAL SECRETS
# ============================================================================

# Database (pms/dev/database)
pms/dev/database={
  "POSTGRES_PASSWORD": "$POSTGRES_PASSWORD",
  "DB_USERNAME": "$DB_USERNAME",
  "DB_PASSWORD": "$DB_PASSWORD"
}

# RabbitMQ (pms/dev/rabbitmq)
pms/dev/rabbitmq={
  "RABBITMQ_DEFAULT_USER": "$RABBITMQ_DEFAULT_USER",
  "RABBITMQ_DEFAULT_PASS": "$RABBITMQ_DEFAULT_PASS",
  "RABBITMQ_USERNAME": "$RABBITMQ_USERNAME",
  "RABBITMQ_PASSWORD": "$RABBITMQ_PASSWORD"
}

# Redis (pms/dev/redis)
pms/dev/redis={
  "REDIS_PASSWORD": "$REDIS_PASSWORD"
}

# Kafka (pms/dev/kafka)
pms/dev/kafka={
  "KAFKA_ADMIN_PASSWORD": "$KAFKA_ADMIN_PASSWORD",
  "KAFKA_USER_PASSWORD": "$KAFKA_USER_PASSWORD"
}

# Schema Registry (pms/dev/schema-registry)
pms/dev/schema-registry={
  "SCHEMA_REGISTRY_API_KEY": "$SCHEMA_REGISTRY_API_KEY",
  "SCHEMA_REGISTRY_API_SECRET": "$SCHEMA_REGISTRY_API_SECRET"
}

# ============================================================================
# SERVICE-SPECIFIC SECRETS
# ============================================================================

# Auth Service (pms/dev/auth)
pms/dev/auth={
  "AUTH_JWT_SECRET": "$AUTH_JWT_SECRET"
}

# Simulation Service (pms/dev/simulation)
pms/dev/simulation={
  "SIMULATION_API_KEY": "$SIMULATION_API_KEY",
  "SIMULATION_JWT_SECRET": "$SIMULATION_JWT_SECRET"
}

# Trade Capture Service (pms/dev/trade-capture)
pms/dev/trade-capture={
  "TRADE_CAPTURE_API_KEY": "$TRADE_CAPTURE_API_KEY",
  "TRADE_CAPTURE_JWT_SECRET": "$TRADE_CAPTURE_JWT_SECRET"
}

# Validation Service (pms/dev/validation)
pms/dev/validation={
  "VALIDATION_API_KEY": "$VALIDATION_API_KEY",
  "VALIDATION_JWT_SECRET": "$VALIDATION_JWT_SECRET"
}

# ============================================================================
# AWS SECRET ARNs (for reference)
# ============================================================================
pms/dev/database=$(aws secretsmanager describe-secret --secret-id pms/dev/database --region $AWS_REGION --query 'ARN' --output text 2>/dev/null || echo "N/A")
pms/dev/rabbitmq=$(aws secretsmanager describe-secret --secret-id pms/dev/rabbitmq --region $AWS_REGION --query 'ARN' --output text 2>/dev/null || echo "N/A")
pms/dev/redis=$(aws secretsmanager describe-secret --secret-id pms/dev/redis --region $AWS_REGION --query 'ARN' --output text 2>/dev/null || echo "N/A")
pms/dev/kafka=$(aws secretsmanager describe-secret --secret-id pms/dev/kafka --region $AWS_REGION --query 'ARN' --output text 2>/dev/null || echo "N/A")
pms/dev/schema-registry=$(aws secretsmanager describe-secret --secret-id pms/dev/schema-registry --region $AWS_REGION --query 'ARN' --output text 2>/dev/null || echo "N/A")
pms/dev/auth=$(aws secretsmanager describe-secret --secret-id pms/dev/auth --region $AWS_REGION --query 'ARN' --output text 2>/dev/null || echo "N/A")
pms/dev/simulation=$(aws secretsmanager describe-secret --secret-id pms/dev/simulation --region $AWS_REGION --query 'ARN' --output text 2>/dev/null || echo "N/A")
pms/dev/trade-capture=$(aws secretsmanager describe-secret --secret-id pms/dev/trade-capture --region $AWS_REGION --query 'ARN' --output text 2>/dev/null || echo "N/A")
pms/dev/validation=$(aws secretsmanager describe-secret --secret-id pms/dev/validation --region $AWS_REGION --query 'ARN' --output text 2>/dev/null || echo "N/A")
EOF

log_info "Generated new secrets.env file: pms-infra/secrets.env.new"

echo ""
echo "========================================"
echo "✅ Migration Complete!"
echo "========================================"
echo ""
log_info "Summary:"
log_info "  - All existing secrets retrieved from AWS"
log_info "  - Global secrets updated with canonical property names"
log_info "  - Service secrets updated (removed duplicates)"
log_info "  - Backups saved to: $BACKUP_DIR"
log_info "  - New secrets reference: pms-infra/secrets.env.new"
echo ""
log_info "Next steps:"
log_info "  1. Review the new secrets.env.new file"
log_info "  2. Update pms-infra/secrets.env: mv pms-infra/secrets.env.new pms-infra/secrets.env"
log_info "  3. Deploy platform: helm upgrade --install pms-platform ./pms-infra/k8s/pms-platform -n pms"
log_info "  4. Verify ExternalSecrets sync: kubectl get externalsecrets -n pms"
log_info "  5. Deploy services and verify startup"
echo ""
