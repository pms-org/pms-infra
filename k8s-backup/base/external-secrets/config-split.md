# Config Split: Local vs AWS Secrets Manager

## What Stays in `.properties` Files (Local)

**.properties files contain NON-SECRET configuration that can be committed to Git:**

### Database Configuration (Non-Secret)
```properties
DB_HOST=postgres
DB_PORT=5432
DB_NAME=pmsdb
DATASOURCE_DRIVER=org.postgresql.Driver
```

### Infrastructure Connection Details
```properties
REDIS_HOST=redis
REDIS_PORT=6379
KAFKA_BOOTSTRAP_SERVERS=kafka:9092
SCHEMA_REGISTRY_URL=http://schema-registry:8081
```

### Application Settings
```properties
SPRING_APPLICATION_NAME=validation
SERVER_PORT=8080
HIBERNATE_DDL_AUTO=update
CACHE_TYPE=redis
```

### Kafka Topics & Consumer Groups
```properties
KAFKA_CONSUMER_GROUP_ID=validation-consumer-group
INCOMING_TRADES_TOPIC=raw-trades-topic
OUTGOING_VALID_TRADES_TOPIC=valid-trades-topic
```

## What Moves to AWS Secrets Manager

**Secrets are sensitive values that should NEVER be committed to Git:**

### Database Credentials
```json
{
  "DB_USERNAME": "pmsuser",
  "DB_PASSWORD": "secure-password-here"
}
```

### API Keys & Tokens
```json
{
  "API_KEY": "your-api-key-here",
  "JWT_SECRET": "your-jwt-secret-here"
}
```

### Service-Specific Secrets
```json
{
  "SERVICE_SECRET_KEY": "service-specific-secret",
  "ENCRYPTION_KEY": "encryption-key-here"
}
```

## Why This Split?

### Properties Files (.properties)
- ✅ **Version Controlled**: Changes tracked in Git
- ✅ **Environment Aware**: Different values per environment
- ✅ **Readable**: Human-readable configuration
- ✅ **Non-Sensitive**: Safe to commit to repository
- ✅ **Infrastructure Config**: Connection details, ports, hosts

### AWS Secrets Manager
- ✅ **Encrypted**: Secrets encrypted at rest
- ✅ **Access Controlled**: IAM policies control access
- ✅ **Auditable**: CloudTrail logs all access
- ✅ **Rotatable**: Automatic secret rotation support
- ✅ **Sensitive Data**: Passwords, keys, tokens

## Example: Validation Service

### validation.properties (Local)
```properties
# Non-secret configuration
DB_HOST=postgres
DB_PORT=5432
DB_NAME=pmsdb
KAFKA_BOOTSTRAP_SERVERS=kafka:9092
SERVER_PORT=8080
CACHE_TYPE=redis
```

### AWS Secrets Manager: `pms/validation/dev`
```json
{
  "VALIDATION_API_KEY": "dev-api-key-123",
  "VALIDATION_DB_PASSWORD": "secure-db-password",
  "VALIDATION_JWT_SECRET": "dev-jwt-secret-456"
}
```

### ExternalSecret Mapping
```yaml
data:
  - secretKey: API_KEY
    remoteRef:
      key: pms/validation/dev
      property: VALIDATION_API_KEY
  - secretKey: DB_PASSWORD
    remoteRef:
      key: pms/validation/dev
      property: VALIDATION_DB_PASSWORD
```

## Deployment envFrom Pattern

Applications use both ConfigMap and Secret:

```yaml
envFrom:
  - configMapRef:
      name: validation-config  # From .properties file
  - secretRef:
      name: validation-secrets  # From AWS Secrets Manager
```

## Migration Checklist

- [ ] Identify all `.env` files and extract secrets
- [ ] Create AWS Secrets Manager entries
- [ ] Move non-secret config to `.properties` files
- [ ] Create ExternalSecret resources
- [ ] Update kustomizations to include external-secret.yaml
- [ ] Remove secretGenerator from overlays
- [ ] Test that applications can access both local config and AWS secrets
- [ ] Remove old `.env` files from repository

## Security Benefits

1. **No Secrets in Git**: Secrets never committed to repository
2. **Encryption**: AWS handles encryption/decryption
3. **Access Control**: IAM policies control secret access
4. **Audit Trail**: All secret access is logged
5. **Rotation**: Secrets can be rotated without code changes
6. **Environment Isolation**: Different secrets per environment