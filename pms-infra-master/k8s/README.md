# PMS Infrastructure - Kustomize Structure

## Overview

This directory contains production-grade Kubernetes manifests organized using **Kustomize** with a **Base/Overlay** pattern. The structure separates environment-agnostic resources from environment-specific configurations.

## Directory Structure

```
k8s/
├── base/                           # Environment-agnostic base resources
│   ├── kustomization.yaml         # Base kustomization file
│   ├── namespace.yaml             # PMS namespace definition
│   ├── apps/                      # Microservices
│   │   ├── simulation/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── simulation.properties    # Non-sensitive config
│   │   │   └── simulation.env           # Sensitive secrets (dev only)
│   │   ├── trade-capture/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── trade-capture.properties
│   │   │   └── trade-capture.env
│   │   └── validation/
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       ├── validation.properties
│   │       └── validation.env
│   ├── infra/                     # Infrastructure services
│   │   ├── kafka/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── kafka.properties
│   │   │   └── kafka.env
│   │   ├── postgres/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   └── postgres.env
│   │   ├── rabbitmq/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   └── rabbitmq.env
│   │   ├── redis/
│   │   │   ├── deployment.yaml
│   │   │   └── service.yaml
│   │   └── schema-registry/
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       └── schema-registry.properties
│   └── aws-addons/               # AWS-specific resources
│       ├── secret-store.yaml
│       └── service-account.yaml
├── overlays/                      # Environment-specific overlays
│   ├── dev/
│   │   ├── kustomization.yaml    # Dev-specific configuration
│   │   └── ingress.yaml          # Dev ingress rules
│   └── prod/
│       ├── kustomization.yaml    # Prod-specific configuration
│       ├── simulation-secrets.env
│       ├── validation-secrets.env
│       ├── trade-capture-secrets.env
│       ├── kafka-secrets.env
│       ├── postgres-secrets.env
│       └── rabbitmq-secrets.env
└── overlays-pms/                 # Legacy structure (to be deprecated)
```

## Key Design Principles

### 1. Base Layer (`/base`)

The base layer contains **environment-agnostic** resources:

- ✅ **Clean Deployments**: All `env` variables removed from deployment manifests
- ✅ **ConfigMap/Secret References**: Uses `envFrom` with `configMapRef` and `secretRef`
- ✅ **Reusability**: Can be used across any environment without modification
- ✅ **Properties Files**: Non-sensitive configuration in `.properties` files
- ✅ **Secret Files**: Sensitive data in `.env` files (for reference only)

**Note**: Properties and env files are copied to each overlay directory due to Kustomize path restrictions in some environments (WSL, Windows). This allows generators to work correctly while maintaining a single source of truth in the base layer.

### 2. Overlay Layer (`/overlays`)

Environment-specific customizations are applied through overlays:

#### Dev Environment (`overlays/dev`)
- **Replicas**: 2 replicas for each microservice
- **Volumes**: Uses `emptyDir` (no persistent storage)
- **Ingress**: Includes basic ingress for local development
- **Secrets**: Uses base `.env` files via generators

#### Prod Environment (`overlays/prod`)
- **Replicas**: 5 replicas for each microservice
- **Resource Limits**: CPU and memory limits defined
  - Apps: 512Mi-1Gi memory, 250m-1000m CPU
  - Infra: 256Mi-512Mi memory, 100m-500m CPU
  - Kafka: 1Gi-2Gi memory, 500m-2000m CPU
- **Volumes**: Uses PVCs for persistent storage
- **Secrets**: Environment-specific secret files (use External Secrets in real prod)

### 3. Generator Pattern

Both overlays use **generators** to create ConfigMaps and Secrets:

```yaml
configMapGenerator:
  - name: simulation-config
    files:
      - ../../base/apps/simulation/simulation.properties

secretGenerator:
  - name: simulation-secrets
    envs:
      - simulation-secrets.env
```

**Benefits:**
- ✅ Automatic hash suffixes trigger rolling updates on config changes
- ✅ No manual ConfigMap/Secret manifest creation
- ✅ Content-based versioning

## Usage

### Deploy to Dev Environment

```bash
# Preview what will be deployed
kubectl kustomize k8s/overlays/dev

# Apply to cluster
kubectl apply -k k8s/overlays/dev

# Verify deployment
kubectl get all -n pms
```

### Deploy to Prod Environment

```bash
# ⚠️ IMPORTANT: Update production secrets first!
# Edit files in k8s/overlays/prod/*-secrets.env

# Preview what will be deployed
kubectl kustomize k8s/overlays/prod

# Apply to cluster
kubectl apply -k k8s/overlays/prod

# Verify deployment
kubectl get all -n pms
kubectl get configmaps -n pms
kubectl get secrets -n pms
```

### View Generated Resources

```bash
# See the final YAML with all patches applied
kubectl kustomize k8s/overlays/dev > dev-output.yaml
kubectl kustomize k8s/overlays/prod > prod-output.yaml
```

### Update Configuration

#### Update Non-Sensitive Config (ConfigMap)

1. Edit the `.properties` file in `base/<service>/`
2. Copy the updated file to your overlay:
   ```bash
   cp k8s/base/apps/simulation/simulation.properties k8s/overlays/dev/
   ```
3. Apply the overlay:
   ```bash
   kubectl apply -k k8s/overlays/dev
   ```
4. Pods will automatically restart due to hash suffix change

#### Update Secrets

**Dev:**
1. Edit the `.env` file in `base/<service>/`
2. Copy to overlay:
   ```bash
   cp k8s/base/apps/simulation/simulation.env k8s/overlays/dev/
   ```
3. Apply:
   ```bash
   kubectl apply -k k8s/overlays/dev
   ```

**Prod:**
1. Edit the `.env` file in `overlays/prod/`
2. Apply:
   ```bash
   kubectl apply -k k8s/overlays/prod
   ```

**Why Copy Files?**: Kustomize has path restrictions in some environments (WSL, Windows) that prevent generators from reading files outside the overlay directory. Copying files ensures compatibility while maintaining base as the source of truth.

## Service Configuration

### Applications

| Service | Port | ConfigMap | Secret | Purpose |
|---------|------|-----------|--------|---------|
| simulation | 4000 | `simulation-config` | `simulation-secrets` | Trade simulation |
| trade-capture | 8080 | `trade-capture-config` | `trade-capture-secrets` | Trade capture |
| validation | 8080 | `validation-config` | `validation-secrets` | Trade validation |

### Infrastructure

| Service | Port | ConfigMap | Secret | Purpose |
|---------|------|-----------|--------|---------|
| kafka | 9092, 19092 | `kafka-config` | `kafka-secrets` | Message broker |
| postgres | 5432 | - | `postgres-secrets` | Database |
| rabbitmq | 5672, 15672, 5552 | - | `rabbitmq-secrets` | Message queue |
| redis | 6379 | - | - | Cache |
| schema-registry | 8081 | `schema-registry-config` | - | Schema management |

## Migration from Legacy Structure

The old `overlays-pms/` structure is deprecated. To migrate:

1. ✅ Base deployments refactored (env vars removed)
2. ✅ Properties and env files created
3. ✅ New overlay structure created
4. ⏳ Update ArgoCD applications to point to new paths
5. ⏳ Remove `overlays-pms/` directory

## Production Best Practices

### Security

- 🔒 **Never commit production secrets to Git**
- 🔒 Use **External Secrets Operator** or **Sealed Secrets** for prod
- 🔒 Integrate with **AWS Secrets Manager** or **HashiCorp Vault**
- 🔒 Use **IRSA** (IAM Roles for Service Accounts) for AWS resources

### Managed Services (Production)

Replace in-cluster infrastructure with managed services:

| In-Cluster | AWS Managed | Benefits |
|------------|-------------|----------|
| Postgres | RDS Multi-AZ | High availability, automated backups |
| RabbitMQ | Amazon MQ | Managed message broker |
| Kafka | MSK (Amazon Managed Streaming for Kafka) | Scalable, managed |
| Redis | ElastiCache | High performance, managed |

### Resource Management

- ✅ All production services have resource limits defined
- ✅ Use Horizontal Pod Autoscaling (HPA) for dynamic scaling
- ✅ Monitor resource usage with Prometheus/Grafana

## Troubleshooting

### ConfigMap/Secret Not Found

```bash
# List generated resources
kubectl get configmaps -n pms | grep simulation
kubectl get secrets -n pms | grep simulation

# Check the hash suffix in the deployment
kubectl describe deployment simulation -n pms
```

### Rolling Update Not Triggered

When config changes don't trigger updates:

```bash
# Delete the deployment to force recreation
kubectl rollout restart deployment/simulation -n pms

# Or delete and reapply
kubectl delete -k k8s/overlays/dev
kubectl apply -k k8s/overlays/dev
```

### View Applied Configuration

```bash
# See what's running in the cluster
kubectl get deployment simulation -n pms -o yaml

# Compare with what you expect
kubectl kustomize k8s/overlays/dev | grep -A 20 "kind: Deployment"
```

## Next Steps

1. **Update ArgoCD Applications**: Point to new overlay paths
2. **Implement External Secrets**: For production secret management
3. **Add PVCs**: Create PersistentVolumeClaim manifests for prod
4. **Setup Monitoring**: Add Prometheus ServiceMonitors
5. **Configure HPA**: Add HorizontalPodAutoscaler resources
6. **Implement Network Policies**: Add NetworkPolicy resources for security

## Additional Resources

- [Kustomize Documentation](https://kustomize.io/)
- [Kubernetes ConfigMaps](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [External Secrets Operator](https://external-secrets.io/)
