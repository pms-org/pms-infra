# PMS Infrastructure - Helm Charts

This directory contains industry-standard Helm charts for deploying the PMS (Portfolio Management System) infrastructure to Kubernetes.

## Architecture

The Helm setup follows these principles:

- **One service = one Helm chart**: Each microservice has its own chart
- **Environment separation**: Configuration varies by environment (dev/prod)
- **External secrets**: Secrets managed via AWS Secrets Manager and External Secrets Operator
- **Infrastructure independence**: Infra services can be enabled/disabled independently

## Structure

```
k8s/
├── charts/
│   ├── platform/          # Cluster-wide components
│   │   └── external-secrets/  # ESO with AWS Secrets Manager
│   ├── infra/             # ✅ Stateful infrastructure
│   │   ├── kafka/         # ✅ Apache Kafka
│   │   ├── postgres/      # ✅ PostgreSQL database
│   │   ├── rabbitmq/      # ✅ RabbitMQ with stream plugin
│   │   ├── redis/         # ✅ Redis with modules
│   │   └── schema-registry/ # ✅ Confluent Schema Registry
│   └── services/          # Application microservices
│       ├── simulation/    # ✅ Complete
│       ├── trade-capture/ # ✅ Complete
│       └── validation/    # ✅ Complete
├── environments/          # Environment-specific values
│   ├── dev/               # ✅ Complete
│   └── prod/              # ✅ Complete
└── README.md              # ✅ Complete
```

## Prerequisites

- Kubernetes cluster (EKS recommended)
- Helm 3.x
- AWS CLI configured
- IRSA enabled on EKS cluster
- AWS Secrets Manager secrets created

## Quick Start

### 1. Install External Secrets Operator

```bash
# For development
helm upgrade --install external-secrets ./charts/platform/external-secrets \
  -f environments/dev/values.yaml

# For production
helm upgrade --install external-secrets ./charts/platform/external-secrets \
  -f environments/prod/values.yaml
```

### 2. Install Infrastructure Services

```bash
# Install infrastructure services for development
helm upgrade --install postgres ./charts/infra/postgres \
  -f environments/dev/values.yaml

helm upgrade --install kafka ./charts/infra/kafka \
  -f environments/dev/values.yaml

helm upgrade --install rabbitmq ./charts/infra/rabbitmq \
  -f environments/dev/values.yaml

helm upgrade --install redis ./charts/infra/redis \
  -f environments/dev/values.yaml

helm upgrade --install schema-registry ./charts/infra/schema-registry \
  -f environments/dev/values.yaml
```

### 3. Install Services

```bash
# Install all services for development
helm upgrade --install simulation ./charts/services/simulation \
  -f environments/dev/values.yaml

helm upgrade --install trade-capture ./charts/services/trade-capture \
  -f environments/dev/values.yaml

helm upgrade --install validation ./charts/services/validation \
  -f environments/dev/values.yaml
```

## Validation

Test your Helm charts:

```bash
# Lint all charts
helm lint ./charts/platform/external-secrets
helm lint ./charts/infra/postgres
helm lint ./charts/infra/kafka
helm lint ./charts/services/simulation

# Template generation (dry-run)
helm template postgres ./charts/infra/postgres \
  -f environments/dev/values.yaml

helm template simulation ./charts/services/simulation \
  -f environments/dev/values.yaml
```

## Migration from Kustomize

This Helm setup replaces the previous Kustomize-based configuration:

- **Backup**: Original Kustomize configs preserved in `k8s-backup/`
- **Rollback**: Can restore from `k8s-backup/` if needed
- **Equivalence**: Helm charts produce identical Kubernetes resources

## Security Model

- **No secrets in Helm values**: All secrets externalized to AWS Secrets Manager
- **IRSA authentication**: External Secrets Operator uses IAM roles for service accounts
- **Environment isolation**: Separate secret paths per environment (`pms/{service}/{env}`)

## Development

### Adding a New Service

1. Create chart directory: `charts/services/{service-name}/`
2. Add `Chart.yaml` and `values.yaml`
3. Create templates in `templates/` directory
4. Add environment overrides in `environments/*/values.yaml`

### Modifying Configuration

- **Non-secret config**: Update `values.yaml` in service chart
- **Secret config**: Update AWS Secrets Manager and ExternalSecret mappings
- **Environment differences**: Override in `environments/*/values.yaml`

## Troubleshooting

### Common Issues

1. **External Secrets not syncing**: Check IRSA role permissions
2. **Services can't connect**: Verify infrastructure services are running
3. **Image pull errors**: Check image registry access

### Logs

```bash
# Check ESO controller logs
kubectl logs -n external-secrets-system deployment/external-secrets-controller

# Check service logs
kubectl logs -n pms deployment/simulation
```

## Contributing

- Follow Helm best practices
- Keep charts DRY (Don't Repeat Yourself)
- Test changes in development environment first
- Update documentation for configuration changes