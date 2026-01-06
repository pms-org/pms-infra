# PMS Infrastructure Repository Refactor Analysis

## Executive Summary

This document provides a comprehensive production-grade refactor analysis for the `pms-infra` repository. The current structure mixes application manifests, infrastructure services, and environment-specific configurations, leading to maintenance challenges and environment divergence issues.

**Key Findings:**
- Mixed concerns between applications and platform infrastructure
- Environment-specific logic scattered across overlays
- Inconsistent secret management between dev and prod
- Difficulty scaling to additional environments or services

**Proposed Solution:** Implement a clean separation between applications, platform infrastructure, and environments with service-owned secret management.

---

## 1. Current Problems

### Structural Issues
- **Mixed concerns**: `k8s/base/` contains both infrastructure services (Kafka, Redis, Postgres) and applications (simulation, trade-capture, validation)
- **Environment coupling**: Dev overlay patches Postgres to use `emptyDir`, but prod overlay still includes the in-cluster Postgres from base
- **Duplicate overlays**: Both `k8s/overlays/dev` and `k8s/overlays-pms/dev` exist with unclear separation
- **Infrastructure sprawl**: All infra services are always deployed, even when prod should use managed services

### Secret Management Issues
- **Scattered configuration**: Secrets are handled in overlay-specific patches rather than service-owned
- **Environment-specific logic**: Dev uses literal secrets, prod uses ExternalSecrets - creates maintenance burden
- **No atomic secrets**: Each service doesn't own its secret dependencies clearly

### Runtime Risks
- **Prod deploys unnecessary infra**: Kafka, Redis, RabbitMQ deployed in prod when they might be managed services
- **Breaking changes potential**: Base includes Postgres that prod doesn't want
- **Hard to test changes**: No clear separation between what changes affect dev vs prod

---

## 2. Target Architecture

### Core Principles
- **Service ownership**: Each service owns its manifests, secrets, and configuration
- **Environment as composition**: Environments compose services, not patch them extensively
- **Platform vs Application separation**: Clear boundary between infrastructure and apps
- **Atomic secrets**: Each service declares its secret dependencies independently

### Service Boundaries
- **Platform services**: Kafka, Redis, RabbitMQ, Schema Registry (conditionally deployed)
- **Application services**: simulation, trade-capture, validation (always deployed)
- **Data services**: Postgres (dev-only), RDS (prod-only)

---

## 3. Proposed Folder Structure

```
pms-infra/
├── apps/                          # Application manifests
│   ├── simulation/
│   │   ├── base/                  # Service-specific base
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── kustomization.yaml
│   │   │   └── secrets/           # Service-owned secrets
│   │   │       ├── database.yaml  # ExternalSecret for DB
│   │   │       └── kustomization.yaml
│   │   └── overlays/              # Environment-specific patches
│   │       ├── dev/
│   │       └── prod/
│   ├── trade-capture/
│   │   ├── base/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── secrets/
│   │   │   │   ├── database.yaml
│   │   │   │   ├── kafka.yaml
│   │   │   │   └── auth.yaml
│   │   │   └── kustomization.yaml
│   │   └── overlays/
│   │       ├── dev/
│   │       └── prod/
│   └── validation/
│       └── [same structure]
├── platform/                      # Infrastructure manifests
│   ├── kafka/
│   │   ├── base/
│   │   └── overlays/
│   │       └── dev/               # Only dev needs this
│   ├── redis/
│   │   └── overlays/
│   │       └── dev/
│   ├── rabbitmq/
│   │   └── overlays/
│   │       └── dev/
│   └── schema-registry/
│       └── overlays/
│       └── dev/
├── environments/                  # Environment composition
│   ├── dev/
│   │   ├── kustomization.yaml     # Composes: all apps + all platform
│   │   └── config/
│   │       └── app-config.yaml    # Dev-specific ConfigMap
│   └── prod/
│       ├── kustomization.yaml     # Composes: all apps only
│       └── config/
│       └── app-config.yaml    # Prod-specific ConfigMap
├── secrets/                       # AWS Secrets Manager structure
│   └── domains/
│       ├── database/
│       │   ├── dev/               # In-cluster Postgres creds
│       │   └── prod/              # RDS creds
│       ├── kafka/
│       └── auth/
└── terraform/                     # Infrastructure as Code
    ├── environments/
    │   ├── dev/
    │   └── prod/
    └── modules/
```

---

## 4. Secrets Architecture

### AWS Secrets Manager Structure
```
pms/
├── database/
│   ├── dev/           # {"host":"postgres.pms.svc.cluster.local", "port":"5432", ...}
│   └── prod/          # {"host":"pms-prod-postgres.xxxx.rds.amazonaws.com", "port":"5432", ...}
├── kafka/
│   ├── dev/           # {"bootstrap_servers":"kafka.pms.svc.cluster.local:9092", ...}
│   └── prod/          # {"bootstrap_servers":"msk.xxxx.amazonaws.com:9092", ...}
└── auth/
    ├── dev/           # {"jwt_secret":"dev-key", ...}
    └── prod/          # {"jwt_secret":"prod-key", ...}
```

### ExternalSecret Pattern per Service
```yaml
# apps/trade-capture/base/secrets/database.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: trade-capture-database
spec:
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: trade-capture-database
  data:
  - secretKey: SPRING_DATASOURCE_URL
    remoteRef:
      key: pms/database/{{ .Values.environment }}
      property: url
  - secretKey: SPRING_DATASOURCE_USERNAME
    remoteRef:
      key: pms/database/{{ .Values.environment }}
      property: username
```

### Spring Boot Consumption
```yaml
# application.yaml
spring:
  datasource:
    url: ${SPRING_DATASOURCE_URL}
    username: ${SPRING_DATASOURCE_USERNAME}
    password: ${SPRING_DATASOURCE_PASSWORD}
  kafka:
    bootstrap-servers: ${KAFKA_BOOTSTRAP_SERVERS}
```

---

## 5. Migration Plan (NON-BREAKING)

### Phase 1: Create New Structure (Safe)
```bash
# Create new directories
mkdir -p apps/{simulation,trade-capture,validation}/{base,overlays/{dev,prod}}
mkdir -p platform/{kafka,redis,rabbitmq,schema-registry}/overlays/dev
mkdir -p environments/{dev,prod}/config
mkdir -p secrets/domains/{database,kafka,auth}/{dev,prod}

# Copy existing files (don't move yet)
cp k8s/base/apps/* apps/simulation/base/
cp k8s/base/apps/* apps/trade-capture/base/
cp k8s/base/apps/* apps/validation/base/
```

### Phase 2: Extract Service Ownership
```bash
# Move app manifests to service-owned structure
mv k8s/base/apps/simulation/* apps/simulation/base/
mv k8s/base/apps/trade-capture/* apps/trade-capture/base/
mv k8s/base/apps/validation/* apps/validation/base/

# Create service-specific kustomizations
# apps/simulation/base/kustomization.yaml
cat > apps/simulation/base/kustomization.yaml << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
EOF
```

### Phase 3: Platform Separation
```bash
# Move platform services
mv k8s/base/infra/* platform/

# Create platform overlays (dev-only for now)
for service in kafka redis rabbitmq schema-registry; do
  mkdir -p platform/$service/overlays/dev
  # Create kustomization that includes base + dev patches
done
```

### Phase 4: Environment Composition
```bash
# environments/dev/kustomization.yaml
cat > environments/dev/kustomization.yaml << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: pms

resources:
  # All platform services (dev versions)
  - ../../platform/kafka/overlays/dev
  - ../../platform/redis/overlays/dev
  - ../../platform/rabbitmq/overlays/dev
  - ../../platform/schema-registry/overlays/dev

  # All applications
  - ../../apps/simulation/base
  - ../../apps/trade-capture/base
  - ../../apps/validation/base

# Dev-specific labels
labels:
  - pairs:
      environment: dev
EOF

# environments/prod/kustomization.yaml
cat > environments/prod/kustomization.yaml << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: pms

resources:
  # NO platform services - prod uses managed services
  # Only applications
  - ../../apps/simulation/base
  - ../../apps/trade-capture/base
  - ../../apps/validation/base

# Prod-specific labels
labels:
  - pairs:
      environment: prod
EOF
```

### Phase 5: Secrets Migration
```bash
# Create service-owned secrets
mkdir -p apps/trade-capture/base/secrets

# Move external secrets to service ownership
cp k8s/overlays-pms/prod/external-secret-trade-capture.yaml \
   apps/trade-capture/base/secrets/database.yaml

# Update secret references to use domain-based naming
sed -i 's|pms/prod/database|pms/database/prod|g' \
  apps/trade-capture/base/secrets/database.yaml
```

### Phase 6: Validation & Cutover
```bash
# Test builds
kustomize build environments/dev > /tmp/dev-manifests.yaml
kustomize build environments/prod > /tmp/prod-manifests.yaml

# Compare with old structure
kustomize build k8s/overlays-pms/dev > /tmp/old-dev-manifests.yaml
diff /tmp/dev-manifests.yaml /tmp/old-dev-manifests.yaml

# Only after validation: remove old structure
rm -rf k8s/overlays-pms/
```

---

## 6. Validation Checklist

### Pre-Migration
- [ ] `kustomize build k8s/overlays-pms/dev` works
- [ ] `kustomize build k8s/overlays-pms/prod` works
- [ ] All secrets exist in AWS Secrets Manager
- [ ] External Secrets Operator is installed

### During Migration
- [ ] Each phase builds successfully
- [ ] `kubectl apply -k environments/dev --dry-run=client` passes
- [ ] `kubectl apply -k environments/prod --dry-run=client` passes
- [ ] Secret references resolve correctly

### Post-Migration
- [ ] Dev environment deploys successfully
- [ ] Prod environment deploys successfully
- [ ] Applications connect to correct databases
- [ ] ArgoCD syncs work with new structure

### Rollback Strategy
```bash
# If issues: keep old overlays, gradually migrate services
# Worst case: git checkout previous commit
# ArgoCD: Update Application manifests to point to old paths
```

---

## 7. Final Best-Practice Rules

### Repository Governance
1. **Never commit secrets** - All credentials go through External Secrets
2. **Service ownership** - Each service team owns their `apps/<service>/` directory
3. **Platform ownership** - Infra team owns `platform/` and `environments/`
4. **Environment isolation** - Dev and prod are completely separate compositions

### Development Workflow
1. **Test locally**: `kustomize build environments/dev | kubectl apply -f -`
2. **Validate prod**: `kustomize build environments/prod --dry-run`
3. **ArgoCD integration**: Each environment has dedicated ArgoCD Application

### Security Boundaries
1. **Domain-based secrets**: `pms/{domain}/{environment}`
2. **Service-specific access**: Each service only accesses its secrets
3. **Environment separation**: Dev/prod secrets are completely isolated

---

## Implementation Priority

### Immediate Actions (Week 1)
1. Create new directory structure
2. Copy existing manifests to new locations
3. Test that builds work in new structure

### Short-term (Week 2-3)
1. Implement service-owned secrets
2. Create environment compositions
3. Test deployments in dev environment

### Medium-term (Month 1-2)
1. Migrate ArgoCD applications to new structure
2. Implement platform service overlays
3. Add monitoring and alerting

### Long-term (Month 3+)
1. Add staging environment
2. Implement automated testing
3. Add service mesh integration

---

## Risk Assessment

### Low Risk
- Creating new directory structure
- Copying existing manifests
- Testing builds in new structure

### Medium Risk
- Moving platform services to conditional deployment
- Implementing service-owned secrets
- Updating ArgoCD applications

### High Risk
- Removing old directory structure
- Changing secret references
- Production deployment with new structure

### Mitigation Strategies
1. **Gradual migration**: Keep old structure until new is validated
2. **Feature flags**: Use ArgoCD to gradually roll out changes
3. **Rollback plan**: Git-based rollback for any issues
4. **Testing**: Comprehensive testing in dev before prod

---

## Success Metrics

### Technical Metrics
- [ ] Build time < 30 seconds for any environment
- [ ] Zero manual secret management
- [ ] 100% automated deployment success rate
- [ ] < 5 minute rollback time

### Operational Metrics
- [ ] New service onboarding time < 1 day
- [ ] Environment provisioning time < 15 minutes
- [ ] Incident response time < 10 minutes
- [ ] Developer productivity increase > 30%

---

## Conclusion

This refactor addresses the core architectural issues while maintaining backward compatibility and providing a clear path to scale. The key insight is treating environments as compositions of services rather than extensive patches of a monolithic base.

The proposed structure provides:
- **Clear ownership boundaries** between platform and application teams
- **Scalable secret management** that grows with the number of services
- **Environment isolation** that prevents dev changes from affecting prod
- **GitOps-friendly structure** that works seamlessly with ArgoCD

**Next Steps:**
1. Review and approve this analysis
2. Schedule implementation kickoff meeting
3. Begin Phase 1 implementation
4. Establish monitoring for migration success

---

*Document Version: 1.0*
*Date: January 6, 2026*
*Authors: PMS Platform Team*</content>
<parameter name="filePath">/mnt/c/Developer/pms-new/pms-infra/REFACTOR_ANALYSIS.md