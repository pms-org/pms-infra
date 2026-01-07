# Configuration Split: Properties vs Secrets

## Overview

This document explains the separation between non-secret configuration (stored in `.properties` files) and secrets (managed via AWS Secrets Manager + External Secrets Operator).

## What Goes Where

### ✅ Properties Files (`.properties`)

Store **non-sensitive configuration** that can be committed to Git:

- Database connection URLs and ports
- Service endpoints and hostnames
- Kafka broker addresses
- Schema registry URLs
- Logging levels
- Feature flags
- Thread pool sizes
- Cache configurations
- Public API keys (if not sensitive)

**Example** (`validation.properties`):
```properties
SPRING_DATASOURCE_URL=jdbc:postgresql://postgres:5432/pmsdb
SPRING_DATASOURCE_DRIVER_CLASS_NAME=org.postgresql.Driver
KAFKA_BOOTSTRAP_SERVERS=kafka:9092
SCHEMA_REGISTRY_URL=http://schema-registry:8081
LOG_LEVEL=INFO
SPRING_JPA_HIBERNATE_DDL_AUTO=update
```

### 🔒 AWS Secrets Manager (ESO)

Store **sensitive secrets** that must never be committed to Git:

- Database passwords
- API keys and tokens
- JWT signing secrets
- Private keys
- Encryption keys
- Service account credentials

**Example** (AWS Secret `pms/validation/dev`):
```json
{
  "VALIDATION_API_KEY": "sk-1234567890abcdef",
  "VALIDATION_DB_PASSWORD": "super-secret-password",
  "VALIDATION_JWT_SECRET": "my-jwt-signing-key"
}
```

## Why This Separation?

### Security Benefits
- **No secrets in Git**: Eliminates risk of credential leaks
- **Access control**: Secrets managed via AWS IAM
- **Audit trail**: AWS CloudTrail logs all secret access
- **Rotation**: Automated secret rotation capabilities

### Operational Benefits
- **Environment flexibility**: Different secrets per environment
- **Service isolation**: Each service manages its own secrets
- **Compliance**: Meets security standards and regulations

### Development Benefits
- **Safe commits**: No risk of accidentally committing secrets
- **Local development**: Use `.env` files or mock secrets for development
- **Clear boundaries**: Developers know what goes where

## Migration Strategy

### Phase 1: Config Ownership
- Move ConfigMap generators to service-owned kustomizations
- Keep existing secret generation temporarily

### Phase 2: ESO Introduction
- Deploy External Secrets Operator
- Create ClusterSecretStore for AWS Secrets Manager
- Create ExternalSecret resources alongside existing secrets

### Phase 3: Secret Migration
- Create secrets in AWS Secrets Manager
- Update ExternalSecret resources to reference AWS secrets
- Remove old secretGenerators from overlays

### Phase 4: Cleanup
- Remove old secret files
- Update documentation
- Validate end-to-end functionality

## Validation Checklist

- [ ] All `.properties` files contain only non-sensitive config
- [ ] No secrets committed to Git repository
- [ ] ESO can access AWS Secrets Manager
- [ ] Applications start successfully with ESO-provided secrets
- [ ] Secret rotation works correctly
- [ ] Environment-specific secrets are properly isolated</content>
<parameter name="filePath">/mnt/c/Developer/pms-new/pms-infra/docs/config-split.md