# PMS Infrastructure Deployment Guide

This guide contains all the commands needed to deploy and manage the PMS (Portfolio Management System) infrastructure on AWS EKS.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Infrastructure Setup (Terraform)](#infrastructure-setup-terraform)
3. [Kubernetes Access](#kubernetes-access)
4. [ArgoCD Setup](#argocd-setup)
5. [Application Deployment](#application-deployment)
6. [Monitoring & Verification](#monitoring--verification)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools
```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

### AWS Configuration
```bash
# Configure AWS credentials
aws configure
# Enter your AWS Access Key ID, Secret Access Key, Region (us-east-1), and output format (json)

# Verify configuration
aws sts get-caller-identity
```

---

## Infrastructure Setup (Terraform)

### 1. Initialize and Deploy Infrastructure
```bash
cd terraform/environments/dev

# Initialize Terraform
terraform init

# Review the plan
terraform plan -out=tfplan

# Apply the infrastructure
terraform apply tfplan

# Note the outputs (cluster name, endpoint, etc.)
terraform output
```

### 2. Create AWS Secrets for Services

The following secrets need to be created in AWS Secrets Manager:

```bash
# Auth Service Secret
aws secretsmanager create-secret \
  --name "pms/dev/auth" \
  --description "PMS Auth Service secrets for dev environment" \
  --region us-east-1

# Apply Terraform to populate secret values
terraform apply -target=data.aws_secretsmanager_secret.auth -target=aws_secretsmanager_secret_version.auth -auto-approve

# Verify the secret
aws secretsmanager get-secret-value --secret-id "pms/dev/auth" --region us-east-1 --query SecretString --output text | jq .
```

**All Required Secrets:**
- `pms/dev/auth` - Auth service credentials
- `pms/dev/simulation` - Simulation service credentials
- `pms/dev/trade-capture` - Trade capture service credentials
- `pms/dev/validation` - Validation service credentials
- `pms/dev/database` - PostgreSQL credentials
- `pms/dev/kafka` - Kafka credentials
- `pms/dev/rabbitmq` - RabbitMQ credentials
- `pms/dev/redis` - Redis credentials
- `pms/dev/schema-registry` - Schema Registry credentials

---

## Kubernetes Access

### 1. Configure kubectl
```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name pms-dev

# Verify connection
kubectl get nodes
kubectl get namespaces
```

### 2. Create PMS Namespace
```bash
kubectl create namespace pms
```

---

## ArgoCD Setup

### 1. Install ArgoCD
```bash
# Create ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD using kustomize
cd argocd/install
kubectl apply -k .

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
```

### 2. Expose ArgoCD Server
```bash
# Expose via LoadBalancer
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Get ArgoCD URL
export ARGOCD_URL=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "ArgoCD URL: http://$ARGOCD_URL"
```

### 3. Get ArgoCD Admin Credentials
```bash
# Get admin password
export ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo "=== ArgoCD Access ==="
echo "URL: http://$ARGOCD_URL"
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"
```

### 4. Create ArgoCD Project and Application
```bash
# Create PMS Project
kubectl apply -f argocd/projects/pms-project.yaml

# Create PMS Platform Application
kubectl apply -f argocd/applications/pms-platform.yaml

# Check application status
kubectl get applications -n argocd
```

---

## Application Deployment

### Option 1: Deploy via Helm (Direct)

```bash
cd k8s/pms-platform

# Install/Upgrade the entire platform
helm upgrade --install pms-platform . -n pms

# Check deployment status
kubectl get pods -n pms
```

### Option 2: Deploy via ArgoCD (GitOps - Recommended)

```bash
# Sync the application
kubectl patch application pms-platform -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'

# Or use ArgoCD CLI
argocd app sync pms-platform

# Watch sync progress
kubectl get applications -n argocd -w
```

### Individual Service Deployment

If you need to deploy individual services:

```bash
# Auth Service
helm upgrade --install auth k8s/charts/services/auth -n pms

# API Gateway
helm upgrade --install apigateway k8s/charts/services/apigateway -n pms

# Simulation Service
helm upgrade --install simulation k8s/charts/services/simulation -n pms

# Trade Capture Service
helm upgrade --install trade-capture k8s/charts/services/trade-capture -n pms

# Validation Service
helm upgrade --install validation k8s/charts/services/validation -n pms
```

---

## Monitoring & Verification

### Check Pod Status
```bash
# All pods in pms namespace
kubectl get pods -n pms

# Watch pods in real-time
kubectl get pods -n pms -w

# Describe a specific pod
kubectl describe pod <pod-name> -n pms
```

### Check Logs
```bash
# View logs for a service
kubectl logs -n pms -l app=auth --tail=100

# Follow logs
kubectl logs -n pms -l app=simulation -f

# Logs from all containers in a pod
kubectl logs -n pms <pod-name> --all-containers=true
```

### Check Services
```bash
# List all services
kubectl get svc -n pms

# Get service details
kubectl describe svc auth -n pms
```

### Check Secrets
```bash
# List secrets
kubectl get secrets -n pms

# Describe ExternalSecrets
kubectl get externalsecret -n pms
kubectl describe externalsecret auth-secrets -n pms
```

### Port Forwarding for Testing
```bash
# Forward auth service
kubectl port-forward -n pms svc/auth 8081:8081

# Forward simulation service
kubectl port-forward -n pms svc/simulation 8090:8090

# Forward API gateway
kubectl port-forward -n pms svc/apigateway 8080:8080
```

---

## Troubleshooting

### Pod Not Starting

```bash
# Check pod events
kubectl describe pod <pod-name> -n pms

# Check init container logs
kubectl logs <pod-name> -n pms -c wait-for-postgres

# Check application logs
kubectl logs <pod-name> -n pms
```

### Secret Sync Issues

```bash
# Check ExternalSecret status
kubectl get externalsecret -n pms auth-secrets -o yaml

# Force sync
kubectl annotate externalsecret -n pms auth-secrets force-sync=$(date +%s) --overwrite

# Check ClusterSecretStore
kubectl get clustersecretstore aws-secretsmanager -o yaml
```

### Image Pull Issues

```bash
# Delete pod to force image pull
kubectl delete pod <pod-name> -n pms

# Restart deployment
kubectl rollout restart deployment <deployment-name> -n pms

# Check deployment status
kubectl rollout status deployment <deployment-name> -n pms
```

### Health Check Issues

Health checks are currently disabled in values.yaml. To re-enable:

```bash
# Edit umbrella chart values
vim k8s/pms-platform/values.yaml

# Set healthChecks.enabled: true for each service
# Then upgrade
helm upgrade pms-platform k8s/pms-platform -n pms
```

### Database Connection Issues

```bash
# Check if postgres is running
kubectl get pods -n pms -l app=postgres

# Check postgres logs
kubectl logs -n pms -l app=postgres

# Test connection from a pod
kubectl exec -n pms <pod-name> -- nc -zv postgres 5432
```

### ArgoCD Sync Issues

```bash
# Check application status
kubectl get application pms-platform -n argocd -o yaml

# Force sync
kubectl patch application pms-platform -n argocd --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'

# Delete and recreate application
kubectl delete application pms-platform -n argocd
kubectl apply -f argocd/applications/pms-platform.yaml
```

---

## Cleanup

### Remove Applications
```bash
# Via Helm
helm uninstall pms-platform -n pms

# Via ArgoCD
kubectl delete application pms-platform -n argocd
```

### Remove ArgoCD
```bash
kubectl delete -k argocd/install
kubectl delete namespace argocd
```

### Destroy Infrastructure
```bash
cd terraform/environments/dev

# Destroy all resources
terraform destroy -auto-approve

# Clean up Terraform state
rm -rf .terraform
rm terraform.tfstate*
```

---

## Quick Reference

### Common Commands

```bash
# Get all resources in pms namespace
kubectl get all -n pms

# Check cluster info
kubectl cluster-info

# Get events
kubectl get events -n pms --sort-by='.lastTimestamp'

# Exec into a pod
kubectl exec -it <pod-name> -n pms -- /bin/sh

# Copy files from/to pod
kubectl cp <pod-name>:/path/to/file ./local-file -n pms
kubectl cp ./local-file <pod-name>:/path/to/file -n pms

# Scale deployment
kubectl scale deployment <deployment-name> -n pms --replicas=3
```

### Environment Variables

```bash
# Export commonly used values
export KUBECONFIG=~/.kube/config
export ARGOCD_URL=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
export ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
```

---

## Service Endpoints

### Internal (ClusterIP)
- **Auth Service**: `http://auth:8081`
- **API Gateway**: `http://apigateway:8080`
- **Simulation**: `http://simulation:8090`
- **Trade Capture**: `http://trade-capture:8091`
- **Validation**: `http://validation-service:8092`
- **PostgreSQL**: `postgres:5432`
- **RabbitMQ**: `rabbitmq:5552` (Stream), `rabbitmq:5672` (AMQP)
- **Redis**: `redis:6379`
- **Kafka**: `kafka:9092`

### External (LoadBalancer/Port-Forward)
Access services via port-forwarding or LoadBalancer as configured.

---

## Version Information

- **Kubernetes**: 1.31
- **Helm**: 3.x
- **ArgoCD**: Latest stable
- **Terraform**: 1.x
- **AWS Provider**: Latest stable

---

## Support & Documentation

- **Repository**: https://github.com/pms-org/pms-infra
- **Issues**: https://github.com/pms-org/pms-infra/issues
- **Kubernetes Docs**: https://kubernetes.io/docs/
- **ArgoCD Docs**: https://argo-cd.readthedocs.io/
- **Helm Docs**: https://helm.sh/docs/

---

*Last Updated: January 12, 2026*
