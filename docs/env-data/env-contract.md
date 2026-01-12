# PMS Platform Environment Contract

**Version:** 1.0
**Date:** January 12, 2026
**Status:** ✅ **AUTHORITY - Single Source of Truth**

This document defines the **complete, authoritative environment contract** for the PMS (Portfolio Management System) platform. Every environment variable used anywhere in the system is documented here with its canonical name, classification, ownership, and usage.

---

## 📋 Contract Rules

### Naming Convention
- **UPPER_CASE** with underscores for all environment variables
- **No prefixes** (no `SPRING_`, `APP_`, etc.) unless required by framework
- **Descriptive names** that clearly indicate purpose
- **Consistent across all services**

### Classification System

| Category | Definition | Storage | Access Pattern |
|----------|------------|---------|----------------|
| `GLOBAL_CONFIG` | Non-secret values shared across multiple services | ConfigMap | `global.config.*` |
| `SERVICE_CONFIG` | Non-secret values unique to one service | ConfigMap | `service.config.*` |
| `GLOBAL_SECRET` | Secrets shared across services | AWS Secrets Manager | `global.secrets.*` |
| `SERVICE_SECRET` | Secrets unique to one service | AWS Secrets Manager | `service.secrets.*` |
| `IMAGE_DEFAULT` | Values baked into container images | Dockerfile | N/A |

### Ownership
- **Platform Team**: `GLOBAL_CONFIG`, `GLOBAL_SECRET`
- **Service Team**: `SERVICE_CONFIG`, `SERVICE_SECRET`
- **DevOps Team**: Infrastructure values in umbrella chart
- **Container Team**: `IMAGE_DEFAULT`

---

## 🌐 GLOBAL_CONFIG

Shared non-secret configuration used across multiple services.

| Variable | Description | Example Value | Used By | Source |
|----------|-------------|---------------|---------|--------|
| `DB_HOST` | PostgreSQL service hostname | `postgres` | auth, simulation, trade-capture, validation | Platform ConfigMap |
| `DB_PORT` | PostgreSQL service port | `5432` | auth, simulation, trade-capture, validation | Platform ConfigMap |
| `DB_NAME` | PostgreSQL database name | `pmsdb` | auth, simulation, trade-capture, validation | Platform ConfigMap |
| `DB_DRIVER` | PostgreSQL JDBC driver class | `org.postgresql.Driver` | auth, simulation, trade-capture, validation | Platform ConfigMap |
| `DB_DIALECT` | Hibernate PostgreSQL dialect | `org.hibernate.dialect.PostgreSQLDialect` | auth, simulation, trade-capture, validation | Platform ConfigMap |
| `DB_DDL_AUTO` | Hibernate DDL auto strategy | `update` | auth, simulation, trade-capture, validation | Platform ConfigMap |
| `DB_SHOW_SQL` | Enable SQL logging | `false` | auth, simulation, trade-capture, validation | Platform ConfigMap |
| `DB_FORMAT_SQL` | Format SQL output | `true` | auth, simulation, trade-capture, validation | Platform ConfigMap |
| `JPA_OPEN_IN_VIEW` | JPA open-in-view setting | `false` | trade-capture | Platform ConfigMap |
| `REDIS_HOST` | Redis service hostname | `redis` | apigateway, validation | Platform ConfigMap |
| `REDIS_PORT` | Redis service port | `6379` | apigateway, validation | Platform ConfigMap |
| `REDIS_TIMEOUT` | Redis connection timeout | `2s` | validation | Platform ConfigMap |
| `CACHE_TYPE` | Cache implementation type | `redis` | validation | Platform ConfigMap |
| `RABBITMQ_HOST` | RabbitMQ service hostname | `rabbitmq` | simulation, trade-capture, validation | Platform ConfigMap |
| `RABBITMQ_PORT` | RabbitMQ management port | `5672` | trade-capture | Platform ConfigMap |
| `RABBITMQ_STREAM_PORT` | RabbitMQ stream port | `5552` | simulation, trade-capture, validation | Platform ConfigMap |
| `RABBITMQ_STREAM_NAME` | RabbitMQ stream name | `trade-stream` | simulation, trade-capture, validation | Platform ConfigMap |
| `KAFKA_BOOTSTRAP_SERVERS` | Kafka broker endpoints | `kafka:9092` | simulation, trade-capture, validation | Platform ConfigMap |
| `SCHEMA_REGISTRY_URL` | Schema Registry endpoint | `http://schema-registry:8081` | simulation, trade-capture, validation | Platform ConfigMap |
| `KAFKA_KEY_SERIALIZER` | Kafka key serializer | `org.apache.kafka.common.serialization.StringSerializer` | trade-capture | Platform ConfigMap |
| `KAFKA_VALUE_SERIALIZER` | Kafka value serializer | `io.confluent.kafka.serializers.protobuf.KafkaProtobufSerializer` | trade-capture | Platform ConfigMap |
| `KAFKA_AUTO_REGISTER_SCHEMAS` | Auto-register Kafka schemas | `true` | trade-capture | Platform ConfigMap |
| `AUTH_SERVICE_HOST` | Auth service hostname | `auth` | apigateway | Platform ConfigMap |
| `AUTH_SERVICE_PORT` | Auth service port | `8081` | apigateway | Platform ConfigMap |
| `SIMULATION_SERVICE_HOST` | Simulation service hostname | `pms-simulation` | apigateway | Platform ConfigMap |
| `SIMULATION_SERVICE_PORT` | Simulation service port | `8090` | apigateway | Platform ConfigMap |
| `TRADE_CAPTURE_SERVICE_HOST` | Trade Capture service hostname | `trade-capture` | validation | Platform ConfigMap |
| `TRADE_CAPTURE_SERVICE_PORT` | Trade Capture service port | `8082` | validation | Platform ConfigMap |
| `VALIDATION_SERVICE_HOST` | Validation service hostname | `validation-service` | apigateway | Platform ConfigMap |
| `VALIDATION_SERVICE_PORT` | Validation service port | `8080` | apigateway | Platform ConfigMap |
| `INCOMING_TRADES_TOPIC` | Kafka topic for incoming trades | `raw-trades-topic` | validation | Platform ConfigMap |
| `OUTGOING_VALID_TRADES_TOPIC` | Kafka topic for valid trades | `valid-trades-topic` | validation | Platform ConfigMap |
| `OUTGOING_INVALID_TRADES_TOPIC` | Kafka topic for invalid trades | `invalid-trades-topic` | validation | Platform ConfigMap |

---

## 🔧 SERVICE_CONFIG

Service-specific non-secret configuration.

| Variable | Description | Example Value | Service | Source |
|----------|-------------|---------------|---------|--------|
| `GATEWAY_CONNECT_TIMEOUT` | Gateway HTTP connect timeout | `3000` | apigateway | Service ConfigMap |
| `GATEWAY_RESPONSE_TIMEOUT` | Gateway HTTP response timeout | `10s` | apigateway | Service ConfigMap |
| `GATEWAY_CORS_ORIGINS` | CORS allowed origins | `*` | apigateway | Service ConfigMap |
| `GATEWAY_CORS_CREDENTIALS` | CORS allow credentials | `false` | apigateway | Service ConfigMap |
| `TRADE_CAPTURE_POOL_SIZE` | Database connection pool size | `20` | trade-capture | Service ConfigMap |
| `TRADE_CAPTURE_BATCH_SIZE` | Batch processing size | `500` | trade-capture | Service ConfigMap |
| `TRADE_CAPTURE_BATCH_TIMEOUT_MS` | Batch timeout in milliseconds | `100` | trade-capture | Service ConfigMap |
| `TRADE_CAPTURE_CONSUMER_GROUP` | Kafka consumer group | `trade-capture-group` | trade-capture | Service ConfigMap |
| `VALIDATION_CONSUMER_GROUP` | Kafka consumer group | `validation-consumer-group` | validation | Service ConfigMap |

---

## 🔐 GLOBAL_SECRET

Shared secrets used across multiple services.

| Variable | Description | AWS Key Path | Used By | Source |
|----------|-------------|--------------|---------|--------|
| `DB_PASSWORD` | PostgreSQL database password | `pms/dev/database:POSTGRES_PASSWORD` | auth, simulation, trade-capture, validation | AWS Secrets Manager |
| `RABBITMQ_USERNAME` | RabbitMQ username | `pms/dev/rabbitmq:RABBITMQ_DEFAULT_USER` | simulation, trade-capture, validation | AWS Secrets Manager |
| `RABBITMQ_PASSWORD` | RabbitMQ password | `pms/dev/rabbitmq:RABBITMQ_DEFAULT_PASS` | simulation, trade-capture, validation | AWS Secrets Manager |
| `KAFKA_ADMIN_PASSWORD` | Kafka admin password | `pms/dev/kafka:KAFKA_ADMIN_PASSWORD` | infrastructure | AWS Secrets Manager |
| `KAFKA_USER_PASSWORD` | Kafka user password | `pms/dev/kafka:KAFKA_USER_PASSWORD` | infrastructure | AWS Secrets Manager |
| `REDIS_PASSWORD` | Redis password | `pms/dev/redis:REDIS_PASSWORD` | apigateway, validation | AWS Secrets Manager |
| `SCHEMA_REGISTRY_API_KEY` | Schema Registry API key | `pms/dev/schema-registry:SCHEMA_REGISTRY_API_KEY` | infrastructure | AWS Secrets Manager |
| `SCHEMA_REGISTRY_API_SECRET` | Schema Registry API secret | `pms/dev/schema-registry:SCHEMA_REGISTRY_API_SECRET` | infrastructure | AWS Secrets Manager |

---


## 🐳 IMAGE_DEFAULT

Values baked into container images (Spring Boot defaults).

| Variable | Description | Default Value | Services | Source |
|----------|-------------|---------------|----------|--------|
| `SERVER_PORT` | Application server port | `8080` | all services | Dockerfile/SPRING |
| `SPRING_PROFILES_ACTIVE` | Spring active profile | `docker` | trade-capture | Dockerfile |

---

## 🔄 Migration Guide

### Phase 1: Global Config Consolidation
1. Move all `GLOBAL_CONFIG` variables to `pms-platform/values.yaml` under `global.config`
2. Remove duplicated config from all service `values.yaml` files
3. Update service templates to reference `{{ .Values.global.config.DB_HOST }}`

### Phase 2: Secret Standardization
1. Update AWS Secrets Manager paths to match canonical names
2. Modify ExternalSecret resources to use standardized variable names
3. Update service templates to reference standardized secret names

### Phase 3: Service Config Cleanup
1. Move `SERVICE_CONFIG` variables to appropriate service `values.yaml` under `service.config`
2. Remove global config duplicates from service charts
3. Update service templates to use `{{ .Values.service.config.* }}`

### Phase 4: Template Standardization
1. Standardize all Helm templates to use the same variable reference patterns
2. Remove custom logic and use consistent config/secret access
3. Validate all services use the contract correctly

---

## ✅ Validation Checklist

- [ ] All services use only variables defined in this contract
- [ ] No variable is defined in more than one location
- [ ] AWS Secrets Manager paths match contract exactly
- [ ] Helm templates use consistent reference patterns
- [ ] No service invents new variable names
- [ ] All global config lives in umbrella chart
- [ ] All service config lives in service charts
- [ ] ExternalSecrets align 1:1 with contract

---
