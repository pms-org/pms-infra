# Standard Environment Variables Reference

## Quick Reference Guide

This is the authoritative list of environment variables for all PMS services.

## Infrastructure Services

### PostgreSQL
```yaml
ConfigMap:
  DB_HOST: postgres
  DB_PORT: "5432"
  DB_NAME: pmsdb
  SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/pmsdb
  SPRING_DATASOURCE_DRIVER_CLASS_NAME: org.postgresql.Driver

Secrets (from AWS SM):
  SPRING_DATASOURCE_USERNAME
  SPRING_DATASOURCE_PASSWORD
```

### RabbitMQ
```yaml
ConfigMap:
  RABBITMQ_HOST: rabbitmq
  RABBITMQ_STREAM_PORT: "5552"
  RABBITMQ_STREAM_NAME: trade-stream
  SPRING_RABBITMQ_HOST: rabbitmq
  SPRING_RABBITMQ_PORT: "5552"

Secrets (from AWS SM):
  SPRING_RABBITMQ_USERNAME
  SPRING_RABBITMQ_PASSWORD
  SPRING_RABBITMQ_STREAM_USERNAME
  SPRING_RABBITMQ_STREAM_PASSWORD
```

### Kafka
```yaml
ConfigMap:
  KAFKA_BOOTSTRAP_SERVERS: kafka:9092
  SPRING_KAFKA_BOOTSTRAP_SERVERS: kafka:9092
  SCHEMA_REGISTRY_URL: http://schema-registry:8081
  SPRING_KAFKA_PROPERTIES_SCHEMA_REGISTRY_URL: http://schema-registry:8081
```

### Redis
```yaml
ConfigMap:
  REDIS_HOST: redis
  REDIS_PORT: "6379"
  SPRING_DATA_REDIS_HOST: redis
  SPRING_DATA_REDIS_PORT: "6379"
```

## Application Services

### Simulation
```yaml
ConfigMap:
  SERVER_PORT: "8090"
  SPRING_APPLICATION_NAME: simulation

Secrets:
  SIMULATION_DB_PASSWORD
  SIMULATION_API_KEY
  SIMULATION_JWT_SECRET
  SPRING_RABBITMQ_USERNAME
  SPRING_RABBITMQ_PASSWORD
```

### Auth
```yaml
ConfigMap:
  SERVER_PORT: "8081"
  SPRING_APPLICATION_NAME: auth

Secrets:
  AUTH_DB_PASSWORD
  AUTH_JWT_SECRET
  SPRING_RABBITMQ_USERNAME
  SPRING_RABBITMQ_PASSWORD
```

### Trade Capture
```yaml
ConfigMap:
  SERVER_PORT: "8082"
  SPRING_APPLICATION_NAME: trade-capture

Secrets:
  TRADE_CAPTURE_DB_PASSWORD
  TRADE_CAPTURE_API_KEY
  SPRING_RABBITMQ_USERNAME
  SPRING_RABBITMQ_PASSWORD
```

### Validation
```yaml
ConfigMap:
  SERVER_PORT: "8080"
  SPRING_APPLICATION_NAME: validation

Secrets:
  VALIDATION_DB_PASSWORD
  VALIDATION_API_KEY
  SPRING_RABBITMQ_USERNAME
  SPRING_RABBITMQ_PASSWORD
```

### API Gateway
```yaml
ConfigMap:
  SERVER_PORT: "8080"
  SPRING_APPLICATION_NAME: apigateway

Secrets:
  GATEWAY_JWT_SECRET
```

## ❌ DO NOT USE

- `APP_RABBIT_STREAM_USERNAME`
- `APP_RABBIT_STREAM_PASSWORD`
- `RABBITMQ_USERNAME`
- `RABBITMQ_PASSWORD`
- Any hardcoded `guest`, `admin`, `password` values

## Spring Property Mapping

Environment variables automatically map to Spring properties:

```
SPRING_RABBITMQ_STREAM_USERNAME → spring.rabbitmq.stream.username
APP_RABBITMQ_STREAM_PROPERTY → app.rabbitmq.stream.property
```

In application.yaml, use the property path:
```yaml
app:
  rabbitmq:
    stream:
      username: ${app.rabbitmq.stream.username}  # NOT ${APP_RABBITMQ_STREAM_USERNAME}
```

In Java @Value annotations, use the property path:
```java
@Value("${app.rabbitmq.stream.username}")  // NOT ${APP_RABBITMQ_STREAM_USERNAME}
```
