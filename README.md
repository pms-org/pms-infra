# PMS Infrastructure Repository# pms-infra — Infrastructure (GitOps)



[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)This repository is the single source of truth for Kubernetes manifests and Argo CD Applications for PMS.

[![Kubernetes](https://img.shields.io/badge/kubernetes-1.27+-blue.svg)](https://kubernetes.io/)

[![ArgoCD](https://img.shields.io/badge/argocd-2.7+-blue.svg)](https://argo-cd.readthedocs.io/)Key principles

- Argo CD is the only deployment mechanism. No kubectl in CI.

A comprehensive GitOps infrastructure repository for the Portfolio Management System (PMS), featuring Kubernetes manifests, ArgoCD applications, and infrastructure automation using modern DevOps practices.- Image tags are immutable (use Git SHAs).

- No secrets in Git; use External Secrets Operator or AWS Secrets Manager (IRSA recommended).

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [AWS Deployment](#aws-deployment)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [CI/CD](#cicd)
- [Infrastructure](#infrastructure)
- [Security](#security)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

- [Infrastructure](#infrastructure)```

- [Security](#security)

- [Monitoring](#monitoring)How deployments work (summary)

- [Troubleshooting](#troubleshooting)1. App CI builds an immutable image and updates `services/<service>/kustomization.yaml` (images.newTag).

- [Contributing](#contributing)2. CI commits that single-file change to `pms-infra`.

3. Argo CD detects the change and applies the new manifest to the target namespace.

## 🎯 Overview

CI contract (what to modify)

This repository implements a **GitOps-driven infrastructure** for the PMS (Portfolio Management System) using:- File: `services/<service>/kustomization.yaml` — change only the `images` newTag field.



- **Kubernetes** for container orchestrationExample GitHub Actions step (illustrative)

- **Kustomize** for manifest templating and environment management

- **ArgoCD** for continuous deployment```yaml

- **External Secrets Operator** for secret management- name: Update infra with new image

- **Terraform** for cloud infrastructure provisioning  run: |

    git clone https://github.com/pms-org/pms-infra infra

### Key Features    cd infra/services/my-service

    # update kustomization images.newTag using a small script or yq

- ✅ **Global Deployment Strategy**: Single overlay system deploying entire PMS stack    yq e '.images[0].newTag = "${{ steps.build.outputs.image_sha }}"' -i kustomization.yaml

- ✅ **SRE Compliance**: Resource limits, health probes, rolling updates, HA replicas    git add kustomization.yaml

- ✅ **GitOps**: ArgoCD manages all deployments from Git    git commit -m "chore(my-service): bump image to ${{ steps.build.outputs.image_sha }}"

- ✅ **Secret Management**: AWS Secrets Manager integration with ESO    git push

- ✅ **Multi-Environment**: Local, development, staging, and production environments```

- ✅ **Infrastructure as Code**: Terraform modules for cloud resources

Notes: The workflow above needs only Git credentials and repo push access — no kubectl or cluster access.

## 🏗️ Architecture

Environments

### System Components- Use namespaces: `pms-dev`, `pms-stage`, `pms-prod`.

- Per-service overlays are under `services/<service>/overlays/{dev,stage,prod}` and set namespace/replicas.

```

┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐Monitoring

│   Trade Capture │    │   Simulation    │    │   Validation    │- Deploy Prometheus + Grafana to namespace `monitoring`. Prometheus scrapes services annotated with

│     Service     │    │    Service      │    │    Service      │  `prometheus.io/scrape: "true"` and `prometheus.io/path: "/actuator/prometheus"`.

│                 │    │                 │    │                 │

│ • Spring Boot   │    │ • Python FastAPI│    │ • Spring Boot   │Promotion and rollback

│ • PostgreSQL    │◄──►│ • Redis         │◄──►│ • PostgreSQL    │- Promote by merging commits (dev → stage → prod). Rollback by reverting the deployment commit in Git.

│ • RabbitMQ      │    │ • Kafka         │    │ • Kafka         │

│ • Kafka         │    │ • Schema Reg.   │    │ • Schema Reg.   │Security & best practices

└─────────────────┘    └─────────────────┘    └─────────────────┘- Do not put secrets in Git. Use External Secrets Operator or AWS Secrets Manager and IRSA.

         │                        │                        │- Argo CD should be the only system allowed to change cluster resources.

         └────────────────────────┼────────────────────────┘

                                  │See `argocd/`, `services/` and `monitoring/` for example manifests and usage notes.

                    ┌─────────────────┐

                    │   Infrastructure │Example CI -> infra integration

                    │                 │- See the example GitHub Actions workflow in the `pms-trade-capture` repository: `.github/workflows/build-and-update-infra.yml`. It demonstrates building an immutable image tag and updating `services/trade-capture/kustomization.yaml` in this repo.

                    │ • PostgreSQL    │

                    │ • RabbitMQ      │How to add a new service (summary)

                    │ • Redis         │1. Add Kubernetes base manifests under `k8s/base/apps/<service>` (Deployment + Service). Do NOT put secrets in YAML.

                    │ • Kafka         │2. Add `services/<service>/kustomization.yaml` that references the base and defines the `images` entry.

                    │ • Schema Reg.   │3. Add overlays `services/<service>/overlays/{dev,stage,prod}` to set namespace/replicas.

                    └─────────────────┘4. Add Argo CD Applications in `argocd/applications/` (one per environment) pointing to the appropriate overlay path.

```

# PMS DevOps Repository# PMS Infrastructure - Simple Kubernetes Setup

### Data Flow



1. **Trade Capture** → Ingests market data → Publishes to Kafka

2. **Simulation** → Processes trades → Stores in Redis/PostgreSQL**Central infrastructure and deployment configuration for the Portfolio Management System (PMS)**This folder contains minimal Kubernetes manifests to run the PMS system on a local Kubernetes cluster.

3. **Validation** → Validates trades → Updates PostgreSQL



## 📁 Repository Structure

## Quick Start## ⚠️ IMPORTANT: Networking Fixes Applied

```

pms-infra/

├── argocd/                    # ArgoCD applications & projects

│   ├── applications/          # Application manifests per environment```bash**READ THESE FIRST:**

│   ├── install/               # ArgoCD installation manifests

│   └── projects/              # ArgoCD project definitions# 1. Setup secrets- [`NETWORKING_AUDIT.md`](./NETWORKING_AUDIT.md) - Complete networking audit with issue analysis

│

├── ci/                        # CI/CD pipeline configurationscp secrets/examples/secrets.env.example k8s/overlays-pms/local/secrets.env- [`FIXES_APPLIED.md`](./FIXES_APPLIED.md) - Summary of fixes and testing guide

│   ├── github-actions/        # GitHub Actions workflows

│   └── jenkins/               # Jenkins pipeline configurations

│

├── k8s/                       # Kubernetes manifests (Kustomize)# 2. Deploy to local Kubernetes**Critical fixes included:**

│   ├── base/                  # Base manifests (infrastructure + apps)

│   │   ├── apps/              # Application manifests./scripts/deploy-local.sh- ✅ Init containers added to prevent connection-refused errors

│   │   │   ├── simulation/    # Simulation service

│   │   │   ├── trade-capture/ # Trade capture service- ✅ Fixed Kafka advertised listeners for Kubernetes

│   │   │   └── validation/    # Validation service

│   │   ├── infra/             # Infrastructure manifests# 3. Verify deployment- ✅ Added missing environment variables for simulation service

│   │   │   ├── kafka/         # Kafka broker

│   │   │   ├── postgres/      # PostgreSQL databasekubectl get pods -n pms- ✅ Proper startup order dependencies

│   │   │   ├── rabbitmq/      # RabbitMQ message broker

│   │   │   ├── redis/         # Redis cache```

│   │   │   └── schema-registry/# Confluent Schema Registry

│   │   ├── aws-addons/        # AWS-specific configurations---

│   │   └── kustomization.yaml # Base kustomization

│   └── overlays-pms/          # Environment overlays## Repository Structure

│       ├── local/             # Local development

│       ├── dev/               # Development environment## Folder Structure

│       └── prod/              # Production environment

│```

├── scripts/                   # Deployment and utility scripts

│   ├── deploy-local.sh        # Local deployment scriptpms-infra/```

│   ├── destroy-local.sh       # Local cleanup script

│   └── cleanup-remaining-resources.sh├── k8s/                    # Kubernetes manifests (Kustomize)pms-infra/

│

├── secrets/                   # Secret management│   ├── base/              # Base configuration (no secrets)├── namespace.yaml              # PMS namespace

│   ├── README.md              # Secret management guide

│   └── examples/              # Example secret templates│   └── overlays/          # Environment-specific configs├── postgres/                   # PostgreSQL database

│

└── terraform/                 # Infrastructure as Code│       ├── local/         # Local development│   ├── deployment.yaml

    ├── modules/               # Reusable Terraform modules

    ├── envs/                  # Environment-specific configs│       ├── dev/           # Development environment│   └── service.yaml           # Includes PVC

    └── README.md              # Terraform documentation

```│       └── prod/          # Production environment├── rabbitmq/                   # RabbitMQ with stream plugin



## 📋 Prerequisites││   ├── deployment.yaml



### Required Tools├── secrets/               # Secret management│   └── service.yaml           # Includes PVC



- **kubectl** 1.27+ - Kubernetes CLI│   ├── README.md          # Secret management guide├── kafka/                      # Kafka broker (KRaft mode)

- **kustomize** 5.0+ - Kubernetes manifest templating

- **helm** 3.12+ - Kubernetes package manager (for ArgoCD)│   └── examples/          # Example secret templates│   ├── deployment.yaml

- **terraform** 1.5+ - Infrastructure as Code (optional)

- **awscli** 2.13+ - AWS CLI (for cloud deployments)││   └── service.yaml           # Includes PVC



### Kubernetes Cluster├── terraform/             # Infrastructure as Code (future)├── schema-registry/            # Confluent Schema Registry



- **Local Development**: Docker Desktop, Minikube, or Kind│   ├── modules/           # Reusable Terraform modules│   ├── deployment.yaml

- **Cloud**: EKS, AKS, or GKE with appropriate IAM permissions

│   └── envs/              # Environment-specific configs│   └── service.yaml

### AWS Resources (for cloud deployments)

│├── redis/                      # Redis with modules

- AWS account with appropriate permissions

- AWS Secrets Manager for secret storage├── ci/                    # CI/CD pipelines│   ├── deployment.yaml

- IAM roles for service accounts (IRSA)

│   ├── github-actions/    # GitHub Actions workflows│   └── service.yaml           # Includes PVC

## 🚀 Quick Start

│   └── jenkins/           # Jenkins pipelines├── simulation/                 # PMS Simulation service

### Local Development Setup

││   ├── deployment.yaml

1. **Clone the repository:**

   ```bash├── scripts/               # Deployment and utility scripts│   └── service.yaml

   git clone https://github.com/your-org/pms-infra.git

   cd pms-infra│   ├── deploy-local.sh    # Deploy to local cluster├── trade-capture/              # Trade Capture service

   ```

│   └── destroy-local.sh   # Remove from local cluster│   ├── deployment.yaml

2. **Setup secrets:**

   ```bash││   └── service.yaml

   cp secrets/examples/secrets.env.example k8s/overlays-pms/local/secrets.env

   # Edit k8s/overlays-pms/local/secrets.env with working values
   # For local development, use the defaults shown in the comments or your own values└── docs/                  # Documentation├── validation/                 # Validation service

   ```

    ├── architecture.md    # System architecture│   ├── deployment.yaml

3. **Deploy to local Kubernetes:**

   ```bash    ├── local-setup.md     # Local development guide│   └── service.yaml

   ./scripts/deploy-local.sh

   ```    └── deployment.md      # Deployment procedures└── README.md                   # This file



4. **Verify deployment:**``````

   ```bash

   kubectl get pods -n pms

   ```

## Services## Prerequisites

5. **Access services:**

   - Trade Capture: http://localhost:8082

   - Simulation: http://localhost:4000

   - Validation: http://localhost:8080### Infrastructure1. **Local Kubernetes cluster** running (Docker Desktop or Minikube)

   - RabbitMQ UI: http://localhost:15672 (guest/guest)

### Production Secrets Setup

Before deploying to production, configure AWS Secrets Manager:

```bash
# Set up production database secrets
./scripts/setup-production-secrets.sh

# Verify secrets are created
aws secretsmanager list-secrets --filters Key=name,Values=pms/database/prod
```

**Production Database Configuration:**
- **RDS Endpoint:** `<YOUR_RDS_ENDPOINT>`
- **Database:** `<YOUR_DB_NAME>`
- **Username:** `<YOUR_DB_USERNAME>`
- **Region:** `<YOUR_AWS_REGION>`

**Note:** RabbitMQ credentials need to be configured separately in `pms/rabbitmq/prod`.

### Quick AWS Setup

1. **Prepare AWS environment:**
   ```bash
   ./scripts/prepare-aws-deployment.sh
   ```

2. **Deploy infrastructure:**
   ```bash
   cd terraform/envs/dev
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

3. **Configure ArgoCD:**
   ```bash
   # Install ArgoCD and configure applications
   # See AWS_DEPLOYMENT_GUIDE.md for detailed steps
   ```

4. **Deploy applications:**
   ```bash
   # ArgoCD will automatically deploy from Git
   argocd app sync trade-capture-dev
   ```

- **PostgreSQL 16** - Primary database2. **Docker images built** for application services:

## ⚙️ Configuration

- **RabbitMQ 3.13** - Message broker with Stream plugin   - `pms-simulation:latest`

### Environment Configuration

- **Kafka 7.5.0** - Event streaming (KRaft mode)   - `trade-capture:latest`

The repository supports multiple environments through Kustomize overlays:

- **Schema Registry 7.5.0** - Protobuf schema management   - `validation-service:latest`

| Environment | Namespace | Purpose | Secret Source |

|-------------|-----------|---------|---------------|- **Redis** - Caching layer (redislabs/redismod)

| `local` | `pms` | Local development | Local `secrets.env` |

| `dev` | `pms-dev` | Development | AWS Secrets Manager |### Build Docker Images

| `prod` | `pms` | Production | AWS Secrets Manager |

### Applications

### Service Configuration

- **Simulation** - Trade event generatorBefore deploying, build the application images:

#### Infrastructure Services

- **Trade Capture** - Ingests trades from RabbitMQ, publishes to Kafka

**PostgreSQL**

- **Image**: postgres:15-alpine- **Validation** - Validates trades from Kafka```bash

- **Port**: 5432

- **Storage**: 10Gi PVC# Build simulation service

- **Environment**: Configurable via secrets

## Deploymentcd pms-simulation

**RabbitMQ**

- **Image**: rabbitmq:3.12-management-alpinedocker build -t pms-simulation:latest .

- **Ports**: 5672 (AMQP), 15672 (Management UI)

- **Plugins**: rabbitmq_stream, rabbitmq_management### Local Kubernetes



**Redis**# Build trade-capture service

- **Image**: redis:7-alpine

- **Port**: 6379```bashcd ../pms-trade-capture

- **Storage**: 1Gi PVC

# Deploydocker build -t trade-capture:latest .

**Kafka**

- **Image**: confluentinc/cp-kafka:7.5.0./scripts/deploy-local.sh

- **Port**: 9092

- **Mode**: KRaft (no ZooKeeper)# Build validation service

- **Storage**: 10Gi PVC

# Verifycd ../pms-validation

**Schema Registry**

- **Image**: confluentinc/cp-schema-registry:7.5.0kubectl get pods -n pmsdocker build -t validation-service:latest -f docker/Dockerfile .

- **Port**: 8081

- **Dependencies**: Kafka, ZooKeeper```



#### Application Services# Check logs



**Trade Capture Service**kubectl logs -f deployment/trade-capture -n pms## Deploy Everything

- **Image**: pms/trade-capture:latest

- **Port**: 8082

- **Replicas**: 2 (prod), 1 (dev/local)

- **Resources**: 512Mi RAM, 500m CPU# DestroyApply all manifests at once:



**Simulation Service**./scripts/destroy-local.sh

- **Image**: pms/simulation:latest

- **Port**: 4000``````bash

- **Replicas**: 2 (prod), 1 (dev/local)

- **Resources**: 256Mi RAM, 200m CPUkubectl apply -f pms-infra/



**Validation Service**### Manual Deployment```

- **Image**: pms/validation:latest

- **Port**: 8080

- **Replicas**: 2 (prod), 1 (dev/local)

- **Resources**: 512Mi RAM, 500m CPU```bashThis will create:



### Secrets Configuration# Create secrets file- Namespace: `pms`



Secrets are managed through multiple methods:cp secrets/examples/secrets.env.example k8s/overlays-pms/local/secrets.env- Infrastructure: Postgres, RabbitMQ, Kafka, Schema Registry, Redis



#### Local Development- Applications: Simulation, Trade Capture, Validation

```bash

# k8s/overlays-pms/local/secrets.env# Apply with Kustomize

POSTGRES_USER=pms

POSTGRES_PASSWORD=secure_passwordkubectl apply -k k8s/overlays-pms/local## Check Status

POSTGRES_DB=pmsdb

RABBITMQ_DEFAULT_USER=guest

RABBITMQ_DEFAULT_PASS=guest

KAFKA_CLUSTER_ID=unique_cluster_id# VerifyCheck all pods:

```

kubectl get all -n pms

#### AWS Secrets Manager (Dev/Prod)

```json``````bash

{

  "pms/dev/database": {kubectl get pods -n pms

    "username": "pms_user",

    "password": "secure_password",## Development Workflow```

    "host": "rds-instance.dev.region.rds.amazonaws.com",

    "port": "5432",

    "dbname": "pmsdb"

  },1. **Make changes** to base manifests in `k8s/base/`Check all services:

  "pms/dev/rabbitmq": {

    "username": "pms_user",2. **Test locally** with `./scripts/deploy-local.sh`

    "password": "secure_password"

  }3. **Commit** only base manifests and overlay configs```bash

}

```4. **Never commit** `secrets.env` fileskubectl get services -n pms



## 🚢 Deployment```



### Local Deployment## Environment Variables



```bashCheck persistent volume claims:

# Deploy all services

./scripts/deploy-local.shAll applications read configuration from environment variables.



# Check status```bash

kubectl get pods -n pms

### Common Variables (non-sensitive)kubectl get pvc -n pms

# View logs

kubectl logs -f deployment/trade-capture -n pmsDefined in `k8s/overlays-pms/<env>/kustomization.yaml` via `configMapGenerator````



# Clean up

./scripts/destroy-local.sh

```### Secrets (sensitive)## View Logs



### ArgoCD DeploymentDefined in `k8s/overlays-pms/<env>/secrets.env` (gitignored) via `secretGenerator`



1. **Install ArgoCD:**View logs for a specific service:

   ```bash

   kubectl apply -f argocd/install/See `secrets/README.md` for details.

   ```

```bash

2. **Access ArgoCD UI:**

   ```bash## Prerequisites# Trade Capture

   kubectl port-forward svc/argocd-server -n argocd 8080:443

   # Open https://localhost:8080kubectl logs -n pms -l app=trade-capture -f

   ```

- Kubernetes cluster (Docker Desktop, Minikube, or cloud)

3. **Login and deploy applications:**

   - Default credentials: admin / password from logs- kubectl# Simulation

   - Applications are auto-created from `argocd/applications/`

- kustomize (or kubectl v1.14+)kubectl logs -n pms -l app=simulation -f

### Environment-Specific Deployment



```bash

# Development environment## Troubleshooting# Validation

kubectl apply -k k8s/overlays-pms/dev

kubectl logs -n pms -l app=validation-service -f

# Production environment

kubectl apply -k k8s/overlays-pms/prod### Pods not starting

```

```bash# Kafka

## 🔄 CI/CD

kubectl describe pod <pod-name> -n pmskubectl logs -n pms -l app=kafka -f

### GitHub Actions

kubectl logs <pod-name> -n pms```

Planned workflows in `ci/github-actions/`:

```

- **PR Validation**: Lint manifests, validate Kustomize, security scans

- **Dev Deployment**: Build images, update tags, deploy to dev## Delete Everything

- **Prod Deployment**: Promote images, deploy to prod with blue-green strategy

### Kafka/Schema Registry PORT errors

### Jenkins

See `docs/KAFKA_FIX_SUMMARY.md` for known issues and solutions.Remove all resources:

Jenkins pipeline configurations in `ci/jenkins/` for organizations preferring Jenkins over GitHub Actions.



### Image Management

### Secret not found```bash

- **Immutable Tags**: Use Git SHA for image tags

- **Registry**: ECR, GCR, or ACR depending on cloud providerEnsure `k8s/overlays-pms/<env>/secrets.env` exists and contains all required values.kubectl delete namespace pms

- **Promotion**: Dev → Staging → Prod tag promotion

```

## ☁️ Infrastructure

## Support

### Terraform Modules

This will delete the namespace and all resources inside it.

The `terraform/` directory contains reusable modules for:

See detailed documentation in `docs/`:

- **EKS Cluster**: Kubernetes control plane and node groups

- **RDS PostgreSQL**: Managed database instance- `local-setup.md` - Complete local setup guide## Service Communication

- **MSK**: Managed Kafka (Amazon MSK)

- **ElastiCache**: Redis cluster- `architecture.md` - System architecture and design

- **VPC**: Network configuration with private/public subnets

- `deployment.md` - Deployment procedures for all environmentsServices communicate using ClusterIP DNS names:

### Environment Configuration



```hcl

# terraform/envs/dev/main.tf## License- PostgreSQL: `postgres:5432`

module "eks" {

  source = "../../modules/eks"- RabbitMQ: `rabbitmq:5672` (AMQP), `rabbitmq:5552` (Stream)

  cluster_name = "pms-dev"

  node_groups = {Internal - Proprietary- Kafka: `kafka:19092` (internal), `kafka:9092` (external)

    general = {

      instance_types = ["t3.medium"]- Schema Registry: `schema-registry:8081`

      min_size       = 2- Redis: `redis:6379`

      max_size       = 10- Simulation: `simulation:4000`

    }- Trade Capture: `trade-capture:8082`

  }- Validation: `validation-service:8080`

}

## Notes

module "rds" {

  source = "../../modules/rds"- All deployments use exactly 1 replica

  identifier = "pms-dev-postgres"- No health checks, resource limits, or scaling

  engine    = "postgres"- Uses local Docker images with `imagePullPolicy: Never`

  engine_version = "15.4"- Persistent volumes for stateful services (Postgres, RabbitMQ, Kafka, Redis)

  instance_class = "db.t3.micro"- All services run in the `pms` namespace

}
```

## 🔒 Security

### Secret Management

- **Local**: Environment files (gitignored)
- **Cloud**: AWS Secrets Manager with External Secrets Operator
- **IRSA**: IAM Roles for Service Accounts for AWS access

### Network Security

- **Private Subnets**: Databases and internal services
- **Security Groups**: Minimal required access
- **Network Policies**: Kubernetes network segmentation

### Compliance

- **SRE Standards**: Resource limits, health probes, rolling updates
- **Security Scans**: Trivy for container vulnerabilities
- **Secret Scanning**: TruffleHog for credential detection

## 📊 Monitoring

### Prometheus & Grafana

ArgoCD application in `argocd/applications/monitoring.yaml`:

- **Prometheus**: Scrapes metrics from annotated services
- **Grafana**: Dashboards for application and infrastructure metrics
- **AlertManager**: Configurable alerting rules

### Health Checks

All services include:
- **Readiness Probes**: Container startup checks
- **Liveness Probes**: Container health checks
- **Startup Probes**: Initial application startup

### Logging

- **Application Logs**: Structured JSON logging
- **Infrastructure Logs**: Fluent Bit collection
- **Centralized**: Elasticsearch or CloudWatch Logs

## 🔧 Troubleshooting

### Common Issues

**Pods not starting:**
```bash
# Check pod status
kubectl get pods -n pms

# Check pod events
kubectl describe pod <pod-name> -n pms

# Check logs
kubectl logs <pod-name> -n pms
```

**Secrets not found:**
```bash
# Verify secrets exist
kubectl get secrets -n pms

# Check External Secrets Operator status
kubectl get externalsecret -n pms
```

**Service connectivity:**
```bash
# Test service DNS resolution
kubectl run test --image=busybox --rm -it -- nslookup postgres.pms.svc.cluster.local

# Test port connectivity
kubectl run test --image=busybox --rm -it -- telnet postgres.pms.svc.cluster.local 5432
```

### Debug Commands

```bash
# Port forward for local access
kubectl port-forward svc/trade-capture 8082:8082 -n pms

# Execute into container
kubectl exec -it deployment/trade-capture -n pms -- /bin/bash

# Check resource usage
kubectl top pods -n pms

# View cluster events
kubectl get events -n pms --sort-by=.metadata.creationTimestamp
```

## 🤝 Contributing

### Development Workflow

1. **Create Feature Branch:**
   ```bash
   git checkout -b feature/new-service
   ```

2. **Make Changes:**
   - Update manifests in `k8s/base/`
   - Test locally with `./scripts/deploy-local.sh`
   - Update documentation

3. **Create Pull Request:**
   - Ensure CI passes
   - Update ArgoCD applications if needed
   - Tag reviewers

### Code Standards

- **Manifests**: Follow Kubernetes best practices
- **Kustomize**: Use overlays for environment-specific changes
- **Secrets**: Never commit actual credentials
- **Documentation**: Update README for configuration changes

### Adding New Services

1. **Create base manifests:**
   ```bash
   mkdir -p k8s/base/apps/new-service
   # Add deployment.yaml, service.yaml, configmap.yaml
   ```

2. **Update base kustomization:**
   ```yaml
   # k8s/base/kustomization.yaml
   resources:
     - apps/new-service/
   ```

3. **Add environment overlays:**
   ```bash
   mkdir -p k8s/overlays-pms/{local,dev,prod}/new-service
   # Add patches for environment-specific config
   ```

4. **Create ArgoCD application:**
   ```yaml
   # argocd/applications/new-service-dev.yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: new-service-dev
   spec:
     source:
       path: k8s/overlays-pms/dev
     destination:
       namespace: pms-dev
   ```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/your-org/pms-infra/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-org/pms-infra/discussions)
- **Documentation**: [Internal Wiki](https://wiki.company.com/pms-infra)

---

**Last Updated**: January 5, 2026
**Version**: 2.0.0