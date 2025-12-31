# PHASE 1 COMPLETE ✅

## Summary

Successfully prepared `pms-infra` for cloud deployment with multi-environment support.

### What Was Done

1. **Created Dev Overlay** (`k8s/overlays/dev/`)
   - Excludes PostgreSQL (will use RDS)
   - Moderate resource limits (512Mi-1Gi memory, 250m-500m CPU)
   - Single replica for all services
   - Dev-specific image tags (`dev-latest`)
   - Environment label: `dev`

2. **Created Prod Overlay** (`k8s/overlays/prod/`)
   - Excludes PostgreSQL (will use RDS Multi-AZ)
   - Production resource limits (1Gi-4Gi memory, 500m-2000m CPU)
   - Multi-replica for HA:
     - trade-capture: 3 replicas (critical service)
     - kafka: 3 replicas (will migrate to MSK later)
     - simulation, validation, schema-registry: 2 replicas each
     - rabbitmq, redis: 1 replica (will migrate to managed services later)
   - Semantic versioning for images (`v1.0.0`)
   - Environment label: `prod`

3. **Local Overlay Unchanged**
   - Still uses in-cluster PostgreSQL
   - Local development environment
   - All 8 services including postgres

### Verification

```bash
# Dev overlay (7 deployments - no postgres)
kubectl kustomize k8s/overlays/dev | grep "kind: Deployment" | wc -l
# Output: 7 ✅

# Prod overlay (7 deployments - no postgres)
kubectl kustomize k8s/overlays/prod | grep "kind: Deployment" | wc -l
# Output: 7 ✅

# Local overlay (8 deployments - includes postgres)
kubectl kustomize k8s/overlays/local | grep "kind: Deployment" | wc -l  
# Output: 8 ✅
```

### Key Design Decisions

1. **PostgreSQL Exclusion**
   - Used Kustomize `patches` with `$patch: delete` directive
   - Cleanly removes postgres deployment, service, and PVC from cloud overlays
   - RDS connection details will come from External Secrets (PHASE 5)

2. **Resource Allocation**
   - Dev: Cost-optimized (smaller instances)
   - Prod: Performance-optimized (larger instances, multi-replica)
   - Kafka gets most resources (2-4Gi) as message broker

3. **Secrets Management**
   - Local: File-based secrets (`.env` files, gitignored)
   - Dev/Prod: Placeholder for External Secrets Operator (PHASE 5)
   - Currently using literal secrets (marked with TODO comments)

4. **Image Tagging Strategy**
   - Local: `latest` tags (development)
   - Dev: `dev-latest` tags (automated dev builds)
   - Prod: Semantic versioning `v1.0.0` (immutable releases)

### Directory Structure

```
k8s/overlays/
├── local/              # Docker Desktop/Minikube
│   ├── kustomization.yaml
│   ├── secrets.env     # Gitignored
│   └── (includes postgres)
│
├── dev/                # EKS Dev ✅ NEW
│   ├── kustomization.yaml
│   ├── replica-patch.yaml        (1 replica each)
│   ├── resources-patch.yaml      (moderate limits)
│   └── (NO postgres - using RDS)
│
└── prod/               # EKS Prod ✅ NEW
    ├── kustomization.yaml
    ├── replica-patch.yaml        (multi-replica for HA)
    ├── resources-patch.yaml      (production limits)
    └── (NO postgres - using RDS Multi-AZ)
```

### Next Steps (PHASE 2)

Ready to provision EKS infrastructure with Terraform:

1. Create `terraform/envs/dev/main.tf`
2. Provision VPC (3 AZs, public + private subnets)
3. Create EKS cluster (managed node group, OIDC enabled)
4. Install AWS Load Balancer Controller
5. Install EBS CSI Driver

---

**Status**: ✅ PHASE 1 COMPLETE - Ready for PHASE 2 (EKS Provisioning)

**Date**: December 31, 2025
