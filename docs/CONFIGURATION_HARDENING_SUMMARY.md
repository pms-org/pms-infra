# Configuration Hardening Summary

## ✅ Completed Actions

### 1. Fixed Simulation Service
- **Problem**: Using `@Value("${APP_RABBIT_STREAM_USERNAME}")` instead of property path
- **Solution**: Changed to `@Value("${app.rabbitmq.stream.username}")`
- **File**: `pms-simulation/src/main/java/com/dtcc/simulation/service/RabbitStreamProducer.java`
- **Result**: Service now correctly authenticates with RabbitMQ

### 2. Updated Helm Charts
- **Changed**: `imagePullPolicy: IfNotPresent` → `imagePullPolicy: Always` (dev only)
- **Added**: Standardized secret mappings in ExternalSecret
- **Result**: Consistent deployment behavior

### 3. Documented Standards
- Created `STANDARD_ENV_VARS.md` - Quick reference guide
- Created `CONFIG_HARDENING_CHECKLIST.md` - Team action items

---

## 📋 Standard Configuration Matrix

| Service | Port | DB Password | API Key | JWT Secret | RabbitMQ Creds |
|---------|------|------------|---------|------------|----------------|
| simulation | 8090 | ✅ | ✅ | ✅ | ✅ |
| auth | 8081 | ✅ | ❌ | ✅ | ✅ |
| trade-capture | 8082 | ✅ | ✅ | ✅ | ✅ |
| validation | 8080 | ✅ | ✅ | ✅ | ✅ |
| apigateway | 8080 | ❌ | ❌ | ✅ | ❌ |

---

## 🔧 Required Changes for Each Team

### Backend Team (Java Services)

#### 1. Update `@Value` Annotations
```java
// ❌ BEFORE
@Value("${APP_RABBIT_STREAM_USERNAME:guest}")
private String username;

// ✅ AFTER
@Value("${app.rabbitmq.stream.username}")
private String username;
```

#### 2. Update `application.yaml`
```yaml
# ❌ BEFORE
app:
  rabbitmq:
    stream:
      username: ${APP_RABBIT_STREAM_USERNAME:guest}
      password: ${APP_RABBIT_STREAM_PASSWORD:guest}

# ✅ AFTER
app:
  rabbitmq:
    stream:
      username: ${app.rabbitmq.stream.username}
      password: ${app.rabbitmq.stream.password}
```

#### 3. Remove All Hardcoded Credentials
- Search for: `guest`, `admin`, `password`, `secret`, `123`
- Replace with environment variable references
- No default values in production configs

### DevOps Team (Infrastructure)

#### 1. Update All Service Charts
Follow the pattern in `k8s/charts/services/simulation/values.yaml`:

```yaml
secrets:
  path: pms/dev/<service>
  refreshInterval: 1h
  data:
    - secretKey: <SERVICE>_DB_PASSWORD
      remoteKey: <SERVICE>_DB_PASSWORD
    - secretKey: SPRING_RABBITMQ_USERNAME
      remoteKey: SPRING_RABBITMQ_USERNAME
    - secretKey: SPRING_RABBITMQ_PASSWORD
      remoteKey: SPRING_RABBITMQ_PASSWORD
```

#### 2. Update AWS Secrets Manager
Each service needs these keys in `pms/dev/<service>`:
- `<SERVICE>_DB_PASSWORD`
- `<SERVICE>_API_KEY` (if applicable)
- `<SERVICE>_JWT_SECRET`
- `SPRING_RABBITMQ_USERNAME`
- `SPRING_RABBITMQ_PASSWORD`

#### 3. Set Image Pull Policy
```yaml
# Development
deployment:
  image:
    pullPolicy: Always

# Production
deployment:
  image:
    pullPolicy: IfNotPresent
    tag: v1.2.3  # Use specific versions
```

---

## 🚫 Variables to REMOVE

### Deprecated Environment Variables

| ❌ Old Name | ✅ New Name | Reason |
|------------|-----------|---------|
| `APP_RABBIT_STREAM_USERNAME` | Use Spring mapping | Incorrect pattern |
| `APP_RABBIT_STREAM_PASSWORD` | Use Spring mapping | Incorrect pattern |
| `RABBITMQ_USERNAME` | `SPRING_RABBITMQ_USERNAME` | Not Spring standard |
| `RABBITMQ_PASSWORD` | `SPRING_RABBITMQ_PASSWORD` | Not Spring standard |
| `<SERVICE>_DB_PASSWORD` in ConfigMap | Move to Secrets | Security risk |

### Hardcoded Values to Remove

```yaml
# ❌ REMOVE these from application.yaml
username: guest
password: admin
secret: password123
api-key: test-key

# ✅ USE environment variable references
username: ${app.rabbitmq.stream.username}
password: ${app.rabbitmq.stream.password}
```

---

## 📊 Standard Environment Variable Naming

### Pattern: `<PREFIX>_<SERVICE>_<PROPERTY>`

#### Infrastructure
```
DB_HOST
DB_PORT  
DB_NAME
RABBITMQ_HOST
RABBITMQ_STREAM_PORT
KAFKA_BOOTSTRAP_SERVERS
REDIS_HOST
```

#### Spring Framework
```
SPRING_DATASOURCE_URL
SPRING_DATASOURCE_USERNAME
SPRING_DATASOURCE_PASSWORD
SPRING_RABBITMQ_USERNAME
SPRING_RABBITMQ_PASSWORD
SPRING_RABBITMQ_STREAM_USERNAME
SPRING_RABBITMQ_STREAM_PASSWORD
SPRING_KAFKA_BOOTSTRAP_SERVERS
```

#### Service-Specific
```
SIMULATION_DB_PASSWORD
SIMULATION_API_KEY
SIMULATION_JWT_SECRET
AUTH_DB_PASSWORD
TRADE_CAPTURE_API_KEY
```

---

## 🔍 Validation Checklist

### Before Deployment

- [ ] No hardcoded credentials in code
- [ ] All `@Value` annotations use property paths
- [ ] All secrets in AWS Secrets Manager
- [ ] ExternalSecret configured correctly
- [ ] Image rebuilt and pushed
- [ ] `imagePullPolicy` set appropriately

### After Deployment

- [ ] All pods in Running status
- [ ] No authentication errors in logs
- [ ] Services can connect to RabbitMQ
- [ ] Services can connect to database
- [ ] Health checks passing
- [ ] Metrics collecting

### Testing Commands

```bash
# Check pod status
kubectl get pods -n pms

# Check service logs
kubectl logs -n pms -l app=simulation --tail=100

# Check environment variables
kubectl exec -n pms deployment/simulation -- env | grep -E "SPRING_RABBITMQ|DB_"

# Check RabbitMQ connections
kubectl exec -n pms deployment/rabbitmq -- rabbitmqctl list_connections

# Check secrets
kubectl get secret -n pms simulation-secrets -o yaml
```

---

## 🛡️ Security Best Practices

1. **Secrets Management**
   - ✅ Store in AWS Secrets Manager
   - ✅ Use ExternalSecrets Operator
   - ✅ Rotate regularly
   - ❌ Never commit to Git
   - ❌ Never log sensitive data

2. **Access Control**
   - Use IRSA for AWS access
   - Least privilege principle
   - Separate secrets per environment
   - Separate secrets per service

3. **Configuration**
   - No default credentials
   - Validate on startup
   - Fail fast if missing required config
   - Log configuration (mask secrets)

4. **Images**
   - Use specific version tags in production
   - Scan for vulnerabilities
   - Use minimal base images
   - Sign images

---

## 📚 Documentation Index

1. **STANDARD_ENV_VARS.md** - Quick reference for all environment variables
2. **CONFIG_HARDENING_CHECKLIST.md** - Team action items
3. **This File** - Complete summary and migration guide

---

## 🤝 Team Responsibilities

### Backend Developers
- Update Java code (@Value annotations)
- Update application.yaml
- Remove hardcoded credentials
- Test locally with env vars
- Build and push Docker images

### DevOps Engineers
- Update Helm charts
- Configure AWS Secrets Manager
- Deploy with umbrella chart
- Monitor deployments
- Document infrastructure changes

### QA Team
- Verify all services start correctly
- Test authentication flows
- Verify database connections
- Test service-to-service communication
- Validate in all environments

---

## 🔄 Migration Process

1. **Week 1: Preparation**
   - Review documentation
   - Audit current configurations
   - Identify all hardcoded credentials
   - Plan AWS Secrets Manager structure

2. **Week 2: Development**
   - Update application code
   - Update Helm charts
   - Configure AWS Secrets Manager
   - Test locally

3. **Week 3: Testing**
   - Deploy to dev environment
   - Run integration tests
   - Fix issues
   - Document learnings

4. **Week 4: Production**
   - Deploy to staging
   - Smoke tests
   - Deploy to production
   - Monitor

---

## 📞 Support

- **Questions**: Platform Team Slack channel
- **Issues**: Create Jira ticket
- **Urgent**: On-call rotation
- **Documentation**: `/docs` directory in pms-infra repo

---

## 🎯 Success Criteria

- ✅ All services use standardized env vars
- ✅ Zero hardcoded credentials
- ✅ All secrets in AWS Secrets Manager
- ✅ All services deploy successfully
- ✅ No authentication errors
- ✅ Team alignment on standards
- ✅ Documentation complete
