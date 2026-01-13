# Phase 1: Discovery & Mapping - Compliance Report

**Generated:** January 13, 2026  
**Status:** 🔍 **DISCOVERY COMPLETE - NO CHANGES MADE**

This report maps all current secrets across the PMS platform against the authoritative `env-contract.md`. Each service is analyzed for compliance with canonical naming, AWS path structure, and proper secret classification.

---

## 📊 Executive Summary

### Contract-Defined Secrets

**GLOBAL_SECRET (7 secrets)**
- `DB_PASSWORD` → `pms/dev/database:POSTGRES_PASSWORD`
- `RABBITMQ_USERNAME` → `pms/dev/rabbitmq:RABBITMQ_DEFAULT_USER`
- `RABBITMQ_PASSWORD` → `pms/dev/rabbitmq:RABBITMQ_DEFAULT_PASS`
- `KAFKA_ADMIN_PASSWORD` → `pms/dev/kafka:KAFKA_ADMIN_PASSWORD`
- `KAFKA_USER_PASSWORD` → `pms/dev/kafka:KAFKA_USER_PASSWORD`
- `REDIS_PASSWORD` → `pms/dev/redis:REDIS_PASSWORD`
- `SCHEMA_REGISTRY_API_KEY` → `pms/dev/schema-registry:SCHEMA_REGISTRY_API_KEY`
- `SCHEMA_REGISTRY_API_SECRET` → `pms/dev/schema-registry:SCHEMA_REGISTRY_API_SECRET`

**SERVICE_SECRET (Not explicitly documented in contract)**
- Auth: `AUTH_DB_USER`, `AUTH_DB_PASSWORD`, `AUTH_JWT_SECRET`
- Simulation: `SIMULATION_API_KEY`, `SIMULATION_JWT_SECRET`
- Trade-Capture: `TRADE_CAPTURE_API_KEY`, `TRADE_CAPTURE_JWT_SECRET`
- Validation: `VALIDATION_API_KEY`, `VALIDATION_JWT_SECRET`

### Overall Compliance Status

| Service | Total Secrets | Compliant | Non-Compliant | Orphaned | Compliance % |
|---------|--------------|-----------|---------------|----------|--------------|
| **apigateway** | 0 | 0 | 0 | 0 | N/A |
| **auth** | 3 | 0 | 3 | 0 | 0% ❌ |
| **simulation** | 9 | 0 | 9 | 2 | 0% ❌ |
| **trade-capture** | 7 | 0 | 7 | 0 | 0% ❌ |
| **validation** | 7 | 0 | 7 | 3 | 0% ❌ |
| **TOTAL** | **26** | **0** | **23** | **5** | **0%** ❌ |

---

## 🔍 Service-by-Service Analysis

---

### Service: `apigateway`

**Status:** ✅ **COMPLIANT** (No secrets required)

#### Current State
- **Helm values.yaml**: `secrets.data: []` (empty)
- **ExternalSecret template**: Conditional (`{{- if .Values.secrets.data }}`)
- **application.yaml**: No secret references

#### Analysis
- Service does not require any secrets per contract
- Redis connection does not require password (handled by infrastructure)
- Fully compliant with contract

---

### Service: `auth`

**Status:** ❌ **NON-COMPLIANT** (0% compliance)

#### Current Secrets in Helm (values.yaml)

| Current Name | AWS Path | AWS Property | Used In | Status |
|--------------|----------|--------------|---------|--------|
| `DATASOURCE_USER` | `pms/dev/auth` | `DATASOURCE_USER` | application.yaml | ❌ Non-compliant |
| `DATASOURCE_PASS` | `pms/dev/auth` | `DATASOURCE_PASS` | application.yaml | ❌ Non-compliant |
| `JWT_SECRET` | `pms/dev/auth` | `JWT_SECRET` | Spring Security | ❌ Non-compliant |

#### Application.yaml Secret References

```yaml
spring:
  datasource:
    username: ${DB_USERNAME}  # ❌ Variable name mismatch
    password: ${DB_PASSWORD}  # ❌ Variable name mismatch
```

#### Issues Identified

1. **Variable Name Mismatch**
   - Helm defines: `DATASOURCE_USER`, `DATASOURCE_PASS`
   - Application expects: `DB_USERNAME`, `DB_PASSWORD`
   - Contract defines: `DB_PASSWORD` (global), no username in contract

2. **Wrong Classification**
   - Using service-specific DB password (`DATASOURCE_PASS`)
   - Should use `GLOBAL_SECRET`: `DB_PASSWORD`
   - DB username should be `GLOBAL_CONFIG` or `GLOBAL_SECRET`

3. **Non-Canonical Naming**
   - `JWT_SECRET` should be `AUTH_JWT_SECRET` (if service-specific)
   - `DATASOURCE_*` prefix not in contract naming convention

4. **Missing from Contract**
   - `DB_USERNAME` not defined in contract (global or service-specific)
   - `AUTH_DB_USER`, `AUTH_DB_PASSWORD`, `AUTH_JWT_SECRET` not in SERVICE_SECRET section

#### Compliance Mapping

| Current | Location | AWS Path | Contract Name | Classification | Action Required |
|---------|----------|----------|---------------|----------------|-----------------|
| `DATASOURCE_USER` | Helm | `pms/dev/auth:DATASOURCE_USER` | `DB_USERNAME` | Should be GLOBAL_SECRET | Add to contract, rename |
| `DATASOURCE_PASS` | Helm | `pms/dev/auth:DATASOURCE_PASS` | `DB_PASSWORD` | GLOBAL_SECRET | Move to global path |
| `JWT_SECRET` | Helm | `pms/dev/auth:JWT_SECRET` | `AUTH_JWT_SECRET` | SERVICE_SECRET | Rename, add to contract |
| `DB_USERNAME` | App | N/A | Not in contract | GLOBAL_SECRET | Add to contract |
| `DB_PASSWORD` | App | N/A | `DB_PASSWORD` | GLOBAL_SECRET | Use global secret |

---

### Service: `simulation`

**Status:** ❌ **NON-COMPLIANT** (0% compliance)

#### Current Secrets in Helm (values.yaml)

| Current Name | AWS Path | AWS Property | Used In | Status |
|--------------|----------|--------------|---------|--------|
| `SIMULATION_DB_PASSWORD` | `pms/dev/simulation` | `SIMULATION_DB_PASSWORD` | application.yaml | ❌ Non-compliant |
| `SIMULATION_API_KEY` | `pms/dev/simulation` | `SIMULATION_API_KEY` | N/A | ⚠️ Orphaned |
| `SIMULATION_JWT_SECRET` | `pms/dev/simulation` | `SIMULATION_JWT_SECRET` | N/A | ⚠️ Orphaned |
| `SPRING_RABBITMQ_USERNAME` | `pms/dev/simulation` | `SPRING_RABBITMQ_USERNAME` | N/A | ❌ Non-compliant |
| `SPRING_RABBITMQ_PASSWORD` | `pms/dev/simulation` | `SPRING_RABBITMQ_PASSWORD` | N/A | ❌ Non-compliant |
| `SPRING_RABBITMQ_STREAM_USERNAME` | `pms/dev/simulation` | `SPRING_RABBITMQ_USERNAME` | N/A | ❌ Non-compliant |
| `SPRING_RABBITMQ_STREAM_PASSWORD` | `pms/dev/simulation` | `SPRING_RABBITMQ_PASSWORD` | N/A | ❌ Non-compliant |
| `SPRING_RABBITMQ_HOST` | `pms/dev/simulation` | `SPRING_RABBITMQ_HOST` | N/A | ❌ Wrong - should be config |
| `SPRING_RABBITMQ_PORT` | `pms/dev/simulation` | `SPRING_RABBITMQ_PORT` | N/A | ❌ Wrong - should be config |

#### Application.yaml Secret References

```yaml
spring:
  datasource:
    username: ${DB_USERNAME}    # ❌ Not in Helm secrets
    password: ${DB_PASSWORD}    # ❌ Not in Helm secrets

app:
  rabbitmq:
    stream:
      username: ${RABBITMQ_USERNAME}  # ✅ Canonical name
      password: ${RABBITMQ_PASSWORD}  # ✅ Canonical name
```

#### Issues Identified

1. **Database Secret Misalignment**
   - Helm defines: `SIMULATION_DB_PASSWORD`
   - Application expects: `DB_PASSWORD`, `DB_USERNAME`
   - Contract defines: `DB_PASSWORD` as GLOBAL_SECRET
   - **Application is correct**, Helm is wrong

2. **RabbitMQ Secret Duplication**
   - 4 RabbitMQ secret mappings in Helm with `SPRING_*` prefix
   - Application uses canonical: `RABBITMQ_USERNAME`, `RABBITMQ_PASSWORD`
   - Contract defines these as GLOBAL_SECRET
   - All `SPRING_*` variants should be deleted

3. **Orphaned Secrets**
   - `SIMULATION_API_KEY` not referenced anywhere
   - `SIMULATION_JWT_SECRET` not referenced anywhere
   - These may be future requirements or legacy

4. **Wrong Classification**
   - `SPRING_RABBITMQ_HOST`, `SPRING_RABBITMQ_PORT` stored as secrets
   - These are configuration, not secrets

5. **Missing DB_USERNAME**
   - Application requires `DB_USERNAME`
   - Not in Helm secrets
   - Not in contract

#### Compliance Mapping

| Current | Location | AWS Path | Contract Name | Classification | Action Required |
|---------|----------|----------|---------------|----------------|-----------------|
| `SIMULATION_DB_PASSWORD` | Helm | `pms/dev/simulation:SIMULATION_DB_PASSWORD` | `DB_PASSWORD` | GLOBAL_SECRET | Delete, use global |
| `DB_USERNAME` | App | N/A | Not in contract | GLOBAL_SECRET | Add to contract, add to global |
| `DB_PASSWORD` | App | N/A | `DB_PASSWORD` | GLOBAL_SECRET | Add to Helm from global |
| `SPRING_RABBITMQ_USERNAME` | Helm | `pms/dev/simulation:SPRING_RABBITMQ_USERNAME` | `RABBITMQ_USERNAME` | GLOBAL_SECRET | Delete, use global |
| `SPRING_RABBITMQ_PASSWORD` | Helm | `pms/dev/simulation:SPRING_RABBITMQ_PASSWORD` | `RABBITMQ_PASSWORD` | GLOBAL_SECRET | Delete, use global |
| `SPRING_RABBITMQ_STREAM_USERNAME` | Helm | `pms/dev/simulation:SPRING_RABBITMQ_USERNAME` | `RABBITMQ_USERNAME` | GLOBAL_SECRET | Delete (duplicate) |
| `SPRING_RABBITMQ_STREAM_PASSWORD` | Helm | `pms/dev/simulation:SPRING_RABBITMQ_PASSWORD` | `RABBITMQ_PASSWORD` | GLOBAL_SECRET | Delete (duplicate) |
| `RABBITMQ_USERNAME` | App | N/A | `RABBITMQ_USERNAME` | GLOBAL_SECRET | Add to Helm from global |
| `RABBITMQ_PASSWORD` | App | N/A | `RABBITMQ_PASSWORD` | GLOBAL_SECRET | Add to Helm from global |
| `SPRING_RABBITMQ_HOST` | Helm | `pms/dev/simulation:SPRING_RABBITMQ_HOST` | N/A | Wrong - should be config | Delete from secrets |
| `SPRING_RABBITMQ_PORT` | Helm | `pms/dev/simulation:SPRING_RABBITMQ_PORT` | N/A | Wrong - should be config | Delete from secrets |
| `SIMULATION_API_KEY` | Helm | `pms/dev/simulation:SIMULATION_API_KEY` | Not in contract | SERVICE_SECRET? | Add to contract or delete |
| `SIMULATION_JWT_SECRET` | Helm | `pms/dev/simulation:SIMULATION_JWT_SECRET` | Not in contract | SERVICE_SECRET? | Add to contract or delete |

---

### Service: `trade-capture`

**Status:** ❌ **NON-COMPLIANT** (0% compliance)

#### Current Secrets in Helm (values.yaml)

| Current Name | AWS Path | AWS Property | Used In | Status |
|--------------|----------|--------------|---------|--------|
| `TRADE_CAPTURE_DB_PASSWORD` | `pms/dev/trade-capture` | `TRADE_CAPTURE_DB_PASSWORD` | N/A | ❌ Non-compliant |
| `TRADE_CAPTURE_API_KEY` | `pms/dev/trade-capture` | `TRADE_CAPTURE_API_KEY` | N/A | ⚠️ Orphaned |
| `TRADE_CAPTURE_JWT_SECRET` | `pms/dev/trade-capture` | `TRADE_CAPTURE_JWT_SECRET` | N/A | ⚠️ Orphaned |
| `SPRING_RABBITMQ_USERNAME` | `pms/dev/trade-capture` | `SPRING_RABBITMQ_USERNAME` | N/A | ❌ Non-compliant |
| `SPRING_RABBITMQ_PASSWORD` | `pms/dev/trade-capture` | `SPRING_RABBITMQ_PASSWORD` | N/A | ❌ Non-compliant |
| `APP_RABBIT_STREAM_USERNAME` | `pms/dev/trade-capture` | `SPRING_RABBITMQ_USERNAME` | application.yaml | ❌ Non-compliant |
| `APP_RABBIT_STREAM_PASSWORD` | `pms/dev/trade-capture` | `SPRING_RABBITMQ_PASSWORD` | application.yaml | ❌ Non-compliant |

#### Application.yaml Secret References

```yaml
spring:
  datasource:
    username: ${DATASOURCE_USER:pms}    # ❌ Non-canonical name
    password: ${DATASOURCE_PASS:pms}    # ❌ Non-canonical name

app:
  rabbit:
    stream:
      username: ${RABBIT_STREAM_USERNAME:guest}  # ❌ Non-canonical name
      password: ${RABBIT_STREAM_PASSWORD:guest}  # ❌ Non-canonical name
```

#### Issues Identified

1. **Database Secret Misalignment**
   - Helm defines: `TRADE_CAPTURE_DB_PASSWORD`
   - Application expects: `DATASOURCE_USER`, `DATASOURCE_PASS`
   - Contract defines: `DB_PASSWORD` (global)
   - **Triple mismatch**: Helm, App, Contract all different

2. **RabbitMQ Secret Naming Chaos**
   - Helm has: `SPRING_RABBITMQ_USERNAME`, `APP_RABBIT_STREAM_USERNAME`
   - Application uses: `RABBIT_STREAM_USERNAME`, `RABBIT_STREAM_PASSWORD`
   - Contract defines: `RABBITMQ_USERNAME`, `RABBITMQ_PASSWORD`
   - No consistency across layers

3. **Orphaned Secrets**
   - `TRADE_CAPTURE_API_KEY` not referenced
   - `TRADE_CAPTURE_JWT_SECRET` not referenced

4. **Missing DB_USERNAME**
   - Application has fallback `DATASOURCE_USER:pms`
   - Not in Helm secrets
   - Not in contract

#### Compliance Mapping

| Current | Location | AWS Path | Contract Name | Classification | Action Required |
|---------|----------|----------|---------------|----------------|-----------------|
| `TRADE_CAPTURE_DB_PASSWORD` | Helm | `pms/dev/trade-capture:TRADE_CAPTURE_DB_PASSWORD` | `DB_PASSWORD` | GLOBAL_SECRET | Delete, use global |
| `DATASOURCE_USER` | App | N/A | Not in contract | GLOBAL_SECRET | Add to contract, rename to DB_USERNAME |
| `DATASOURCE_PASS` | App | N/A | `DB_PASSWORD` | GLOBAL_SECRET | Rename to DB_PASSWORD |
| `SPRING_RABBITMQ_USERNAME` | Helm | `pms/dev/trade-capture:SPRING_RABBITMQ_USERNAME` | `RABBITMQ_USERNAME` | GLOBAL_SECRET | Delete, use global |
| `SPRING_RABBITMQ_PASSWORD` | Helm | `pms/dev/trade-capture:SPRING_RABBITMQ_PASSWORD` | `RABBITMQ_PASSWORD` | GLOBAL_SECRET | Delete, use global |
| `APP_RABBIT_STREAM_USERNAME` | Helm | `pms/dev/trade-capture:SPRING_RABBITMQ_USERNAME` | `RABBITMQ_USERNAME` | GLOBAL_SECRET | Delete, use global |
| `APP_RABBIT_STREAM_PASSWORD` | Helm | `pms/dev/trade-capture:SPRING_RABBITMQ_PASSWORD` | `RABBITMQ_PASSWORD` | GLOBAL_SECRET | Delete, use global |
| `RABBIT_STREAM_USERNAME` | App | N/A | `RABBITMQ_USERNAME` | GLOBAL_SECRET | Rename to RABBITMQ_USERNAME |
| `RABBIT_STREAM_PASSWORD` | App | N/A | `RABBITMQ_PASSWORD` | GLOBAL_SECRET | Rename to RABBITMQ_PASSWORD |
| `TRADE_CAPTURE_API_KEY` | Helm | `pms/dev/trade-capture:TRADE_CAPTURE_API_KEY` | Not in contract | SERVICE_SECRET? | Add to contract or delete |
| `TRADE_CAPTURE_JWT_SECRET` | Helm | `pms/dev/trade-capture:TRADE_CAPTURE_JWT_SECRET` | Not in contract | SERVICE_SECRET? | Add to contract or delete |

---

### Service: `validation`

**Status:** ❌ **NON-COMPLIANT** (0% compliance)

#### Current Secrets in Helm (values.yaml)

| Current Name | AWS Path | AWS Property | Used In | Status |
|--------------|----------|--------------|---------|--------|
| `VALIDATION_API_KEY` | `pms/dev/validation` | `VALIDATION_API_KEY` | N/A | ⚠️ Orphaned |
| `VALIDATION_DB_PASSWORD` | `pms/dev/validation` | `VALIDATION_DB_PASSWORD` | N/A | ❌ Non-compliant |
| `VALIDATION_JWT_SECRET` | `pms/dev/validation` | `VALIDATION_JWT_SECRET` | N/A | ⚠️ Orphaned |
| `SPRING_RABBITMQ_USERNAME` | `pms/dev/validation` | `SPRING_RABBITMQ_USERNAME` | N/A | ❌ Non-compliant |
| `SPRING_RABBITMQ_PASSWORD` | `pms/dev/validation` | `SPRING_RABBITMQ_PASSWORD` | N/A | ❌ Non-compliant |
| `APP_RABBIT_STREAM_USERNAME` | `pms/dev/validation` | `SPRING_RABBITMQ_USERNAME` | N/A | ❌ Non-compliant |
| `APP_RABBIT_STREAM_PASSWORD` | `pms/dev/validation` | `SPRING_RABBITMQ_PASSWORD` | N/A | ❌ Non-compliant |

#### Application.yaml Secret References

```yaml
spring:
  datasource:
    url: ${DB_URL}              # ❌ Non-canonical variable name
    username: ${DB_USERNAME}    # ✅ Canonical name (not in Helm)
    password: ${DB_PASSWORD}    # ✅ Canonical name (not in Helm)
```

#### Issues Identified

1. **Database Secret Misalignment**
   - Helm defines: `VALIDATION_DB_PASSWORD`
   - Application expects: `DB_USERNAME`, `DB_PASSWORD`
   - Contract defines: `DB_PASSWORD` (global)
   - **Application is correct**, Helm is wrong

2. **RabbitMQ Secret Overload**
   - 4 RabbitMQ-related secrets in Helm
   - Not referenced in application.yaml
   - Application doesn't use RabbitMQ (Kafka-only)
   - **All RabbitMQ secrets are orphaned**

3. **DB_URL vs DB_HOST**
   - Application uses: `DB_URL` (full JDBC URL)
   - Contract defines: `DB_HOST`, `DB_PORT`, `DB_NAME` (separate)
   - ConfigMap has: `DB_HOST`, `DB_PORT`, `DB_NAME`
   - **Application needs refactoring** to use separate variables

4. **Orphaned Secrets**
   - `VALIDATION_API_KEY` not referenced
   - `VALIDATION_JWT_SECRET` not referenced
   - All RabbitMQ secrets not referenced

#### Compliance Mapping

| Current | Location | AWS Path | Contract Name | Classification | Action Required |
|---------|----------|----------|---------------|----------------|-----------------|
| `VALIDATION_DB_PASSWORD` | Helm | `pms/dev/validation:VALIDATION_DB_PASSWORD` | `DB_PASSWORD` | GLOBAL_SECRET | Delete, use global |
| `DB_USERNAME` | App | N/A | Not in contract | GLOBAL_SECRET | Add to contract, add to global |
| `DB_PASSWORD` | App | N/A | `DB_PASSWORD` | GLOBAL_SECRET | Add to Helm from global |
| `DB_URL` | App | N/A | Should be composite | GLOBAL_CONFIG | Refactor to use DB_HOST/PORT/NAME |
| `SPRING_RABBITMQ_USERNAME` | Helm | `pms/dev/validation:SPRING_RABBITMQ_USERNAME` | N/A | Orphaned | Delete (not used) |
| `SPRING_RABBITMQ_PASSWORD` | Helm | `pms/dev/validation:SPRING_RABBITMQ_PASSWORD` | N/A | Orphaned | Delete (not used) |
| `APP_RABBIT_STREAM_USERNAME` | Helm | `pms/dev/validation:SPRING_RABBITMQ_USERNAME` | N/A | Orphaned | Delete (not used) |
| `APP_RABBIT_STREAM_PASSWORD` | Helm | `pms/dev/validation:SPRING_RABBITMQ_PASSWORD` | N/A | Orphaned | Delete (not used) |
| `VALIDATION_API_KEY` | Helm | `pms/dev/validation:VALIDATION_API_KEY` | Not in contract | SERVICE_SECRET? | Add to contract or delete |
| `VALIDATION_JWT_SECRET` | Helm | `pms/dev/validation:VALIDATION_JWT_SECRET` | Not in contract | SERVICE_SECRET? | Add to contract or delete |

---

## 📝 Cross-Cutting Issues

### Issue 1: Missing `DB_USERNAME` in Contract

**Severity:** 🔴 **CRITICAL**

All services require database username, but it's not defined in `env-contract.md`:
- **auth** app uses: `${DB_USERNAME}`
- **simulation** app uses: `${DB_USERNAME}`
- **trade-capture** app uses: `${DATASOURCE_USER}`
- **validation** app uses: `${DB_USERNAME}`

**Decision Required:**
1. Is DB username a **GLOBAL_SECRET** or **GLOBAL_CONFIG**?
   - If all services use same user → GLOBAL_SECRET
   - If username is not sensitive → GLOBAL_CONFIG
2. What is the canonical name? `DB_USERNAME` (recommended)
3. What is the AWS path? `pms/dev/database:POSTGRES_USER`?

---

### Issue 2: Service-Specific Secrets Not in Contract

**Severity:** 🟡 **MEDIUM**

The following secrets are defined in Helm but not in contract's SERVICE_SECRET section:
- `SIMULATION_API_KEY`
- `SIMULATION_JWT_SECRET`
- `TRADE_CAPTURE_API_KEY`
- `TRADE_CAPTURE_JWT_SECRET`
- `VALIDATION_API_KEY`
- `VALIDATION_JWT_SECRET`

**Analysis:**
- None are referenced in application.yaml files
- May be intended for future use
- May be legacy/orphaned

**Recommendation:**
1. Verify with service teams if these are required
2. If yes → Add to contract as SERVICE_SECRET
3. If no → Delete from AWS and Helm

---

### Issue 3: RabbitMQ Credentials Chaos

**Severity:** 🔴 **CRITICAL**

RabbitMQ credentials have multiple naming conventions:
- **Contract**: `RABBITMQ_USERNAME`, `RABBITMQ_PASSWORD`
- **Simulation Helm**: `SPRING_RABBITMQ_USERNAME`, `SPRING_RABBITMQ_PASSWORD`, `SPRING_RABBITMQ_STREAM_USERNAME`, `SPRING_RABBITMQ_STREAM_PASSWORD`
- **Simulation App**: `RABBITMQ_USERNAME`, `RABBITMQ_PASSWORD`
- **Trade-Capture Helm**: `SPRING_RABBITMQ_USERNAME`, `APP_RABBIT_STREAM_USERNAME`
- **Trade-Capture App**: `RABBIT_STREAM_USERNAME`, `RABBIT_STREAM_PASSWORD`
- **Validation Helm**: 4 RabbitMQ secrets (not used)

**Impact:**
- 100% non-compliance
- Confusion about which variable to use
- Duplicate AWS secrets

**Recommendation:**
1. **Canonical names**: `RABBITMQ_USERNAME`, `RABBITMQ_PASSWORD`
2. **AWS path**: `pms/dev/rabbitmq:RABBITMQ_DEFAULT_USER`, `pms/dev/rabbitmq:RABBITMQ_DEFAULT_PASS`
3. **Delete all**: `SPRING_*`, `APP_*` variants
4. **Update applications**: Use canonical names only

---

### Issue 4: Database Password Duplication

**Severity:** 🔴 **CRITICAL**

Every service has its own DB password in AWS:
- `pms/dev/auth:DATASOURCE_PASS`
- `pms/dev/simulation:SIMULATION_DB_PASSWORD`
- `pms/dev/trade-capture:TRADE_CAPTURE_DB_PASSWORD`
- `pms/dev/validation:VALIDATION_DB_PASSWORD`

**Contract says:** `DB_PASSWORD` is a **GLOBAL_SECRET** at `pms/dev/database:POSTGRES_PASSWORD`

**Current reality:** 4+ different DB passwords across services

**Recommendation:**
1. Verify all services use same PostgreSQL database
2. If yes → Delete all service-specific DB passwords
3. Use single global: `pms/dev/database:POSTGRES_PASSWORD`
4. Update Helm to reference global secret

---

### Issue 5: Variable Name Inconsistency

**Severity:** 🟡 **MEDIUM**

Same secret has different names across layers:

**Database Password:**
- Contract: `DB_PASSWORD`
- Auth Helm: `DATASOURCE_PASS`
- Auth App: `DB_PASSWORD`
- Simulation Helm: `SIMULATION_DB_PASSWORD`
- Simulation App: `DB_PASSWORD`
- Trade-Capture Helm: `TRADE_CAPTURE_DB_PASSWORD`
- Trade-Capture App: `DATASOURCE_PASS`
- Validation Helm: `VALIDATION_DB_PASSWORD`
- Validation App: `DB_PASSWORD`

**Impact:**
- Applications using correct canonical names
- Helm charts using wrong names
- ExternalSecrets injecting wrong variable names

**Recommendation:**
1. Applications are mostly correct → Keep as-is
2. Fix Helm values.yaml → Use canonical names
3. Fix ExternalSecret mappings → secretKey = canonical name

---

## 🎯 Summary of Required Actions

### Immediate Actions (Block deployments)

1. **Add `DB_USERNAME` to contract** as GLOBAL_SECRET
2. **Standardize all database secrets** to use `DB_PASSWORD`, `DB_USERNAME` (global)
3. **Standardize all RabbitMQ secrets** to use `RABBITMQ_USERNAME`, `RABBITMQ_PASSWORD` (global)
4. **Delete orphaned RabbitMQ secrets** from validation service

### Medium Priority (Next sprint)

1. **Add SERVICE_SECRET section** to contract for API keys and JWT secrets
2. **Verify and document** service-specific secrets (or delete if unused)
3. **Refactor validation app** to use `DB_HOST`/`DB_PORT`/`DB_NAME` instead of `DB_URL`

### Low Priority (Technical debt)

1. **Consolidate AWS secret paths** to match contract exactly
2. **Remove legacy secret names** from AWS Secrets Manager
3. **Standardize all Helm templates** to use same pattern

---

## 📊 Metrics

### Discovery Results
- **Services Analyzed:** 5 (apigateway, auth, simulation, trade-capture, validation)
- **Total Secrets Found:** 26
- **Compliant Secrets:** 0
- **Non-Compliant Secrets:** 23
- **Orphaned Secrets:** 5 (not referenced in apps)
- **Missing from Contract:** 13 (DB_USERNAME + 12 service secrets)

### Top Issues
1. 🔴 **0% compliance** with canonical naming
2. 🔴 **100% of services** using non-canonical DB secrets
3. 🔴 **100% of RabbitMQ secrets** non-compliant
4. 🟡 **19% orphaned secrets** (5/26 not used)

---

## ✅ Phase 1 Complete

**Next Step:** Proceed to **Phase 2: Canonical Mapping Plan**

No changes have been made to any files. This is a discovery-only report.
