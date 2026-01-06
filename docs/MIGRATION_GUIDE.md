# Migration Guide: Flat Structure → Kustomize Base/Overlay

## What Changed?

### Before (Flat Structure)
```yaml
# deployment.yaml - Everything hardcoded
env:
  - name: KAFKA_BOOTSTRAP_SERVERS
    value: "kafka:9092"
  - name: POSTGRES_USER
    value: "pms"
  - name: POSTGRES_PASSWORD
    value: "pms"
```

### After (Kustomize Pattern)
```yaml
# deployment.yaml - Clean and environment-agnostic
envFrom:
  - configMapRef:
      name: simulation-config
  - secretRef:
      name: simulation-secrets
```

```properties
# simulation.properties - Non-sensitive config
KAFKA_BOOTSTRAP_SERVERS=kafka:9092
```

```env
# simulation.env - Sensitive secrets
POSTGRES_USER=pms
POSTGRES_PASSWORD=pms
```

## Benefits Achieved

✅ **Separation of Concerns**: Config separated from deployment manifests  
✅ **Environment Reusability**: Same base works for dev/stage/prod  
✅ **Automatic Rolling Updates**: Config changes trigger pod restarts via hash suffixes  
✅ **Security**: Secrets separated from public config  
✅ **GitOps Ready**: Easy to version and track changes  

## File-by-File Changes

### Simulation Service

**Modified Files:**
- `base/apps/simulation/deployment.yaml` - Stripped env vars, added `envFrom`
- `base/apps/simulation/service.yaml` - No changes

**New Files:**
- `base/apps/simulation/simulation.properties` - All non-sensitive config
- `base/apps/simulation/simulation.env` - Database credentials

### Validation Service

**Modified Files:**
- `base/apps/validation/deployment.yaml` - Stripped env vars, added `envFrom`
- `base/apps/validation/service.yaml` - No changes

**New Files:**
- `base/apps/validation/validation.properties` - All non-sensitive config
- `base/apps/validation/validation.env` - Database credentials

### Trade-Capture Service

**Modified Files:**
- `base/apps/trade-capture/deployment.yaml` - Stripped env vars, added `envFrom`
- `base/apps/trade-capture/service.yaml` - No changes

**Existing Files Kept:**
- `base/apps/trade-capture/trade-capture.properties` - Already existed
- `base/apps/trade-capture/trade-capture.env` - Already existed

### Infrastructure Services

#### Kafka
**Modified Files:**
- `base/infra/kafka/deployment.yaml` - Stripped env vars, added `envFrom`

**Existing Files Kept:**
- `base/infra/kafka/kafka.properties`
- `base/infra/kafka/kafka.env`

#### Postgres
**Modified Files:**
- `base/infra/postgres/deployment.yaml` - Stripped env vars, added `envFrom`

**New Files:**
- `base/infra/postgres/postgres.env`

#### RabbitMQ
**Modified Files:**
- `base/infra/rabbitmq/deployment.yaml` - Stripped env vars, added `envFrom`

**New Files:**
- `base/infra/rabbitmq/rabbitmq.env`

#### Redis
**Modified Files:**
- `base/infra/redis/deployment.yaml` - No changes (no env vars to extract)

#### Schema Registry
**Modified Files:**
- `base/infra/schema-registry/deployment.yaml` - Stripped env vars, added `envFrom`

**New Files:**
- `base/infra/schema-registry/schema-registry.properties`

## Overlay Structure

### Dev Overlay (`overlays/dev/`)

**Features:**
- 2 replicas for each microservice
- emptyDir volumes (no persistence)
- Basic ingress for local testing
- Uses base `.env` files for secrets

**Key Files:**
```
overlays/dev/
├── kustomization.yaml    # Defines generators and patches
└── ingress.yaml         # Development ingress rules
```

### Prod Overlay (`overlays/prod/`)

**Features:**
- 5 replicas for each microservice
- Resource limits and requests defined
- PVC volumes for persistence
- Production-specific secrets

**Key Files:**
```
overlays/prod/
├── kustomization.yaml              # Defines generators and patches
├── simulation-secrets.env          # Prod-specific secrets
├── validation-secrets.env
├── trade-capture-secrets.env
├── kafka-secrets.env
├── postgres-secrets.env
└── rabbitmq-secrets.env
```

## How Generators Work

### ConfigMap Generator
```yaml
configMapGenerator:
  - name: simulation-config
    files:
      - ../../base/apps/simulation/simulation.properties
```

**Result:**
- Creates: `simulation-config-<hash>` ConfigMap
- Hash changes when content changes
- Triggers rolling update automatically

### Secret Generator
```yaml
secretGenerator:
  - name: simulation-secrets
    envs:
      - simulation-secrets.env
```

**Result:**
- Creates: `simulation-secrets-<hash>` Secret
- Hash changes when content changes
- Triggers rolling update automatically

## Testing the Migration

### 1. Validate Kustomize Output

```bash
# Dev environment
kubectl kustomize k8s/overlays/dev > /tmp/dev-output.yaml
cat /tmp/dev-output.yaml

# Prod environment
kubectl kustomize k8s/overlays/prod > /tmp/prod-output.yaml
cat /tmp/prod-output.yaml
```

### 2. Check Generated Resources

Look for ConfigMaps and Secrets with hash suffixes:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: simulation-config-abc123def  # ← Hash suffix
  namespace: pms
```

### 3. Verify Environment References

Check that deployments reference the correct ConfigMaps/Secrets:
```yaml
envFrom:
- configMapRef:
    name: simulation-config
- secretRef:
    name: simulation-secrets
```

### 4. Deploy to Dev

```bash
# Deploy
kubectl apply -k k8s/overlays/dev

# Verify pods are running
kubectl get pods -n pms

# Check logs
kubectl logs -n pms deployment/simulation

# Verify environment variables are injected
kubectl exec -n pms deployment/simulation -- env | grep KAFKA
```

### 5. Test Configuration Updates

```bash
# Modify a config value
echo "KAFKA_BOOTSTRAP_SERVERS=kafka:9093" >> k8s/base/apps/simulation/simulation.properties

# Reapply
kubectl apply -k k8s/overlays/dev

# Watch the rollout
kubectl rollout status deployment/simulation -n pms

# Verify new config
kubectl exec -n pms deployment/simulation -- env | grep KAFKA
```

## ArgoCD Integration

### Update ArgoCD Applications

**Before:**
```yaml
# argocd/applications/trade-capture-dev.yaml
spec:
  source:
    path: k8s/overlays-pms/dev
```

**After:**
```yaml
# argocd/applications/trade-capture-dev.yaml
spec:
  source:
    path: k8s/overlays/dev
```

### Update All ArgoCD Apps

```bash
# Update dev
sed -i 's|k8s/overlays-pms/dev|k8s/overlays/dev|g' argocd/applications/trade-capture-dev.yaml

# Update prod
sed -i 's|k8s/overlays-pms/prod|k8s/overlays/prod|g' argocd/applications/trade-capture-prod.yaml

# Sync
kubectl apply -f argocd/applications/
```

## Rollback Plan

If issues occur, rollback is simple:

### Option 1: Revert to Old Structure
```bash
# Use the old overlays-pms structure
kubectl apply -k k8s/overlays-pms/dev
```

### Option 2: Git Revert
```bash
git revert <commit-hash>
kubectl apply -k k8s/overlays/dev
```

### Option 3: Manual Rollback
```bash
kubectl rollout undo deployment/simulation -n pms
```

## Common Issues and Solutions

### Issue 1: ConfigMap Not Found

**Error:**
```
Warning  FailedMount  configmap "simulation-config" not found
```

**Solution:**
Kustomize didn't run. Always use `kubectl apply -k` not `kubectl apply -f`:
```bash
kubectl apply -k k8s/overlays/dev  # ✅ Correct
kubectl apply -f k8s/overlays/dev/kustomization.yaml  # ❌ Wrong
```

### Issue 2: Pods Not Restarting on Config Change

**Cause:** Hash suffix not changing

**Solution:**
1. Check if file was actually modified
2. Ensure you're using generators (not static ConfigMaps)
3. Force restart:
   ```bash
   kubectl rollout restart deployment/simulation -n pms
   ```

### Issue 3: Secret Values Not Loading

**Error:**
```
panic: database connection failed
```

**Solution:**
1. Verify secret exists:
   ```bash
   kubectl get secrets -n pms | grep simulation
   ```
2. Check secret content:
   ```bash
   kubectl get secret simulation-secrets-<hash> -n pms -o yaml
   ```
3. Decode and verify:
   ```bash
   kubectl get secret simulation-secrets-<hash> -n pms -o jsonpath='{.data.SPRING_DATASOURCE_PASSWORD}' | base64 -d
   ```

### Issue 4: Wrong Environment Variables

**Cause:** Mixing dev and prod secrets

**Solution:**
Ensure correct overlay is applied:
```bash
# Check which overlay was last applied
kubectl get deployment simulation -n pms -o yaml | grep "environment:"
```

## Production Checklist

Before deploying to production:

- [ ] Update all `*-secrets.env` files in `overlays/prod/`
- [ ] Change default passwords (no "pms", "guest", "CHANGEME")
- [ ] Verify resource limits are appropriate
- [ ] Ensure PVCs are created for stateful services
- [ ] Configure External Secrets Operator (recommended)
- [ ] Setup backup strategy for databases
- [ ] Configure monitoring and alerting
- [ ] Test disaster recovery procedures
- [ ] Review security policies
- [ ] Update documentation

## Next Steps

1. **Remove Legacy Structure**
   ```bash
   rm -rf k8s/overlays-pms/
   ```

2. **Add Stage Environment**
   ```bash
   cp -r k8s/overlays/dev k8s/overlays/stage
   # Edit stage-specific values
   ```

3. **Implement External Secrets**
   - Install External Secrets Operator
   - Configure AWS Secrets Manager integration
   - Migrate from secretGenerator to ExternalSecret

4. **Add More Overlays**
   - `overlays/local` - For local development
   - `overlays/qa` - For QA testing
   - `overlays/uat` - For user acceptance testing

## Questions?

Refer to:
- `k8s/README.md` - Main documentation
- [Kustomize Best Practices](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/)
- ArgoCD documentation for GitOps integration
