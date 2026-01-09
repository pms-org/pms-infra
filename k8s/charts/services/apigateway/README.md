# PMS API Gateway Helm Chart

This Helm chart deploys the PMS API Gateway microservice.

## Prerequisites

- Kubernetes cluster
- Helm 3.x
- External Secrets Operator (for secrets management)
- AWS Secrets Manager (if using secrets)

## Installation

```bash
helm install apigateway ./chart
```

## Configuration

The following table lists the configurable parameters of the apigateway chart and their default values.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.name` | Service name | `apigateway` |
| `service.namespace` | Namespace | `pms` |
| `service.port` | Service port | `8080` |
| `service.targetPort` | Container port | `8080` |
| `service.type` | Service type | `ClusterIP` |
| `deployment.replicas` | Number of replicas | `1` |
| `deployment.image.repository` | Image repository | `niishantdev/pms-apigateway` |
| `deployment.image.tag` | Image tag | `latest` |
| `deployment.image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `deployment.resources.requests.cpu` | CPU requests | `100m` |
| `deployment.resources.requests.memory` | Memory requests | `256Mi` |
| `deployment.resources.limits.cpu` | CPU limits | `500m` |
| `deployment.resources.limits.memory` | Memory limits | `1Gi` |
| `config.*` | Application configuration | See values.yaml |
| `secrets.path` | AWS Secrets Manager path | `pms/dev/apigateway` |
| `secrets.refreshInterval` | Secrets refresh interval | `1h` |

## Dependencies

- Redis (for rate limiting)
- Auth service (for JWT issuer)

## Secrets

If secrets are required, configure the `secrets.data` array in values.yaml.