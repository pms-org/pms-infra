# PMS Platform Environment Variables & Configuration Standard

## Overview
This document defines the standard environment variables and configuration for all PMS services.
All teams must align to these standards to ensure consistency across the platform.

## Configuration Principles

1. **Use Spring Boot property naming conventions**: `app.service.property`
2. **Environment variables use UPPERCASE_SNAKE_CASE**: `APP_SERVICE_PROPERTY`
3. **ConfigMaps for non-sensitive data**, **Secrets for sensitive data**
4. **No hardcoded credentials** - all credentials from AWS Secrets Manager
5. **Consistent naming across services**

---

## Standard Environment Variables

### 1. Database (PostgreSQL)

#### ConfigMap (Non-Sensitive)
```yaml
DB_HOST: postgres                                    # PostgreSQL service hostname
DB_PORT: "5432"                                      # PostgreSQL port
DB_NAME: pmsdb                                       # Database name
SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/pmsdb
SPRING_DATASOURCE_DRIVER_CLASS_NAME: org.postgresql.Driver
SPRING_JPA_HIBERNATE_DDL_AUTO: update               # Options: none, update, create, create-drop
SPRING_JPA_DATABASE_PLATFORM: org.hibernate.dialect.PostgreSQLDialect
SPRING_JPA_SHOW_SQL: "false"                        # Set to true for debugging
```

#### Secrets (Sensitive)
```yaml
DB_USER: <from-aws-secrets-manager>                 # Database username
DB_PASSWORD: <from-aws-secrets-manager>              # Database password
SPRING_DATASOURCE_USERNAME: <from-aws-secrets-manager>
SPRING_DATASOURCE_PASSWORD: <from-aws-secrets-manager>
```

#### AWS Secrets Manager Keys
- `DB_USER`
- `DB_PASSWORD`
- `SPRING_DATASOURCE_USERNAME`
- `SPRING_DATASOURCE_PASSWORD`

---

### 2. RabbitMQ (AMQP & Streams)

#### ConfigMap (Non-Sensitive)
```yaml
RABBITMQ_HOST: rabbitmq                              # RabbitMQ service hostname
RABBITMQ_AMQP_PORT: "5672"                          # AMQP protocol port
RABBITMQ_MANAGEMENT_PORT: "15672"                    # Management UI port
RABBITMQ_STREAM_PORT: "5552"                        # Stream protocol port
RABBITMQ_STREAM_NAME: trade-stream                   # Default stream name
SPRING_RABBITMQ_HOST: rabbitmq
SPRING_RABBITMQ_PORT: "5552"                        # Use stream port for services
SPRING_RABBITMQ_STREAM_HOST: rabbitmq
SPRING_RABBITMQ_STREAM_PORT: "5552"
```

#### Secrets (Sensitive)
```yaml
RABBITMQ_USERNAME: <from-aws-secrets-manager>        # RabbitMQ username
RABBITMQ_PASSWORD: <from-aws-secrets-manager>        # RabbitMQ password
SPRING_RABBITMQ_USERNAME: <from-aws-secrets-manager>
SPRING_RABBITMQ_PASSWORD: <from-aws-secrets-manager>
SPRING_RABBITMQ_STREAM_USERNAME: <from-aws-secrets-manager>
SPRING_RABBITMQ_STREAM_PASSWORD: <from-aws-secrets-manager>
```

#### Application YAML Properties (Spring Boot)
```yaml
app:
  rabbitmq:
    stream:
      host: ${RABBITMQ_HOST}
      port: ${RABBITMQ_STREAM_PORT}
      name: ${RABBITMQ_STREAM_NAME}
      username: ${app.rabbitmq.stream.username:guest}  # Maps from SPRING_RABBITMQ_STREAM_USERNAME
      password: ${app.rabbitmq.stream.password:guest}  # Maps from SPRING_RABBITMQ_STREAM_PASSWORD
```

#### AWS Secrets Manager Keys
- `RABBITMQ_USERNAME`
- `RABBITMQ_PASSWORD`
- `SPRING_RABBITMQ_USERNAME`
- `SPRING_RABBITMQ_PASSWORD`
- `SPRING_RABBITMQ_STREAM_USERNAME` (same as SPRING_RABBITMQ_USERNAME)
- `SPRING_RABBITMQ_STREAM_PASSWORD` (same as SPRING_RABBITMQ_PASSWORD)

---

### 3. Kafka & Schema Registry

#### ConfigMap (Non-Sensitive)
```yaml
KAFKA_BOOTSTRAP_SERVERS: kafka:9092                  # Kafka broker address
KAFKA_INTERNAL_PORT: "19092"                        # Internal broker port
SPRING_KAFKA_BOOTSTRAP_SERVERS: kafka:9092
SCHEMA_REGISTRY_URL: http://schema-registry:8081     # Schema Registry URL
SPRING_KAFKA_PROPERTIES_SCHEMA_REGISTRY_URL: http://schema-registry:8081
KAFKA_TRADE_TOPIC: trade-events                      # Topic name for trade events
```

#### Secrets (Sensitive)
```yaml
# Currently no authentication required for Kafka in dev
# Add these when enabling SASL/SSL:
# KAFKA_SASL_USERNAME: <from-aws-secrets-manager>
# KAFKA_SASL_PASSWORD: <from-aws-secrets-manager>
```

---

### 4. Redis

#### ConfigMap (Non-Sensitive)
```yaml
REDIS_HOST: redis                                    # Redis service hostname
REDIS_PORT: "6379"                                  # Redis port
SPRING_DATA_REDIS_HOST: redis
SPRING_DATA_REDIS_PORT: "6379"
```

#### Secrets (Sensitive)
```yaml
REDIS_PASSWORD: <from-aws-secrets-manager>           # Redis password (if auth enabled)
SPRING_DATA_REDIS_PASSWORD: <from-aws-secrets-manager>
```

---

### 5. Service-to-Service Authentication (OAuth2)

#### ConfigMap (Non-Sensitive)
```yaml
AUTH_SERVER_URL: http://auth:8081                    # Auth service URL
SPRING_SECURITY_OAUTH2_CLIENT_PROVIDER_MY_AUTH_SERVER_ISSUER_URI: http://auth:8081
```

#### Secrets (Sensitive)
```yaml
<SERVICE>_CLIENT_ID: <from-aws-secrets-manager>      # OAuth2 client ID
<SERVICE>_CLIENT_SECRET: <from-aws-secrets-manager>  # OAuth2 client secret
<SERVICE>_JWT_SECRET: <from-aws-secrets-manager>     # JWT signing secret
```

---

### 6. Service-Specific Configuration

#### Simulation Service
**ConfigMap:**
```yaml
SPRING_APPLICATION_NAME: simulation
SERVER_PORT: "8090"
API_GATEWAY_URL: http://apigateway:8080
PORTFOLIO_SERVICE_URL: http://apigateway:8080/simulation
```

**Secrets:**
```yaml
SIMULATION_DB_PASSWORD: <from-aws-secrets-manager>
SIMULATION_API_KEY: <from-aws-secrets-manager>
SIMULATION_JWT_SECRET: <from-aws-secrets-manager>
SIMULATION_CLIENT_ID: <from-aws-secrets-manager>
SIMULATION_CLIENT_SECRET: <from-aws-secrets-manager>
```

#### Auth Service
**ConfigMap:**
```yaml
SPRING_APPLICATION_NAME: auth
SERVER_PORT: "8081"
```

**Secrets:**
```yaml
AUTH_DB_PASSWORD: <from-aws-secrets-manager>
AUTH_JWT_SECRET: <from-aws-secrets-manager>
AUTH_ADMIN_PASSWORD: <from-aws-secrets-manager>
```

#### Trade Capture Service
**ConfigMap:**
```yaml
SPRING_APPLICATION_NAME: trade-capture
SERVER_PORT: "8082"
```

**Secrets:**
```yaml
TRADE_CAPTURE_DB_PASSWORD: <from-aws-secrets-manager>
TRADE_CAPTURE_API_KEY: <from-aws-secrets-manager>
TRADE_CAPTURE_JWT_SECRET: <from-aws-secrets-manager>
```

#### Validation Service
**ConfigMap:**
```yaml
SPRING_APPLICATION_NAME: validation
SERVER_PORT: "8080"
```

**Secrets:**
```yaml
VALIDATION_DB_PASSWORD: <from-aws-secrets-manager>
VALIDATION_API_KEY: <from-aws-secrets-manager>
VALIDATION_JWT_SECRET: <from-aws-secrets-manager>
```

#### API Gateway
**ConfigMap:**
```yaml
SPRING_APPLICATION_NAME: apigateway
SERVER_PORT: "8080"
```

**Secrets:**
```yaml
GATEWAY_JWT_SECRET: <from-aws-secrets-manager>
```

---

## Environment Variables to REMOVE/DEPRECATE

### ❌ Deprecated Variables (Do NOT use)

1. **Old RabbitMQ naming**:
   - `APP_RABBIT_STREAM_USERNAME` → Use `app.rabbitmq.stream.username` in application.yaml
   - `APP_RABBIT_STREAM_PASSWORD` → Use `app.rabbitmq.stream.password` in application.yaml

2. **Inconsistent database vars**:
   - `SIMULATION_DB_PASSWORD` → Should map to `SPRING_DATASOURCE_PASSWORD`
   - Use consistent `DB_*` or `SPRING_DATASOURCE_*` prefix

3. **Hardcoded values in application.yaml**:
   - Remove any default values like `guest`, `admin`, `password`
   - Always reference environment variables

---

## Migration Checklist for Teams

### For Each Service:

- [ ] Review `application.yaml` and remove hardcoded credentials
- [ ] Update `@Value` annotations to use consistent property paths
- [ ] Ensure all properties use `${ENV_VAR:defaultValue}` syntax
- [ ] Map Spring properties correctly:
  - `app.rabbitmq.stream.username` (not `APP_RABBIT_STREAM_USERNAME`)
  - `spring.datasource.password` (not custom vars)
- [ ] Add all secrets to AWS Secrets Manager under `pms/<env>/<service>`
- [ ] Update Helm chart `values.yaml` with standardized names
- [ ] Test with environment variables set correctly
- [ ] Remove unused environment variables
- [ ] Document any service-specific variables

---

## AWS Secrets Manager Structure

### Path Convention
```
pms/<environment>/<service>
```

### Examples
```
pms/dev/simulation
pms/dev/auth
pms/dev/trade-capture
pms/dev/validation
pms/dev/rabbitmq
pms/dev/postgres
pms/dev/redis
```

### Shared Infrastructure Secrets
```
pms/dev/rabbitmq:
  - RABBITMQ_DEFAULT_USER: rabbit-user
  - RABBITMQ_DEFAULT_PASS: <secure-password>
  - SPRING_RABBITMQ_USERNAME: rabbit-user
  - SPRING_RABBITMQ_PASSWORD: <secure-password>

pms/dev/postgres:
  - DB_USER: pms
  - DB_PASSWORD: <secure-password>
```

---

## Best Practices

1. **Never use default credentials** in production
2. **Rotate secrets regularly** via AWS Secrets Manager
3. **Use least privilege** - only grant access to needed secrets
4. **Validate environment variables** on application startup
5. **Log configuration (without secrets)** for debugging
6. **Use consistent naming** across all services
7. **Document exceptions** if service needs custom variables
8. **Test in dev** before promoting to prod

---

## Troubleshooting

### Common Issues

1. **Authentication Failures**
   - Check environment variable names match application.yaml
   - Verify AWS Secrets Manager has correct values
   - Check ExternalSecret is syncing (check Secret resource)
   - Ensure Spring property mapping is correct

2. **Stream/Queue Conflicts**
   - Delete existing streams/queues when changing configuration
   - Use consistent stream names across services
   - Check RabbitMQ management UI for existing resources

3. **Image Not Updating**
   - Set `imagePullPolicy: Always` for development
   - Use specific tags (not `latest`) for production
   - Verify Docker image was pushed to registry

---

## References

- Spring Boot External Configuration: https://docs.spring.io/spring-boot/reference/features/external-config.html
- RabbitMQ Streams: https://www.rabbitmq.com/docs/streams
- AWS Secrets Manager: https://docs.aws.amazon.com/secretsmanager/
- External Secrets Operator: https://external-secrets.io/

