# Service-Owned Configuration Refactor

## Current Problems (from repo)

### Centralized Configuration Ownership
- ConfigMap and Secret generators are defined in `overlays/dev/kustomization.yaml` and `overlays/prod/kustomization.yaml`
- Services don't own their configuration - overlays do
- Duplicated `.properties` and `.env` files in overlay directories

### File Duplication
- Properties files copied from `base/apps/<service>/` to `overlays/*/`
- Env files copied and renamed (e.g., `simulation.env` → `simulation-secrets.env`)
- Kustomize path restrictions force this duplication

### Mixed Secret Management
- Local `secretGenerator` for development
- No External Secrets Operator integration
- Secrets committed to repository (security risk)

## Target Architecture

### Service Ownership
Each service owns:
- `base/apps/<service>/kustomization.yaml` - ConfigMap generator
- `base/apps/<service>/external-secret.yaml` - ESO definition
- `base/apps/<service>/<service>.properties` - Non-secret config
- `base/apps/<service>/<service>.env` - Secret template (for local dev)

### Overlay Responsibility
Environment overlays handle:
- Environment composition (which services)
- Replicas, resources, volumes
- Infrastructure behavior
- **NO** application configuration files

### Config Split
- **`.properties` files** → Non-secret configuration (local, committed)
- **AWS Secrets Manager** → Secrets only (via ESO)
- **ConfigMaps** → Generated from `.properties` (service-owned)
- **Secrets** → Generated from AWS Secrets Manager (via ESO)

## Implementation Plan

### Phase 1: Service-Owned ConfigMaps
1. Create `kustomization.yaml` in each service directory
2. Move ConfigMap generators from overlays to services
3. Remove duplicated `.properties` files from overlays
4. Update base `kustomization.yaml` to include service kustomizations

### Phase 2: External Secrets Operator Setup
1. Install ESO in `external-secrets` namespace
2. Create IRSA for ESO service account
3. Create ClusterSecretStore for AWS Secrets Manager
4. Define AWS Secrets Manager structure

### Phase 3: Service-Owned ExternalSecrets
1. Create `external-secret.yaml` for each service
2. Remove `secretGenerator` from overlays
3. Update deployments to use ESO-generated secrets
4. Remove `.env` files from overlays

### Phase 4: Migration & Validation
1. Test non-breaking behavior
2. Provide rollback strategy
3. Document AWS Secrets Manager setup