# Configuration Hardening Checklist

## Immediate Actions Completed ✅

1. ✅ Fixed RabbitMQ authentication in simulation service
2. ✅ Updated Java code to use Spring property paths
3. ✅ Set `imagePullPolicy: Always` for development
4. ✅ Standardized secret mappings in Helm charts

## Required Team Actions

### All Development Teams Must:

1. **Update Java/Spring Code**
   ```java
   // ❌ WRONG
   @Value("${APP_RABBIT_STREAM_USERNAME:guest}")
   
   // ✅ CORRECT
   @Value("${app.rabbitmq.stream.username}")
   ```

2. **Update application.yaml**
   ```yaml
   # ❌ WRONG
   username: ${APP_RABBIT_STREAM_USERNAME:guest}
   
   # ✅ CORRECT  
   username: ${app.rabbitmq.stream.username}
   ```

3. **Remove ALL hardcoded credentials**
   - No `guest`, `admin`, `password`, `secret` in code
   - No default credentials in application.yaml
   - All secrets from AWS Secrets Manager

## Standard Environment Variable Names

### Database
- `DB_HOST`, `DB_PORT`, `DB_NAME`
- `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`

### RabbitMQ
- `RABBITMQ_HOST`, `RABBITMQ_STREAM_PORT`, `RABBITMQ_STREAM_NAME`
- `SPRING_RABBITMQ_USERNAME`, `SPRING_RABBITMQ_PASSWORD`
- `SPRING_RABBITMQ_STREAM_USERNAME`, `SPRING_RABBITMQ_STREAM_PASSWORD`

### Kafka
- `KAFKA_BOOTSTRAP_SERVERS`, `SCHEMA_REGISTRY_URL`
- `SPRING_KAFKA_BOOTSTRAP_SERVERS`, `SPRING_KAFKA_PROPERTIES_SCHEMA_REGISTRY_URL`

### Redis
- `REDIS_HOST`, `REDIS_PORT`
- `SPRING_DATA_REDIS_HOST`, `SPRING_DATA_REDIS_PORT`

## Variables to REMOVE

### ❌ Deprecated (Do Not Use)
1. `APP_RABBIT_STREAM_USERNAME` → Use Spring property mapping
2. `APP_RABBIT_STREAM_PASSWORD` → Use Spring property mapping
3. `RABBITMQ_USERNAME` → Use `SPRING_RABBITMQ_USERNAME`
4. `RABBITMQ_PASSWORD` → Use `SPRING_RABBITMQ_PASSWORD`

### ✅ Standard Names to Use
1. `SPRING_RABBITMQ_STREAM_USERNAME`
2. `SPRING_RABBITMQ_STREAM_PASSWORD`
3. `SPRING_DATASOURCE_USERNAME`
4. `SPRING_DATASOURCE_PASSWORD`

## AWS Secrets Manager Structure

```
pms/
├── dev/
│   ├── rabbitmq
│   │   ├── SPRING_RABBITMQ_USERNAME
│   │   └── SPRING_RABBITMQ_PASSWORD
│   ├── postgres
│   │   ├── DB_USER
│   │   └── DB_PASSWORD
│   ├── simulation
│   │   ├── SIMULATION_DB_PASSWORD
│   │   ├── SIMULATION_API_KEY
│   │   ├── SIMULATION_JWT_SECRET
│   │   ├── SPRING_RABBITMQ_USERNAME
│   │   └── SPRING_RABBITMQ_PASSWORD
│   ├── auth
│   ├── trade-capture
│   └── validation
├── staging/
└── prod/
```

## Testing Checklist

- [ ] Delete namespace: `kubectl delete namespace pms`
- [ ] Deploy umbrella chart: `helm install pms-platform . -n pms --create-namespace`
- [ ] Verify all pods running: `kubectl get pods -n pms`
- [ ] Check logs for auth errors: `kubectl logs -n pms -l app=<service>`
- [ ] Verify RabbitMQ connections: `kubectl exec -n pms deployment/rabbitmq -- rabbitmqctl list_connections`
- [ ] Test service endpoints

## For Questions/Support

Contact: Platform Team
Documentation: `/docs/ENVIRONMENT_VARIABLES_STANDARD.md`
