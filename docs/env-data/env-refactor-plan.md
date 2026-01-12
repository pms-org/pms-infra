# PMS Environment Standardization - Refactor Plan

**Version:** 1.0
**Date:** January 12, 2026
**Status:** 🚧 **READY FOR EXECUTION**

This plan outlines the step-by-step process to implement the standardized environment contract across the entire PMS platform.

---

## 🎯 Objectives

1. **Single Source of Truth**: One authoritative environment contract
2. **Eliminate Duplication**: No variable defined in multiple places
3. **Standardize Naming**: Consistent UPPER_CASE with clear semantics
4. **Proper Classification**: GLOBAL_CONFIG, SERVICE_CONFIG, GLOBAL_SECRET, SERVICE_SECRET, IMAGE_DEFAULT
5. **Clean Ownership**: Platform vs Service team responsibilities clearly defined

---

## 📊 Current State Analysis

### Issues Identified
- **47 unique environment variables** discovered across 5 services
- **~60% duplication** with different names for same concepts
- **Inconsistent naming**: `SPRING_*`, `APP_*`, bare names mixed
- **Wrong classification**: Config values stored as secrets
- **Scattered definitions**: Same values in every service chart

### Impact
- **New engineers**: 2-3 days to understand config system
- **Onboarding**: Confusion about what values to use where
- **Maintenance**: Changes require updates in multiple places
- **Debugging**: Hard to trace variable origins

---

## 🔄 Implementation Phases

### Phase 1: Foundation (Week 1) - Global Config Consolidation

#### 1.1 Update Umbrella Chart Structure
**File:** `k8s/pms-platform/values.yaml`

**Add global config section:**
```yaml
global:
  config:
    # Database
    DB_HOST: postgres
    DB_PORT: "5432"
    DB_NAME: pmsdb
    DB_DRIVER: org.postgresql.Driver
    DB_DIALECT: org.hibernate.dialect.PostgreSQLDialect
    DB_DDL_AUTO: update
    DB_SHOW_SQL: "false"
    DB_FORMAT_SQL: "true"
    JPA_OPEN_IN_VIEW: "false"

    # Redis
    REDIS_HOST: redis
    REDIS_PORT: "6379"
    REDIS_TIMEOUT: 2s
    CACHE_TYPE: redis

    # RabbitMQ
    RABBITMQ_HOST: rabbitmq
    RABBITMQ_PORT: "5672"
    RABBITMQ_STREAM_PORT: "5552"
    RABBITMQ_STREAM_NAME: trade-stream

    # Kafka
    KAFKA_BOOTSTRAP_SERVERS: kafka:9092
    SCHEMA_REGISTRY_URL: http://schema-registry:8081
    KAFKA_KEY_SERIALIZER: org.apache.kafka.common.serialization.StringSerializer
    KAFKA_VALUE_SERIALIZER: io.confluent.kafka.serializers.protobuf.KafkaProtobufSerializer
    KAFKA_AUTO_REGISTER_SCHEMAS: "true"

    # Service Discovery
    AUTH_SERVICE_HOST: auth
    AUTH_SERVICE_PORT: "8081"
    SIMULATION_SERVICE_HOST: pms-simulation
    SIMULATION_SERVICE_PORT: "8090"
    TRADE_CAPTURE_SERVICE_HOST: trade-capture
    TRADE_CAPTURE_SERVICE_PORT: "8082"
    VALIDATION_SERVICE_HOST: validation-service
    VALIDATION_SERVICE_PORT: "8080"

    # Topics
    INCOMING_TRADES_TOPIC: raw-trades-topic
    OUTGOING_VALID_TRADES_TOPIC: valid-trades-topic
    OUTGOING_INVALID_TRADES_TOPIC: invalid-trades-topic
```

#### 1.2 Create Global ConfigMap Template
**File:** `k8s/pms-platform/templates/global-configmap.yaml` (NEW)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: pms-global-config
  namespace: pms
data:
  {{- range $key, $value := .Values.global.config }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
```

#### 1.3 Update Service Charts - Remove Global Duplicates

**For each service (`apigateway`, `auth`, `simulation`, `trade-capture`, `validation`):**

**Remove from `values.yaml`:**
```yaml
# REMOVE these duplicated global configs:
DB_HOST: postgres
DB_NAME: pmsdb
SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/pmsdb
SPRING_RABBITMQ_HOST: rabbitmq
RABBITMQ_HOST: rabbitmq
KAFKA_BOOTSTRAP_SERVERS: kafka:9092
# ... etc
```

**Keep only service-specific config:**
```yaml
service:
  config:
    # Gateway specific
    GATEWAY_CONNECT_TIMEOUT: "3000"
    GATEWAY_RESPONSE_TIMEOUT: "10s"
    GATEWAY_CORS_ORIGINS: "*"
    GATEWAY_CORS_CREDENTIALS: "false"
```

#### 1.4 Update Service Templates

**Modify all deployment templates to use global config:**

```yaml
env:
  # Global config from umbrella
  - name: DB_HOST
    valueFrom:
      configMapKeyRef:
        name: pms-global-config
        key: DB_HOST
  - name: DB_PORT
    valueFrom:
      configMapKeyRef:
        name: pms-global-config
        key: DB_PORT

  # Service config (if any)
  - name: GATEWAY_CONNECT_TIMEOUT
    valueFrom:
      configMapKeyRef:
        name: {{ include "apigateway.fullname" . }}-config
        key: GATEWAY_CONNECT_TIMEOUT
```

### Phase 2: Secret Standardization (Week 2)

#### 2.1 Update AWS Secrets Manager Structure

**Current Structure → Canonical Structure:**

```
pms/dev/database (KEEP AS-IS)
├── POSTGRES_PASSWORD → DB_PASSWORD

pms/dev/rabbitmq (RENAME PROPERTIES)
├── RABBITMQ_DEFAULT_USER → RABBITMQ_USERNAME
├── RABBITMQ_DEFAULT_PASS → RABBITMQ_PASSWORD

pms/dev/kafka (KEEP AS-IS)
├── KAFKA_ADMIN_PASSWORD
├── KAFKA_USER_PASSWORD

pms/dev/redis (KEEP AS-IS)
├── REDIS_PASSWORD

pms/dev/schema-registry (KEEP AS-IS)
├── SCHEMA_REGISTRY_API_KEY
├── SCHEMA_REGISTRY_API_SECRET

pms/dev/auth (RENAME PROPERTIES)
├── DATASOURCE_USER → AUTH_DB_USER
├── DATASOURCE_PASS → AUTH_DB_PASSWORD
├── JWT_SECRET → AUTH_JWT_SECRET

pms/dev/simulation (RENAME PROPERTIES)
├── SIMULATION_DB_PASSWORD → (REMOVE - use DB_PASSWORD)
├── SIMULATION_API_KEY → SIMULATION_API_KEY
├── SIMULATION_JWT_SECRET → SIMULATION_JWT_SECRET
├── SPRING_RABBITMQ_USERNAME → (REMOVE - use RABBITMQ_USERNAME)
├── SPRING_RABBITMQ_PASSWORD → (REMOVE - use RABBITMQ_PASSWORD)

pms/dev/trade-capture (RENAME PROPERTIES)
├── TRADE_CAPTURE_DB_PASSWORD → (REMOVE - use DB_PASSWORD)
├── TRADE_CAPTURE_API_KEY → TRADE_CAPTURE_API_KEY
├── TRADE_CAPTURE_JWT_SECRET → TRADE_CAPTURE_JWT_SECRET
├── SPRING_RABBITMQ_USERNAME → (REMOVE - use RABBITMQ_USERNAME)
├── SPRING_RABBITMQ_PASSWORD → (REMOVE - use RABBITMQ_PASSWORD)

pms/dev/validation (RENAME PROPERTIES)
├── VALIDATION_DB_PASSWORD → (REMOVE - use DB_PASSWORD)
├── VALIDATION_API_KEY → VALIDATION_API_KEY
├── VALIDATION_JWT_SECRET → VALIDATION_JWT_SECRET
├── SPRING_RABBITMQ_USERNAME → (REMOVE - use RABBITMQ_USERNAME)
├── SPRING_RABBITMQ_PASSWORD → (REMOVE - use RABBITMQ_PASSWORD)
```

#### 2.2 Update ExternalSecret Resources

**Example for auth service:**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: auth-secrets
spec:
  data:
  - secretKey: AUTH_DB_USER
    remoteRef:
      key: pms/dev/auth
      property: AUTH_DB_USER  # Updated property name
  - secretKey: AUTH_DB_PASSWORD
    remoteRef:
      key: pms/dev/auth
      property: AUTH_DB_PASSWORD
  - secretKey: AUTH_JWT_SECRET
    remoteRef:
      key: pms/dev/auth
      property: AUTH_JWT_SECRET
```

#### 2.3 Create Global Secrets ExternalSecret

**File:** `k8s/pms-platform/templates/global-secrets.yaml` (NEW)

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: pms-global-secrets
spec:
  data:
  - secretKey: DB_PASSWORD
    remoteRef:
      key: pms/dev/database
      property: POSTGRES_PASSWORD
  - secretKey: RABBITMQ_USERNAME
    remoteRef:
      key: pms/dev/rabbitmq
      property: RABBITMQ_DEFAULT_USER
  - secretKey: RABBITMQ_PASSWORD
    remoteRef:
      key: pms/dev/rabbitmq
      property: RABBITMQ_DEFAULT_PASS
  - secretKey: REDIS_PASSWORD
    remoteRef:
      key: pms/dev/redis
      property: REDIS_PASSWORD
```

### Phase 3: Service-Specific Updates (Week 3)

#### 3.1 Update Each Service Chart

**For each service, update `values.yaml`:**
```yaml
# Service-specific config
service:
  config:
    # Service-specific non-secret values
    TRADE_CAPTURE_POOL_SIZE: "20"
    TRADE_CAPTURE_BATCH_SIZE: "500"

# Service-specific secrets (ExternalSecret data mappings)
service:
  secrets:
    data:
    - secretKey: TRADE_CAPTURE_API_KEY
      remoteRef:
        key: pms/dev/trade-capture
        property: TRADE_CAPTURE_API_KEY
```

#### 3.2 Update Service Templates

**Standardize environment variable injection:**

```yaml
env:
  # Global config
  {{- range $key, $value := .Values.global.config }}
  - name: {{ $key }}
    value: {{ $value | quote }}
  {{- end }}

  # Service config
  {{- range $key, $value := .Values.service.config }}
  - name: {{ $key }}
    value: {{ $value | quote }}
  {{- end }}

  # Global secrets
  {{- range $secret := .Values.global.secrets.data }}
  - name: {{ $secret.secretKey }}
    valueFrom:
      secretKeyRef:
        name: pms-global-secrets
        key: {{ $secret.secretKey }}
  {{- end }}

  # Service secrets
  {{- range $secret := .Values.service.secrets.data }}
  - name: {{ $secret.secretKey }}
    valueFrom:
      secretKeyRef:
        name: {{ include "servicename.fullname" . }}-secrets
        key: {{ $secret.secretKey }}
  {{- end }}
```

### Phase 4: Validation & Testing (Week 4)

#### 4.1 Update CI/CD Pipelines
- Add environment contract validation to CI
- Test all services with new config structure
- Validate ExternalSecret synchronization

#### 4.2 Documentation Updates
- Update all README files to reference env-contract.md
- Create migration guide for service teams
- Update onboarding documentation

#### 4.3 Rollback Plan
- Keep old config structure as backup
- Gradual rollout with feature flags
- Monitoring and alerting for config issues

---

## 📋 Detailed Task Breakdown

### Week 1 Tasks
- [ ] Update `pms-platform/values.yaml` with global config section
- [ ] Create `global-configmap.yaml` template
- [ ] Remove global config duplicates from `apigateway/values.yaml`
- [ ] Update apigateway templates to use global config
- [ ] Test apigateway with new config structure

### Week 2 Tasks
- [ ] Update AWS Secrets Manager property names
- [ ] Create global secrets ExternalSecret
- [ ] Update auth service ExternalSecret mappings
- [ ] Update auth service templates
- [ ] Test auth service with new secret structure

### Week 3 Tasks
- [ ] Update simulation service configuration
- [ ] Update trade-capture service configuration
- [ ] Update validation service configuration
- [ ] Standardize all Helm template patterns
- [ ] Update CI/CD validation scripts

### Week 4 Tasks
- [ ] Full platform testing
- [ ] Documentation updates
- [ ] Team training and onboarding
- [ ] Go-live and monitoring

---

## 🔍 Validation Criteria

### Pre-Implementation
- [ ] All variables classified in env-contract.md
- [ ] AWS Secrets Manager updated with canonical names
- [ ] Helm templates updated for new structure

### Post-Implementation
- [ ] All services start successfully
- [ ] ExternalSecrets sync without errors
- [ ] No environment variable conflicts
- [ ] All functionality works as expected
- [ ] New engineer can onboard in < 1 hour

---

## 🚨 Risk Mitigation

### Rollback Strategy
1. Keep old config structure in separate branch
2. Use feature flags for gradual rollout
3. Monitor service health during transition
4. Have backup deployment configs ready

### Testing Strategy
1. Unit tests for config parsing
2. Integration tests for service communication
3. End-to-end tests for complete workflows
4. Performance tests for config loading

### Communication Plan
1. Notify all service teams of changes
2. Provide migration guide and support
3. Schedule office hours for questions
4. Create Slack channel for config discussions

---

## 📈 Success Metrics

- **Time to onboard**: New engineers understand config in < 1 hour
- **Change frequency**: Config changes require updates in 1 place only
- **Error rate**: 0 config-related production incidents
- **Developer satisfaction**: > 90% positive feedback on config system

---

## 📞 Support & Ownership

**Execution Owner:** Platform Engineering Team
**Service Owners:** Individual service teams
**Infrastructure Owner:** DevOps Team
**Approval Required:** Architecture Review Board

**Contact:** platform-eng@pms.com
**Slack:** #platform-config-standardization</content>
<parameter name="filePath">/mnt/c/Developer/pms-new/pms-infra/docs/env-refactor-plan.md