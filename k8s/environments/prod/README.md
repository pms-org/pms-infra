# Production Environment

This directory contains configuration specific to the production environment.

## Usage

To deploy to production environment:

```bash
# Install External Secrets Operator
helm upgrade --install external-secrets ./charts/platform/external-secrets \
  -f environments/prod/values.yaml

# Install services with production scaling
helm upgrade --install simulation ./charts/services/simulation \
  -f environments/prod/values.yaml

helm upgrade --install trade-capture ./charts/services/trade-capture \
  -f environments/prod/values.yaml

helm upgrade --install validation ./charts/services/validation \
  -f environments/prod/values.yaml
```

## Prerequisites

- EKS cluster with IRSA enabled
- AWS Secrets Manager secrets created with appropriate paths
- External Secrets Operator IRSA role configured
- Production-grade infrastructure (RDS, MSK, ElastiCache, etc.)

## Configuration

- **AWS Region**: us-east-1
- **Secrets Path Pattern**: `pms/{service}/prod`
- **Namespace**: pms
- **High Availability**: Multiple replicas, increased resources
- **Security**: Production secrets paths

## Important Notes

- Production deployments use higher replica counts for availability
- Resource limits are increased for production workloads
- Secrets are stored in production-specific AWS Secrets Manager paths
- Consider using managed AWS services (RDS, MSK, ElastiCache) in production