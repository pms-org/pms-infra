# Development Environment

This directory contains configuration specific to the development environment.

## Usage

To deploy to development environment:

```bash
# Install External Secrets Operator
helm upgrade --install external-secrets ./charts/platform/external-secrets \
  -f environments/dev/values.yaml

# Install services
helm upgrade --install simulation ./charts/services/simulation \
  -f environments/dev/values.yaml

helm upgrade --install trade-capture ./charts/services/trade-capture \
  -f environments/dev/values.yaml

helm upgrade --install validation ./charts/services/validation \
  -f environments/dev/values.yaml
```

## Prerequisites

- EKS cluster with IRSA enabled
- AWS Secrets Manager secrets created with appropriate paths
- External Secrets Operator IRSA role configured

## Configuration

- **AWS Region**: us-east-1
- **Secrets Path Pattern**: `pms/{service}/dev`
- **Namespace**: pms