# GitHub Actions Workflows

## Overview
This directory will contain GitHub Actions workflow definitions for CI/CD automation.

## Planned Workflows

### 1. PR Validation (`pr-validation.yml`)
**Trigger:** Pull Request to main/master

**Jobs:**
- Lint Kubernetes manifests (kubeval/kube-linter)
- Validate Kustomize build
- Check for secrets in code (trufflehog/gitleaks)
- Run security scans (trivy)

### 2. Deploy to Dev (`deploy-dev.yml`)
**Trigger:** Push to main/master

**Jobs:**
- Build and push Docker images
- Update image tags in k8s/overlays/dev
- Apply to dev cluster
- Run smoke tests

### 3. Deploy to Prod (`deploy-prod.yml`)
**Trigger:** Manual workflow dispatch or tag push

**Jobs:**
- Promote images from dev
- Update image tags in k8s/overlays/prod
- Apply to prod cluster (blue-green deployment)
- Run integration tests
- Notify team

## Example Workflow Structure

```yaml
name: Deploy to Dev

on:
  push:
    branches: [main, master]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup kubectl
        uses: azure/setup-kubectl@v3
        
      - name: Apply manifests
        run: |
          kubectl apply -k k8s/overlays/dev
```

## Secrets Required

GitHub repository secrets:
- `KUBE_CONFIG_DEV` - kubeconfig for dev cluster
- `KUBE_CONFIG_PROD` - kubeconfig for prod cluster
- `DOCKER_USERNAME` - Docker Hub username
- `DOCKER_TOKEN` - Docker Hub access token

## Next Steps

1. Define workflow YAML files
2. Configure GitHub secrets
3. Set up branch protection rules
4. Test workflows in feature branch
