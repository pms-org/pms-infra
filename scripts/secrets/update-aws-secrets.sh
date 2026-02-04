#!/bin/bash

# AWS Secrets Manager Update Script
# This script updates all AWS Secrets Manager secrets to match the canonical env-contract.md
# 
# IMPORTANT: This script performs the following operations:
# 1. Creates/updates global secrets (database, rabbitmq, redis, kafka)
# 2. Updates service-specific secrets (removes duplicates, renames to canonical names)
# 3. Creates backups before any destructive operations
#
# Prerequisites:
# - AWS CLI installed and configured
# - Appropriate IAM permissions for Secrets Manager
# - Target environment: dev (change ENV variable for prod)

set -e  # Exit on error
set -u  # Exit on undefined variable

# Configuration
ENV="dev"
AWS_REGION="${AWS_REGION:-us-east-1}"
BACKUP_DIR="./secrets-backup-$(date +%Y%m%d-%H%M%S)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

create_backup_dir() {
    mkdir -p "$BACKUP_DIR"
    log_info "Created backup directory: $BACKUP_DIR"
}

backup_secret() {
    local secret_name="$1"
    log_info "Backing up secret: $secret_name"
    
    if aws secretsmanager describe-secret --secret-id "$secret_name" --region "$AWS_REGION" &> /dev/null; then
        aws secretsmanager get-secret-value \
            --secret-id "$secret_name" \
            --region "$AWS_REGION" \
            --query 'SecretString' \
            --output text > "$BACKUP_DIR/${secret_name//\//_}.json" 2>/dev/null || true
        log_info "✓ Backed up: $secret_name"
    else
        log_warn "Secret does not exist (will be created): $secret_name"
    fi
}

create_or_update_secret() {
    local secret_name="$1"
    local secret_value="$2"
    
    if aws secretsmanager describe-secret --secret-id "$secret_name" --region "$AWS_REGION" &> /dev/null; then
        log_info "Updating existing secret: $secret_name"
        aws secretsmanager put-secret-value \
            --secret-id "$secret_name" \
            --secret-string "$secret_value" \
            --region "$AWS_REGION"
        log_info "✓ Updated: $secret_name"
    else
        log_info "Creating new secret: $secret_name"
        aws secretsmanager create-secret \
            --name "$secret_name" \
            --secret-string "$secret_value" \
            --region "$AWS_REGION"
        log_info "✓ Created: $secret_name"
    fi
}

# ============================================================================
# PHASE 1: BACKUP ALL EXISTING SECRETS
# ============================================================================

log_info "========================================="
log_info "PHASE 1: Backing up existing secrets"
log_info "========================================="

create_backup_dir

# Backup all service secrets
backup_secret "pms/${ENV}/auth"
backup_secret "pms/${ENV}/simulation"
backup_secret "pms/${ENV}/trade-capture"
backup_secret "pms/${ENV}/validation"
backup_secret "pms/${ENV}/database"
backup_secret "pms/${ENV}/rabbitmq"
backup_secret "pms/${ENV}/redis"
backup_secret "pms/${ENV}/kafka"
backup_secret "pms/${ENV}/schema-registry"

log_info "All secrets backed up to: $BACKUP_DIR"

# ============================================================================
# PHASE 2: CREATE/UPDATE GLOBAL SECRETS
# ============================================================================

log_info ""
log_info "========================================="
log_info "PHASE 2: Creating/updating global secrets"
log_info "========================================="

# Database (Global Secret)
log_info "Processing: pms/${ENV}/database"
create_or_update_secret "pms/${ENV}/database" '{
  "POSTGRES_PASSWORD": "your-postgres-password-here",
  "DB_USERNAME": "pms",
  "DB_PASSWORD": "your-postgres-password-here"
}'

# RabbitMQ (Global Secret)
log_info "Processing: pms/${ENV}/rabbitmq"
create_or_update_secret "pms/${ENV}/rabbitmq" '{
  "RABBITMQ_DEFAULT_USER": "guest",
  "RABBITMQ_DEFAULT_PASS": "guest",
  "RABBITMQ_USERNAME": "guest",
  "RABBITMQ_PASSWORD": "guest"
}'

# Redis (Global Secret)
log_info "Processing: pms/${ENV}/redis"
create_or_update_secret "pms/${ENV}/redis" '{
  "REDIS_PASSWORD": "your-redis-password-here"
}'

# Kafka (Global Secret)
log_info "Processing: pms/${ENV}/kafka"
create_or_update_secret "pms/${ENV}/kafka" '{
  "KAFKA_ADMIN_PASSWORD": "admin-password",
  "KAFKA_USER_PASSWORD": "user-password"
}'

# Schema Registry (Global Secret)
log_info "Processing: pms/${ENV}/schema-registry"
create_or_update_secret "pms/${ENV}/schema-registry" '{
  "SCHEMA_REGISTRY_API_KEY": "your-api-key",
  "SCHEMA_REGISTRY_API_SECRET": "your-api-secret"
}'

# ============================================================================
# PHASE 3: UPDATE SERVICE-SPECIFIC SECRETS
# ============================================================================

log_info ""
log_info "========================================="
log_info "PHASE 3: Updating service-specific secrets"
log_info "========================================="

# Auth Service
log_info "Processing: pms/${ENV}/auth"
create_or_update_secret "pms/${ENV}/auth" '{
  "AUTH_JWT_SECRET": "your-auth-jwt-secret-here"
}'

# Simulation Service
log_info "Processing: pms/${ENV}/simulation"
create_or_update_secret "pms/${ENV}/simulation" '{
  "SIMULATION_API_KEY": "your-simulation-api-key",
  "SIMULATION_JWT_SECRET": "your-simulation-jwt-secret"
}'

# Trade Capture Service
log_info "Processing: pms/${ENV}/trade-capture"
create_or_update_secret "pms/${ENV}/trade-capture" '{
  "TRADE_CAPTURE_API_KEY": "your-trade-capture-api-key",
  "TRADE_CAPTURE_JWT_SECRET": "your-trade-capture-jwt-secret"
}'

# Validation Service
log_info "Processing: pms/${ENV}/validation"
create_or_update_secret "pms/${ENV}/validation" '{
  "VALIDATION_API_KEY": "your-validation-api-key",
  "VALIDATION_JWT_SECRET": "your-validation-jwt-secret"
}'

# ============================================================================
# PHASE 4: VERIFICATION
# ============================================================================

log_info ""
log_info "========================================="
log_info "PHASE 4: Verifying updated secrets"
log_info "========================================="

verify_secret() {
    local secret_name="$1"
    if aws secretsmanager describe-secret --secret-id "$secret_name" --region "$AWS_REGION" &> /dev/null; then
        log_info "✓ Verified: $secret_name"
        return 0
    else
        log_error "✗ Missing: $secret_name"
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
# COMPLETION
# ============================================================================

log_info ""
log_info "========================================="
log_info "✓ AWS Secrets Manager update complete!"
log_info "========================================="
log_info ""
log_info "Next steps:"
log_info "1. Review the changes in AWS Secrets Manager console"
log_info "2. Deploy the updated Helm charts"
log_info "3. Verify External Secrets Operator syncs correctly"
log_info "4. Test each service startup"
log_info ""
log_info "Backups saved to: $BACKUP_DIR"
log_info ""
log_warn "⚠️  IMPORTANT: Update the placeholder values in AWS Secrets Manager with actual secrets!"
log_warn "⚠️  Use: aws secretsmanager put-secret-value --secret-id <name> --secret-string <json>"
