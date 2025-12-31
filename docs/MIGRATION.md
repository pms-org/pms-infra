# Migration Guide: Legacy to DevOps Repository

## Overview

This guide explains how to migrate from the legacy `pms-infra-backup` structure to the new industry-standard DevOps repository structure.

## What Changed

### Directory Structure

**Before (pms-infra-backup/):**
```
base/
  kafka/deployment.yaml
  kafka/service.yaml
  postgres/deployment.yaml
  ...
overlays/
  local/kustomization.yaml
```

**After (pms-infra/):**
```
k8s/
  base/
    namespace.yaml
    infra/          # Infrastructure services
      kafka/
      postgres/
      ...
    apps/           # Application services
      simulation/
      trade-capture/
      validation/
    kustomization.yaml
  overlays/
    local/
      kustomization.yaml
      secrets.env   # Gitignored
    dev/            # Future
    prod/           # Future
secrets/
  examples/
    secrets.env.example
  README.md
scripts/
  deploy-local.sh
  destroy-local.sh
docs/
  README.md
  local-setup.md
  architecture.md
ci/
  github-actions/  # Future
terraform/         # Future
.gitignore
```

### Key Improvements

1. **Secret Management**: Secrets externalized to `secrets.env` files (gitignored)
2. **Clear Separation**: Infrastructure vs application services clearly separated
3. **Documentation**: Comprehensive docs in dedicated `docs/` directory
4. **Automation**: Deployment scripts with health checks
5. **Security**: `.gitignore` prevents accidental secret commits
6. **Scalability**: Structure ready for dev/prod overlays, CI/CD, IaC

## Migration Steps

### 1. Backup Current Deployment

```bash
# Get current state
kubectl get all -n pms > current-state.yaml

# Backup current kustomization
cp -r pms-infra pms-infra-backup
```

### 2. Clone New Repository

```bash
git clone <your-repo-url> pms-infra-new
cd pms-infra-new
```

### 3. Configure Secrets

```bash
# Copy secret template
cp secrets/examples/secrets.env.example k8s/overlays/local/secrets.env

# Edit with your credentials
vim k8s/overlays/local/secrets.env
```

**Required secrets:**
```env
POSTGRES_USER=pms
POSTGRES_PASSWORD=<your-password>
POSTGRES_DB=pmsdb
RABBITMQ_DEFAULT_USER=guest
RABBITMQ_DEFAULT_PASS=<your-password>
KAFKA_CLUSTER_ID=<your-cluster-id>
```

### 4. Deploy New Structure

```bash
# Deploy using automated script
./scripts/deploy-local.sh

# Or manually
kubectl apply -k k8s/overlays/local

# Verify deployment
kubectl get pods -n pms
```

### 5. Verify All Pods Running

```bash
# Should see 8 pods: kafka, schema-registry, postgres, rabbitmq, redis,
# simulation, trade-capture, validation-service
kubectl wait --for=condition=ready pod -l project=pms -n pms --timeout=300s
```

### 6. Test Applications

```bash
# Check trade-capture logs
kubectl logs -n pms -l app=trade-capture --tail=50

# Verify Kafka connectivity
kubectl exec -it -n pms kafka-<pod-id> -- kafka-topics --list --bootstrap-server localhost:19092

# Test schema registry
curl http://localhost:8081/subjects
```

### 7. Update Git Remote (if applicable)

```bash
# If migrating existing repository
git remote set-url origin <new-repo-url>
git push -u origin main
```

## Rollback Procedure

If issues arise, rollback to the backup:

```bash
# Delete new deployment
kubectl delete namespace pms

# Redeploy from backup
cd pms-infra-backup
kubectl apply -k overlays/local

# Verify
kubectl get pods -n pms
```

## Configuration Differences

### Secrets Handling

**Old Way:**
```yaml
# Hardcoded in deployment.yaml
env:
  - name: POSTGRES_PASSWORD
    value: "pms"  # ❌ Security issue
```

**New Way:**
```yaml
# Referenced from secret
env:
  - name: POSTGRES_PASSWORD
    valueFrom:
      secretKeyRef:
        name: postgres-credentials
        key: POSTGRES_PASSWORD  # ✅ Secure
```

### Kustomize Changes

**Old Way:**
```yaml
# base/kustomization.yaml
resources:
  - kafka/deployment.yaml
  - kafka/service.yaml
  - postgres/deployment.yaml
  ...
```

**New Way:**
```yaml
# k8s/base/kustomization.yaml
resources:
  - namespace.yaml
  - infra/kafka/deployment.yaml
  - infra/kafka/service.yaml
  - apps/simulation/deployment.yaml
  ...

labels:
  - pairs:
      managed-by: kustomize
      project: pms
    includeSelectors: false
```

## Environment-Specific Configuration

### Local Overlay

```yaml
# k8s/overlays/local/kustomization.yaml
secretGenerator:
  - name: postgres-credentials
    envs: [secrets.env]

configMapGenerator:
  - name: app-config
    literals:
      - KAFKA_BOOTSTRAP_SERVERS=kafka:19092
      - SCHEMA_REGISTRY_URL=http://schema-registry:8081
```

### Future: Dev Overlay

```yaml
# k8s/overlays/dev/kustomization.yaml
bases:
  - ../../base

patchesStrategicMerge:
  - replica-patch.yaml  # Increase replicas

images:
  - name: niishantdev/pms-simulation
    newTag: dev-latest
```

### Future: Prod Overlay

```yaml
# k8s/overlays/prod/kustomization.yaml
bases:
  - ../../base

patchesStrategicMerge:
  - resources-patch.yaml  # Production resource limits
  - hpa-patch.yaml        # Horizontal Pod Autoscaling

secretGenerator:
  - name: postgres-credentials
    envs: [secrets-prod.env]  # Different credentials
```

## Known Issues & Solutions

### Issue 1: Kafka PORT Collision

**Symptom:** Kafka pod crashes with "port is deprecated" error

**Solution:** Already fixed in manifests
```yaml
spec:
  template:
    spec:
      enableServiceLinks: false
      containers:
      - command: [/bin/bash, -c, "unset KAFKA_PORT; unset KAFKA_SERVICE_PORT; unset PORT; /etc/confluent/docker/run"]
```

### Issue 2: Schema Registry Connection

**Symptom:** Schema Registry can't connect to Kafka

**Solution:** Use internal Kafka listener
```yaml
env:
  - name: SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS
    value: "kafka:19092"  # Use internal port
```

### Issue 3: Redis Command Error

**Symptom:** Redis crashes with "can't open config file"

**Solution:** Separate command and args
```yaml
command: [redis-server]
args: [--loadmodule, /usr/lib/redis/modules/redisearch.so, ...]
```

## Verification Checklist

After migration, verify:

- [ ] All 8 pods running (`kubectl get pods -n pms`)
- [ ] No secrets committed to git (`git log -- '*secrets.env'` should be empty)
- [ ] Kafka accepting connections (`kubectl logs -n pms kafka-* | grep "Kafka Server started"`)
- [ ] Schema Registry started (`kubectl logs -n pms schema-registry-* | grep "Server started"`)
- [ ] Trade-capture processing trades (`kubectl logs -n pms trade-capture-* | grep "OutboxDispatcher"`)
- [ ] RabbitMQ management UI accessible (`curl http://localhost:15672`)
- [ ] PostgreSQL accepting connections (`kubectl exec -it postgres-* -- psql -U pms -c '\l'`)

## Post-Migration Tasks

1. **Update CI/CD pipelines** to point to new repository structure
2. **Create dev and prod overlays** following local template
3. **Document environment variables** in `docs/configuration.md`
4. **Set up secret management** (e.g., Sealed Secrets, External Secrets Operator)
5. **Implement Infrastructure as Code** in `terraform/`
6. **Configure GitHub Actions** in `ci/github-actions/`

## Support

For issues or questions:
1. Check `docs/troubleshooting.md`
2. Review `docs/architecture.md` for system overview
3. Examine pod logs: `kubectl logs -n pms <pod-name>`
4. Check deployment status: `kubectl describe deployment -n pms <deployment-name>`

## Additional Resources

- [Local Setup Guide](docs/local-setup.md)
- [Architecture Documentation](docs/architecture.md)
- [Secret Management](secrets/README.md)
- [Kustomize Documentation](https://kustomize.io/)
- [Kafka Fix Summary](../pms-infra-backup/KAFKA_FIX_SUMMARY.md)
