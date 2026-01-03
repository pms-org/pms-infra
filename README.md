# pms-infra — Infrastructure (GitOps)

This repository is the single source of truth for Kubernetes manifests and Argo CD Applications for PMS.

Key principles
- Argo CD is the only deployment mechanism. No kubectl in CI.
- Image tags are immutable (use Git SHAs).
- No secrets in Git; use External Secrets Operator or AWS Secrets Manager (IRSA recommended).

Repository layout (mandatory)

```
pms-infra/
├── argocd/                # Argo CD install, Application manifests, Projects
├── services/              # Per-service kustomize bases + overlays
├── monitoring/            # Prometheus + Grafana manifests
├── environments/          # Optional environment-level collections
└── README.md
```

How deployments work (summary)
1. App CI builds an immutable image and updates `services/<service>/kustomization.yaml` (images.newTag).
2. CI commits that single-file change to `pms-infra`.
3. Argo CD detects the change and applies the new manifest to the target namespace.

CI contract (what to modify)
- File: `services/<service>/kustomization.yaml` — change only the `images` newTag field.

Example GitHub Actions step (illustrative)

```yaml
- name: Update infra with new image
  run: |
    git clone https://github.com/pms-org/pms-infra infra
    cd infra/services/my-service
    # update kustomization images.newTag using a small script or yq
    yq e '.images[0].newTag = "${{ steps.build.outputs.image_sha }}"' -i kustomization.yaml
    git add kustomization.yaml
    git commit -m "chore(my-service): bump image to ${{ steps.build.outputs.image_sha }}"
    git push
```

Notes: The workflow above needs only Git credentials and repo push access — no kubectl or cluster access.

Environments
- Use namespaces: `pms-dev`, `pms-stage`, `pms-prod`.
- Per-service overlays are under `services/<service>/overlays/{dev,stage,prod}` and set namespace/replicas.

Monitoring
- Deploy Prometheus + Grafana to namespace `monitoring`. Prometheus scrapes services annotated with
  `prometheus.io/scrape: "true"` and `prometheus.io/path: "/actuator/prometheus"`.

Promotion and rollback
- Promote by merging commits (dev → stage → prod). Rollback by reverting the deployment commit in Git.

Security & best practices
- Do not put secrets in Git. Use External Secrets Operator or AWS Secrets Manager and IRSA.
- Argo CD should be the only system allowed to change cluster resources.

See `argocd/`, `services/` and `monitoring/` for example manifests and usage notes.

Example CI -> infra integration
- See the example GitHub Actions workflow in the `pms-trade-capture` repository: `.github/workflows/build-and-update-infra.yml`. It demonstrates building an immutable image tag and updating `services/trade-capture/kustomization.yaml` in this repo.

How to add a new service (summary)
1. Add Kubernetes base manifests under `k8s/base/apps/<service>` (Deployment + Service). Do NOT put secrets in YAML.
2. Add `services/<service>/kustomization.yaml` that references the base and defines the `images` entry.
3. Add overlays `services/<service>/overlays/{dev,stage,prod}` to set namespace/replicas.
4. Add Argo CD Applications in `argocd/applications/` (one per environment) pointing to the appropriate overlay path.

# PMS DevOps Repository# PMS Infrastructure - Simple Kubernetes Setup



**Central infrastructure and deployment configuration for the Portfolio Management System (PMS)**This folder contains minimal Kubernetes manifests to run the PMS system on a local Kubernetes cluster.



## Quick Start## ⚠️ IMPORTANT: Networking Fixes Applied



```bash**READ THESE FIRST:**

# 1. Setup secrets- [`NETWORKING_AUDIT.md`](./NETWORKING_AUDIT.md) - Complete networking audit with issue analysis

cp secrets/examples/secrets.env.example k8s/overlays/local/secrets.env- [`FIXES_APPLIED.md`](./FIXES_APPLIED.md) - Summary of fixes and testing guide



# 2. Deploy to local Kubernetes**Critical fixes included:**

./scripts/deploy-local.sh- ✅ Init containers added to prevent connection-refused errors

- ✅ Fixed Kafka advertised listeners for Kubernetes

# 3. Verify deployment- ✅ Added missing environment variables for simulation service

kubectl get pods -n pms- ✅ Proper startup order dependencies

```

---

## Repository Structure

## Folder Structure

```

pms-infra/```

├── k8s/                    # Kubernetes manifests (Kustomize)pms-infra/

│   ├── base/              # Base configuration (no secrets)├── namespace.yaml              # PMS namespace

│   └── overlays/          # Environment-specific configs├── postgres/                   # PostgreSQL database

│       ├── local/         # Local development│   ├── deployment.yaml

│       ├── dev/           # Development environment│   └── service.yaml           # Includes PVC

│       └── prod/          # Production environment├── rabbitmq/                   # RabbitMQ with stream plugin

││   ├── deployment.yaml

├── secrets/               # Secret management│   └── service.yaml           # Includes PVC

│   ├── README.md          # Secret management guide├── kafka/                      # Kafka broker (KRaft mode)

│   └── examples/          # Example secret templates│   ├── deployment.yaml

││   └── service.yaml           # Includes PVC

├── terraform/             # Infrastructure as Code (future)├── schema-registry/            # Confluent Schema Registry

│   ├── modules/           # Reusable Terraform modules│   ├── deployment.yaml

│   └── envs/              # Environment-specific configs│   └── service.yaml

│├── redis/                      # Redis with modules

├── ci/                    # CI/CD pipelines│   ├── deployment.yaml

│   ├── github-actions/    # GitHub Actions workflows│   └── service.yaml           # Includes PVC

│   └── jenkins/           # Jenkins pipelines├── simulation/                 # PMS Simulation service

││   ├── deployment.yaml

├── scripts/               # Deployment and utility scripts│   └── service.yaml

│   ├── deploy-local.sh    # Deploy to local cluster├── trade-capture/              # Trade Capture service

│   └── destroy-local.sh   # Remove from local cluster│   ├── deployment.yaml

││   └── service.yaml

└── docs/                  # Documentation├── validation/                 # Validation service

    ├── architecture.md    # System architecture│   ├── deployment.yaml

    ├── local-setup.md     # Local development guide│   └── service.yaml

    └── deployment.md      # Deployment procedures└── README.md                   # This file

``````



## Services## Prerequisites



### Infrastructure1. **Local Kubernetes cluster** running (Docker Desktop or Minikube)

- **PostgreSQL 16** - Primary database2. **Docker images built** for application services:

- **RabbitMQ 3.13** - Message broker with Stream plugin   - `pms-simulation:latest`

- **Kafka 7.5.0** - Event streaming (KRaft mode)   - `trade-capture:latest`

- **Schema Registry 7.5.0** - Protobuf schema management   - `validation-service:latest`

- **Redis** - Caching layer (redislabs/redismod)

### Build Docker Images

### Applications

- **Simulation** - Trade event generatorBefore deploying, build the application images:

- **Trade Capture** - Ingests trades from RabbitMQ, publishes to Kafka

- **Validation** - Validates trades from Kafka```bash

# Build simulation service

## Deploymentcd pms-simulation

docker build -t pms-simulation:latest .

### Local Kubernetes

# Build trade-capture service

```bashcd ../pms-trade-capture

# Deploydocker build -t trade-capture:latest .

./scripts/deploy-local.sh

# Build validation service

# Verifycd ../pms-validation

kubectl get pods -n pmsdocker build -t validation-service:latest -f docker/Dockerfile .

```

# Check logs

kubectl logs -f deployment/trade-capture -n pms## Deploy Everything



# DestroyApply all manifests at once:

./scripts/destroy-local.sh

``````bash

kubectl apply -f pms-infra/

### Manual Deployment```



```bashThis will create:

# Create secrets file- Namespace: `pms`

cp secrets/examples/secrets.env.example k8s/overlays/local/secrets.env- Infrastructure: Postgres, RabbitMQ, Kafka, Schema Registry, Redis

- Applications: Simulation, Trade Capture, Validation

# Apply with Kustomize

kubectl apply -k k8s/overlays/local## Check Status



# VerifyCheck all pods:

kubectl get all -n pms

``````bash

kubectl get pods -n pms

## Development Workflow```



1. **Make changes** to base manifests in `k8s/base/`Check all services:

2. **Test locally** with `./scripts/deploy-local.sh`

3. **Commit** only base manifests and overlay configs```bash

4. **Never commit** `secrets.env` fileskubectl get services -n pms

```

## Environment Variables

Check persistent volume claims:

All applications read configuration from environment variables.

```bash

### Common Variables (non-sensitive)kubectl get pvc -n pms

Defined in `k8s/overlays/<env>/kustomization.yaml` via `configMapGenerator````



### Secrets (sensitive)## View Logs

Defined in `k8s/overlays/<env>/secrets.env` (gitignored) via `secretGenerator`

View logs for a specific service:

See `secrets/README.md` for details.

```bash

## Prerequisites# Trade Capture

kubectl logs -n pms -l app=trade-capture -f

- Kubernetes cluster (Docker Desktop, Minikube, or cloud)

- kubectl# Simulation

- kustomize (or kubectl v1.14+)kubectl logs -n pms -l app=simulation -f



## Troubleshooting# Validation

kubectl logs -n pms -l app=validation-service -f

### Pods not starting

```bash# Kafka

kubectl describe pod <pod-name> -n pmskubectl logs -n pms -l app=kafka -f

kubectl logs <pod-name> -n pms```

```

## Delete Everything

### Kafka/Schema Registry PORT errors

See `docs/KAFKA_FIX_SUMMARY.md` for known issues and solutions.Remove all resources:



### Secret not found```bash

Ensure `k8s/overlays/<env>/secrets.env` exists and contains all required values.kubectl delete namespace pms

```

## Support

This will delete the namespace and all resources inside it.

See detailed documentation in `docs/`:

- `local-setup.md` - Complete local setup guide## Service Communication

- `architecture.md` - System architecture and design

- `deployment.md` - Deployment procedures for all environmentsServices communicate using ClusterIP DNS names:



## License- PostgreSQL: `postgres:5432`

- RabbitMQ: `rabbitmq:5672` (AMQP), `rabbitmq:5552` (Stream)

Internal - Proprietary- Kafka: `kafka:19092` (internal), `kafka:9092` (external)

- Schema Registry: `schema-registry:8081`
- Redis: `redis:6379`
- Simulation: `simulation:4000`
- Trade Capture: `trade-capture:8082`
- Validation: `validation-service:8080`

## Notes

- All deployments use exactly 1 replica
- No health checks, resource limits, or scaling
- Uses local Docker images with `imagePullPolicy: Never`
- Persistent volumes for stateful services (Postgres, RabbitMQ, Kafka, Redis)
- All services run in the `pms` namespace
