# Phase 2: Canonical Mapping Plan

**Generated:** January 13, 2026  
**Status:** 🗺️ **MIGRATION PLAN - NO CHANGES MADE YET**

This document provides the complete, deterministic migration plan to bring all secrets into compliance with `env-contract.md`. Every secret migration is mapped with exact source/target paths and AWS CLI commands.

---

## 🎯 Migration Strategy

### Principles
1. **Safety First**: Copy before delete, never destructive
2. **Contract is Law**: All changes follow `env-contract.md` exactly
3. **Atomic Changes**: One service at a time
4. **Backwards Compatible**: Support old names during transition
5. **Validation**: Test each change before proceeding

### Migration Order
1. **Update Contract** → Add missing secrets
2. **Global Secrets** → Create shared infrastructure secrets
3. **Service Secrets** → Migrate service-specific secrets
4. **Helm Charts** → Update ExternalSecrets and values
5. **Applications** → Update application.yaml files (minimal changes)

---

## 📋 Contract Updates Required

Before migrating secrets, we must update `env-contract.md` to add missing definitions.

### Add to GLOBAL_SECRET Section

Add `DB_USERNAME` as a new global secret:

```markdown
| Variable | Description | AWS Key Path | Used By | Source |
|----------|-------------|--------------|---------|--------|
| `DB_USERNAME` | PostgreSQL database username | `pms/dev/database:POSTGRES_USER` | auth, simulation, trade-capture, validation | AWS Secrets Manager |
```

**Rationale:**
- All services use same PostgreSQL instance
- All services require username
- Username is sensitive (should be secret, not config)
- Single shared credential simplifies management

### Add SERVICE_SECRET Section

Create new section in `env-contract.md`:

```markdown
## 🔒 SERVICE_SECRET

Service-specific secrets unique to each service.

| Variable | Description | AWS Key Path | Service | Source |
|----------|-------------|--------------|---------|--------|
| `AUTH_DB_USER` | Auth service DB username (if different from global) | `pms/dev/auth:AUTH_DB_USER` | auth | AWS Secrets Manager |
| `AUTH_DB_PASSWORD` | Auth service DB password (if different from global) | `pms/dev/auth:AUTH_DB_PASSWORD` | auth | AWS Secrets Manager |
| `AUTH_JWT_SECRET` | JWT signing secret for auth service | `pms/dev/auth:AUTH_JWT_SECRET` | auth | AWS Secrets Manager |
| `SIMULATION_API_KEY` | External API key for simulation service | `pms/dev/simulation:SIMULATION_API_KEY` | simulation | AWS Secrets Manager |
| `SIMULATION_JWT_SECRET` | JWT signing secret for simulation service | `pms/dev/simulation:SIMULATION_JWT_SECRET` | simulation | AWS Secrets Manager |
| `TRADE_CAPTURE_API_KEY` | External API key for trade-capture service | `pms/dev/trade-capture:TRADE_CAPTURE_API_KEY` | trade-capture | AWS Secrets Manager |
| `TRADE_CAPTURE_JWT_SECRET` | JWT signing secret for trade-capture service | `pms/dev/trade-capture:TRADE_CAPTURE_JWT_SECRET` | trade-capture | AWS Secrets Manager |
| `VALIDATION_API_KEY` | External API key for validation service | `pms/dev/validation:VALIDATION_API_KEY` | validation | AWS Secrets Manager |
| `VALIDATION_JWT_SECRET` | JWT signing secret for validation service | `pms/dev/validation:VALIDATION_JWT_SECRET` | validation | AWS Secrets Manager |
```

**Rationale:**
- JWT secrets must be service-specific for security isolation
- API keys are external integrations, not shared
- Keeps flexibility for future service-specific credentials

---

## 🌐 Global Secrets Migration

### Migration: Database Username

**Action:** Create new global database username secret

**Current State:**
- Does not exist in AWS
- Services have hardcoded fallbacks or service-specific paths

**Target State:**
- AWS Path: `pms/dev/database`
- Property: `POSTGRES_USER`
- Value: `pms` (from service defaults)

**AWS Commands:**

```bash
# Step 1: Get current database secret to preserve existing password
aws secretsmanager get-secret-value \
  --secret-id pms/dev/database \
  --query SecretString \
  --output text > /tmp/db-secret-backup.json

# Step 2: Add POSTGRES_USER to existing secret
aws secretsmanager update-secret \
  --secret-id pms/dev/database \
  --secret-string '{
    "POSTGRES_PASSWORD": "<existing-password>",
    "POSTGRES_USER": "pms"
  }'

# Step 3: Verify
aws secretsmanager get-secret-value \
  --secret-id pms/dev/database \
  --query SecretString \
  --output text | jq .
```

---

### Migration: Database Password (Already Exists)

**Action:** ✅ No change required

**Current State:**
- AWS Path: `pms/dev/database`
- Property: `POSTGRES_PASSWORD`
- Status: ✅ Already compliant with contract

**Target State:**
- Same as current (no changes)

**Note:** Services are duplicating this in their own AWS paths. Those will be deleted after migration.

---

### Migration: RabbitMQ Credentials

**Action:** Rename properties to match contract

**Current State:**
- AWS Path: `pms/dev/rabbitmq` ✅ Correct
- Properties: `RABBITMQ_DEFAULT_USER`, `RABBITMQ_DEFAULT_PASS` ❌ Non-canonical

**Target State:**
- AWS Path: `pms/dev/rabbitmq` (no change)
- Properties: `RABBITMQ_USERNAME`, `RABBITMQ_PASSWORD` (canonical)

**AWS Commands:**

```bash
# Step 1: Backup current secret
aws secretsmanager get-secret-value \
  --secret-id pms/dev/rabbitmq \
  --query SecretString \
  --output text > /tmp/rabbitmq-secret-backup.json

# Step 2: Get current values
RABBITMQ_USER=$(aws secretsmanager get-secret-value \
  --secret-id pms/dev/rabbitmq \
  --query SecretString \
  --output text | jq -r '.RABBITMQ_DEFAULT_USER')

RABBITMQ_PASS=$(aws secretsmanager get-secret-value \
  --secret-id pms/dev/rabbitmq \
  --query SecretString \
  --output text | jq -r '.RABBITMQ_DEFAULT_PASS')

# Step 3: Update with canonical property names (keep old names temporarily)
aws secretsmanager update-secret \
  --secret-id pms/dev/rabbitmq \
  --secret-string "{
    \"RABBITMQ_DEFAULT_USER\": \"$RABBITMQ_USER\",
    \"RABBITMQ_DEFAULT_PASS\": \"$RABBITMQ_PASS\",
    \"RABBITMQ_USERNAME\": \"$RABBITMQ_USER\",
    \"RABBITMQ_PASSWORD\": \"$RABBITMQ_PASS\"
  }"

# Step 4: Verify
aws secretsmanager get-secret-value \
  --secret-id pms/dev/rabbitmq \
  --query SecretString \
  --output text | jq .

# Step 5: After migration complete, remove old properties
# aws secretsmanager update-secret \
#   --secret-id pms/dev/rabbitmq \
#   --secret-string "{
#     \"RABBITMQ_USERNAME\": \"$RABBITMQ_USER\",
#     \"RABBITMQ_PASSWORD\": \"$RABBITMQ_PASS\"
#   }"
```

**Note:** Keeping old property names during transition for backwards compatibility.

---

### Migration: Redis Password

**Action:** ✅ No change required

**Current State:**
- AWS Path: `pms/dev/redis`
- Property: `REDIS_PASSWORD`
- Status: ✅ Already compliant with contract

**Note:** Contract defines this but apigateway and validation charts don't use it yet. Will add in Helm updates.

---

### Migration: Kafka Credentials

**Action:** ✅ No change required

**Current State:**
- AWS Path: `pms/dev/kafka`
- Properties: `KAFKA_ADMIN_PASSWORD`, `KAFKA_USER_PASSWORD`
- Status: ✅ Already compliant with contract

---

### Migration: Schema Registry Credentials

**Action:** ✅ No change required

**Current State:**
- AWS Path: `pms/dev/schema-registry`
- Properties: `SCHEMA_REGISTRY_API_KEY`, `SCHEMA_REGISTRY_API_SECRET`
- Status: ✅ Already compliant with contract

---

## 🔧 Service-Specific Secrets Migration

---

### Service: auth

#### Migration 1: Rename Database Credentials

**Current State:**
- AWS Path: `pms/dev/auth`
- Properties: `DATASOURCE_USER`, `DATASOURCE_PASS`

**Target State:**
- Option A: Delete (use global `DB_USERNAME`, `DB_PASSWORD`)
- Option B: Rename to `AUTH_DB_USER`, `AUTH_DB_PASSWORD` (if auth needs separate DB user)

**Recommendation:** **Option A** - Use global credentials

**AWS Commands:**

```bash
# Step 1: Backup
aws secretsmanager get-secret-value \
  --secret-id pms/dev/auth \
  --query SecretString \
  --output text > /tmp/auth-secret-backup.json

# Step 2: Verify values match global credentials
AUTH_USER=$(aws secretsmanager get-secret-value \
  --secret-id pms/dev/auth \
  --query SecretString \
  --output text | jq -r '.DATASOURCE_USER')

AUTH_PASS=$(aws secretsmanager get-secret-value \
  --secret-id pms/dev/auth \
  --query SecretString \
  --output text | jq -r '.DATASOURCE_PASS')

echo "Auth DB User: $AUTH_USER"
echo "Compare with global DB user"

# Step 3: If they match, remove from auth secret
aws secretsmanager update-secret \
  --secret-id pms/dev/auth \
  --secret-string '{
    "AUTH_JWT_SECRET": "<existing-jwt-secret>"
  }'

# If they DON'T match, rename properties
# aws secretsmanager update-secret \
#   --secret-id pms/dev/auth \
#   --secret-string '{
#     "AUTH_DB_USER": "<user>",
#     "AUTH_DB_PASSWORD": "<pass>",
#     "AUTH_JWT_SECRET": "<jwt>"
#   }'
```

#### Migration 2: Rename JWT Secret

**Current State:**
- Property: `JWT_SECRET`

**Target State:**
- Property: `AUTH_JWT_SECRET`

**AWS Commands:**

```bash
# Step 1: Get current value
JWT_SECRET=$(aws secretsmanager get-secret-value \
  --secret-id pms/dev/auth \
  --query SecretString \
  --output text | jq -r '.JWT_SECRET')

# Step 2: Update with canonical name (keep old temporarily)
aws secretsmanager update-secret \
  --secret-id pms/dev/auth \
  --secret-string "{
    \"JWT_SECRET\": \"$JWT_SECRET\",
    \"AUTH_JWT_SECRET\": \"$JWT_SECRET\"
  }"

# Step 3: After migration, remove old name
# aws secretsmanager update-secret \
#   --secret-id pms/dev/auth \
#   --secret-string "{
#     \"AUTH_JWT_SECRET\": \"$JWT_SECRET\"
#   }"
```

---

### Service: simulation

#### Migration 1: Delete Service-Specific DB Password

**Current State:**
- AWS Path: `pms/dev/simulation`
- Property: `SIMULATION_DB_PASSWORD`

**Target State:**
- Deleted (use global `DB_PASSWORD`)

**AWS Commands:**

```bash
# Step 1: Backup
aws secretsmanager get-secret-value \
  --secret-id pms/dev/simulation \
  --query SecretString \
  --output text > /tmp/simulation-secret-backup.json

# Step 2: Get current secret
CURRENT_SECRET=$(aws secretsmanager get-secret-value \
  --secret-id pms/dev/simulation \
  --query SecretString \
  --output text)

# Step 3: Remove DB password, keep API key and JWT secret
SIM_API_KEY=$(echo $CURRENT_SECRET | jq -r '.SIMULATION_API_KEY')
SIM_JWT=$(echo $CURRENT_SECRET | jq -r '.SIMULATION_JWT_SECRET')

aws secretsmanager update-secret \
  --secret-id pms/dev/simulation \
  --secret-string "{
    \"SIMULATION_API_KEY\": \"$SIM_API_KEY\",
    \"SIMULATION_JWT_SECRET\": \"$SIM_JWT\"
  }"
```

#### Migration 2: Delete All RabbitMQ Secrets

**Current State:**
- Properties: `SPRING_RABBITMQ_USERNAME`, `SPRING_RABBITMQ_PASSWORD`, `SPRING_RABBITMQ_HOST`, `SPRING_RABBITMQ_PORT`

**Target State:**
- All deleted (use global `RABBITMQ_USERNAME`, `RABBITMQ_PASSWORD`)

**AWS Commands:**

```bash
# Included in step above - these properties removed from secret
# No additional commands needed
```

#### Migration 3: Verify Service Secrets

**Verify these are actually used:**
- `SIMULATION_API_KEY` → Not found in application.yaml ⚠️
- `SIMULATION_JWT_SECRET` → Not found in application.yaml ⚠️

**Decision Required:** Keep or delete?

---

### Service: trade-capture

#### Migration 1: Delete Service-Specific DB Password

**Current State:**
- AWS Path: `pms/dev/trade-capture`
- Property: `TRADE_CAPTURE_DB_PASSWORD`

**Target State:**
- Deleted (use global `DB_PASSWORD`)

**AWS Commands:**

```bash
# Step 1: Backup
aws secretsmanager get-secret-value \
  --secret-id pms/dev/trade-capture \
  --query SecretString \
  --output text > /tmp/trade-capture-secret-backup.json

# Step 2: Remove DB password and RabbitMQ creds, keep service secrets
CURRENT_SECRET=$(aws secretsmanager get-secret-value \
  --secret-id pms/dev/trade-capture \
  --query SecretString \
  --output text)

TC_API_KEY=$(echo $CURRENT_SECRET | jq -r '.TRADE_CAPTURE_API_KEY')
TC_JWT=$(echo $CURRENT_SECRET | jq -r '.TRADE_CAPTURE_JWT_SECRET')

aws secretsmanager update-secret \
  --secret-id pms/dev/trade-capture \
  --secret-string "{
    \"TRADE_CAPTURE_API_KEY\": \"$TC_API_KEY\",
    \"TRADE_CAPTURE_JWT_SECRET\": \"$TC_JWT\"
  }"
```

#### Migration 2: Delete All RabbitMQ Secrets

**Current State:**
- Properties: `SPRING_RABBITMQ_USERNAME`, `SPRING_RABBITMQ_PASSWORD`

**Target State:**
- Deleted (use global)

(Included in commands above)

---

### Service: validation

#### Migration 1: Delete Service-Specific DB Password

**Current State:**
- AWS Path: `pms/dev/validation`
- Property: `VALIDATION_DB_PASSWORD`

**Target State:**
- Deleted (use global `DB_PASSWORD`)

**AWS Commands:**

```bash
# Step 1: Backup
aws secretsmanager get-secret-value \
  --secret-id pms/dev/validation \
  --query SecretString \
  --output text > /tmp/validation-secret-backup.json

# Step 2: Remove DB password and RabbitMQ creds, keep service secrets
CURRENT_SECRET=$(aws secretsmanager get-secret-value \
  --secret-id pms/dev/validation \
  --query SecretString \
  --output text)

VAL_API_KEY=$(echo $CURRENT_SECRET | jq -r '.VALIDATION_API_KEY')
VAL_JWT=$(echo $CURRENT_SECRET | jq -r '.VALIDATION_JWT_SECRET')

aws secretsmanager update-secret \
  --secret-id pms/dev/validation \
  --secret-string "{
    \"VALIDATION_API_KEY\": \"$VAL_API_KEY\",
    \"VALIDATION_JWT_SECRET\": \"$VAL_JWT\"
  }"
```

#### Migration 2: Delete All RabbitMQ Secrets

**Current State:**
- Properties: `SPRING_RABBITMQ_USERNAME`, `SPRING_RABBITMQ_PASSWORD`, `APP_RABBIT_STREAM_USERNAME`, `APP_RABBIT_STREAM_PASSWORD`

**Target State:**
- All deleted (validation doesn't use RabbitMQ)

(Included in commands above)

---

## 📊 Migration Summary

### AWS Secrets Changes

| AWS Path | Old Properties | New Properties | Action |
|----------|---------------|----------------|--------|
| `pms/dev/database` | `POSTGRES_PASSWORD` | `POSTGRES_PASSWORD`, `POSTGRES_USER` | Add property |
| `pms/dev/rabbitmq` | `RABBITMQ_DEFAULT_USER`, `RABBITMQ_DEFAULT_PASS` | `RABBITMQ_USERNAME`, `RABBITMQ_PASSWORD` (+ old during transition) | Rename properties |
| `pms/dev/auth` | `DATASOURCE_USER`, `DATASOURCE_PASS`, `JWT_SECRET` | `AUTH_JWT_SECRET` (maybe `AUTH_DB_USER`, `AUTH_DB_PASSWORD`) | Remove/rename |
| `pms/dev/simulation` | `SIMULATION_DB_PASSWORD`, `SPRING_RABBITMQ_*`, etc. | `SIMULATION_API_KEY`, `SIMULATION_JWT_SECRET` | Remove global duplicates |
| `pms/dev/trade-capture` | `TRADE_CAPTURE_DB_PASSWORD`, `SPRING_RABBITMQ_*` | `TRADE_CAPTURE_API_KEY`, `TRADE_CAPTURE_JWT_SECRET` | Remove global duplicates |
| `pms/dev/validation` | `VALIDATION_DB_PASSWORD`, `SPRING_RABBITMQ_*`, `APP_RABBIT_*` | `VALIDATION_API_KEY`, `VALIDATION_JWT_SECRET` | Remove global duplicates |

### Secrets to Delete (After Migration)

From **pms/dev/simulation**:
- `SIMULATION_DB_PASSWORD`
- `SPRING_RABBITMQ_USERNAME`
- `SPRING_RABBITMQ_PASSWORD`
- `SPRING_RABBITMQ_HOST` (wrong - should be config)
- `SPRING_RABBITMQ_PORT` (wrong - should be config)

From **pms/dev/trade-capture**:
- `TRADE_CAPTURE_DB_PASSWORD`
- `SPRING_RABBITMQ_USERNAME`
- `SPRING_RABBITMQ_PASSWORD`

From **pms/dev/validation**:
- `VALIDATION_DB_PASSWORD`
- `SPRING_RABBITMQ_USERNAME`
- `SPRING_RABBITMQ_PASSWORD`
- `APP_RABBIT_STREAM_USERNAME`
- `APP_RABBIT_STREAM_PASSWORD`

From **pms/dev/auth** (if using global):
- `DATASOURCE_USER`
- `DATASOURCE_PASS`

---

## 🔄 Verification Commands

After each migration, verify:

```bash
# Verify global database secret
aws secretsmanager get-secret-value \
  --secret-id pms/dev/database \
  --query SecretString \
  --output text | jq .

# Verify global RabbitMQ secret
aws secretsmanager get-secret-value \
  --secret-id pms/dev/rabbitmq \
  --query SecretString \
  --output text | jq .

# Verify service secret (example: auth)
aws secretsmanager get-secret-value \
  --secret-id pms/dev/auth \
  --query SecretString \
  --output text | jq .
```

---

## ⚠️ Safety Checklist

Before running AWS commands:

- [ ] Backup all secrets to local files
- [ ] Document current values
- [ ] Test AWS CLI access and permissions
- [ ] Review each command before execution
- [ ] Run in non-prod environment first
- [ ] Have rollback plan ready
- [ ] Coordinate with team (announce downtime if needed)

---

## 📋 Execution Order

1. ✅ Update `env-contract.md` with missing secrets
2. 🔄 Migrate global secrets (database, RabbitMQ)
3. 🔄 Migrate service secrets (remove duplicates)
4. 🔄 Update Helm charts (Phase 3)
5. 🔄 Update applications (Phase 3)
6. 🔄 Test and validate
7. 🔄 Remove old property names from AWS

---

## 🎯 Phase 2 Complete

**Next Step:** Proceed to **Phase 3: Execute Updates (Helm + Apps + AWS)**

No changes have been made to AWS or any files. This is a planning document only.

**Ready for Phase 3?** Yes, all migrations are mapped with exact commands.
