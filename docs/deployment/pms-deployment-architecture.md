# PMS Platform Deployment Architecture

## Overview

The PMS (Portfolio Management System) is a microservices-based platform deployed on AWS EKS using GitOps principles. This document describes the complete runtime deployment architecture, including infrastructure provisioning, deployment management, and application topology.

## Architecture Layers

### 1. Infrastructure Provisioning Layer (Terraform)

**Purpose**: Provisions the underlying AWS infrastructure and Kubernetes cluster.

**Components**:
- **VPC**: Multi-AZ VPC with public/private/database subnets
- **EKS Cluster**: Managed Kubernetes control plane with worker nodes
- **RDS PostgreSQL**: Managed database instance with automated backups
- **Security Groups**: Network access controls for all components
- **IAM Roles**: Service accounts for EKS and external integrations

**Key Resources**:
```
terraform/
├── environments/
│   ├── dev/main.tf          # Development environment
│   └── prod/main.tf         # Production environment
└── modules/
    ├── vpc/                 # VPC and subnet configuration
    ├── eks/                 # EKS cluster and node groups
    ├── rds/                 # PostgreSQL database
    └── irsa/                # IAM roles for service accounts
```

**Data Flow**:
```
Terraform State → AWS Resources → EKS Cluster Ready
```

### 2. GitOps Control Plane (ArgoCD)

**Purpose**: Manages declarative deployments and maintains desired state.

**Components**:
- **ArgoCD Server**: Web UI and API server in `argocd` namespace
- **Application Controller**: Monitors and syncs applications
- **Repository Server**: Clones and processes manifests
- **Dex**: Authentication provider (optional)

**Key Resources**:
```
argocd/
├── install/kustomization.yaml    # ArgoCD installation
├── applications/
│   └── pms-platform.yaml         # Main application manifest
└── projects/
    └── pms-project.yaml          # Project permissions and destinations
```

**Deployment Flow**:
```
Git Push → ArgoCD Detects Change → Helm Template → K8s Apply
```

### 3. Platform Orchestration Layer (Helm Umbrella)

**Purpose**: Coordinates deployment of all platform components and services.

**Components**:
- **pms-platform Chart**: Parent Helm chart with subchart dependencies
- **Global ConfigMap**: Shared configuration values
- **Global Secrets**: Shared secret references

**Chart Structure**:
```
k8s/pms-platform/
├── Chart.yaml                 # Chart metadata and dependencies
├── values.yaml               # Default values
├── charts/                   # Subchart symlinks
└── templates/                # Global resources
    ├── global-configmap.yaml
    └── global-secrets.yaml
```

**Dependencies** (from Chart.yaml):
```
Infrastructure:
├── postgres (Bitnami PostgreSQL)
├── redis (Bitnami Redis)
├── kafka (Bitnami Kafka)
├── rabbitmq (Bitnami RabbitMQ)
└── schema-registry (Confluent Schema Registry)

Platform:
└── external-secrets (External Secrets Operator)

Services:
├── apigateway
├── auth
├── simulation
├── trade-capture
├── validation
├── analytics
├── portfolio
├── transactional
├── leaderboard (disabled)
├── crosscutting (disabled)
├── rttm (disabled)
└── frontend (disabled)
```

### 4. Infrastructure Services Layer

**Purpose**: Provides shared infrastructure components for application services.

#### PostgreSQL (Stateful)
- **Purpose**: Primary database for transactional data
- **Configuration**: Single instance with persistent volumes
- **Access**: Internal service discovery (`postgres:5432`)
- **Backup**: Automated snapshots via RDS

#### Redis + Sentinel (Stateful)
- **Purpose**: Distributed cache and session store
- **Configuration**: Master-replica with Sentinel for HA
- **Access**: Internal service discovery (`redis:6379`)
- **Features**: Redis modules for advanced data structures

#### Kafka + Schema Registry (Stateful)
- **Purpose**: Event streaming and schema management
- **Configuration**: Single broker with ZooKeeper
- **Access**: Internal service discovery (`kafka:9092`, `schema-registry:8081`)
- **Features**: Confluent Schema Registry for Avro/Protobuf schemas

#### RabbitMQ (Stateful)
- **Purpose**: Message queuing with streaming support
- **Configuration**: Single instance with stream plugin
- **Access**: Internal service discovery (`rabbitmq:5672`, `rabbitmq:5552`)
- **Features**: AMQP and stream protocols for different use cases

#### External Secrets Operator (Stateless)
- **Purpose**: Synchronizes AWS Secrets Manager secrets to Kubernetes
- **Configuration**: Cluster-wide SecretStore for AWS SM
- **Access**: Creates secrets in application namespaces
- **Security**: IRSA (IAM Roles for Service Accounts)

### 5. Application Services Layer

**Namespace**: `pms`
**Deployment Pattern**: Each service is a Helm subchart with standardized templates

#### API Gateway (apigateway)
- **Purpose**: Single entry point for external API calls
- **Technology**: Spring Boot with Spring Cloud Gateway
- **Dependencies**: Redis (caching), Auth service
- **Ports**: 8080 (internal), 80/443 (external via LoadBalancer)
- **Features**: Rate limiting, CORS, authentication routing

#### Auth Service (auth)
- **Purpose**: User authentication and authorization
- **Technology**: Spring Boot with OAuth2/JWT
- **Dependencies**: PostgreSQL
- **Ports**: 8081 (internal)
- **Features**: JWT token issuance, user management

#### Simulation Service (simulation)
- **Purpose**: Portfolio simulation and modeling
- **Technology**: Spring Boot
- **Dependencies**: PostgreSQL, RabbitMQ (streams), Kafka, Schema Registry
- **Ports**: 8090 (internal)
- **Features**: Real-time simulation processing

#### Trade Capture Service (trade-capture)
- **Purpose**: Trade data ingestion and processing
- **Technology**: Spring Boot
- **Dependencies**: PostgreSQL, RabbitMQ (streams), Kafka, Schema Registry, Redis
- **Ports**: 8082 (internal)
- **Features**: Batch processing, event publishing

#### Validation Service (validation)
- **Purpose**: Trade validation and compliance checking
- **Technology**: Spring Boot
- **Dependencies**: PostgreSQL, Redis, Kafka, Schema Registry
- **Ports**: 8080 (internal)
- **Features**: Real-time validation, caching

#### Additional Services
- **Analytics**: Data analytics and reporting
- **Portfolio**: Portfolio management operations
- **Transactional**: Transaction processing
- **Leaderboard**: Performance rankings (disabled)
- **Crosscutting**: Shared business logic (disabled)
- **RTTM**: Real-time trade monitoring (disabled)
- **Frontend**: Web UI (disabled)

### 6. Data and Event Flow Layer

#### Synchronous Communication (REST)
```
User → LoadBalancer → API Gateway → Auth Service → JWT Token
API Gateway → Simulation Service → Portfolio Data
API Gateway → Analytics Service → Reports
```

#### Asynchronous Communication (Events)
```
Trade Capture → Kafka (raw-trades-topic) → Validation Service
Validation → Kafka (valid-trades-topic) → Downstream Consumers
Validation → Kafka (invalid-trades-topic) → Error Handling
```

#### Message Queue Communication (Streams)
```
Simulation → RabbitMQ Stream (trade-stream) → Trade Capture
Trade Capture → RabbitMQ Stream (trade-stream) → Analytics
```

#### Database Access
```
All Services → PostgreSQL (pmsdb)
├── Auth: user_sessions, credentials
├── Simulation: portfolios, scenarios
├── Trade Capture: trades, batches
├── Validation: validation_rules, results
└── Analytics: aggregated_data, reports
```

#### Caching Layer
```
API Gateway → Redis (session cache, rate limits)
Validation → Redis (validation cache, rules)
Analytics → Redis (computed results)
```

#### Secret Management
```
AWS Secrets Manager → External Secrets Operator → Kubernetes Secrets
├── Global Secrets: DB credentials, Redis password
├── Service Secrets: API keys, JWT secrets, service-specific credentials
└── Access Pattern: envFrom.secretRef in pod specs
```

## Deployment Environments

### Development Environment
- **Namespace**: `pms-dev`
- **Cluster**: `pms-dev-cluster`
- **Configuration**: Full stack with development optimizations
- **Secrets Path**: `pms/*/dev`

### Production Environment
- **Namespace**: `pms-prod`
- **Cluster**: `pms-prod-cluster`
- **Configuration**: Production hardening, HA setup
- **Secrets Path**: `pms/*/prod`

## CI/CD Pipeline

### GitHub Actions Workflows
```
Git Push/PR → Lint & Validate → Build Images → Deploy to Dev → Integration Tests → Manual Prod Deploy
```

### Key Pipeline Stages
1. **PR Validation**: Kubeval, security scanning, secret detection
2. **Image Building**: Multi-stage Docker builds with security scanning
3. **Dev Deployment**: Automatic deployment to dev environment
4. **Prod Deployment**: Manual promotion with blue-green strategy

## Monitoring and Observability

### Components (Planned)
- **Prometheus**: Metrics collection
- **Grafana**: Visualization dashboards
- **Loki**: Log aggregation
- **Tempo**: Distributed tracing
- **AlertManager**: Alert routing

### Service Health Checks
- **Readiness Probes**: Application startup verification
- **Liveness Probes**: Application health monitoring
- **Startup Probes**: Slow-starting service handling

## Security Architecture

### Network Security
- **VPC Isolation**: Private subnets for workloads
- **Security Groups**: Least-privilege access controls
- **IRSA**: AWS IAM integration for pod-level permissions

### Secret Management
- **AWS Secrets Manager**: Centralized secret storage
- **External Secrets Operator**: Kubernetes-native secret synchronization
- **Rotation**: Automated secret rotation and pod restarts

### Access Control
- **ArgoCD RBAC**: Deployment permissions by team/role
- **Kubernetes RBAC**: Service account permissions
- **AWS IAM**: Infrastructure access controls

## Scaling and High Availability

### Infrastructure Scaling
- **EKS Node Groups**: Auto-scaling based on resource utilization
- **RDS**: Multi-AZ deployment with read replicas
- **Load Balancing**: AWS ALB for external traffic

### Application Scaling
- **Horizontal Pod Autoscaling**: CPU/memory-based scaling
- **Kafka Partitioning**: Event processing scalability
- **Redis Clustering**: Cache distribution

### Disaster Recovery
- **Multi-AZ Deployment**: Cross-availability zone redundancy
- **Backup Strategy**: Automated database and configuration backups
- **Failover Procedures**: Documented recovery processes

## Operational Procedures

### Deployment Process
1. **Infrastructure**: Terraform apply for environment setup
2. **ArgoCD**: Application creation and sync
3. **Services**: Helm upgrade through ArgoCD
4. **Verification**: Health checks and smoke tests

### Rollback Strategy
1. **ArgoCD**: Sync to previous git commit
2. **Helm**: Rollback to previous release
3. **Database**: Point-in-time recovery if needed

### Troubleshooting
- **ArgoCD UI**: Deployment status and logs
- **kubectl**: Direct cluster inspection
- **AWS Console**: Infrastructure monitoring
- **Application Logs**: Service-specific debugging

---

*This document serves as the authoritative reference for PMS deployment architecture and should be updated with any architectural changes.*