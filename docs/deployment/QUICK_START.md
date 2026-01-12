# PMS Infrastructure - Quick Start Guide

This is a condensed guide to quickly get the PMS infrastructure up and running.

## Prerequisites

- AWS CLI configured with credentials
- kubectl, helm, and terraform installed
- Access to AWS account with appropriate permissions

## 1. Deploy Infrastructure (5-10 minutes)

```bash
cd terraform/environments/dev
terraform init
terraform apply -auto-approve
```

## 2. Configure Kubernetes Access

```bash
aws eks update-kubeconfig --region us-east-1 --name pms-dev
kubectl create namespace pms
```

## 3. Create AWS Secrets

```bash
# Create auth secret
aws secretsmanager create-secret --name "pms/dev/auth" --region us-east-1

# Populate with Terraform
terraform apply -target=aws_secretsmanager_secret_version.auth -auto-approve
```

## 4. Install ArgoCD

```bash
kubectl create namespace argocd
cd ../../argocd/install
kubectl apply -k .
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
```

## 5. Deploy PMS Platform

```bash
# Create ArgoCD project
kubectl apply -f ../projects/pms-project.yaml

# Create ArgoCD application
kubectl apply -f ../applications/pms-platform.yaml

# OR deploy directly with Helm
cd ../../k8s/pms-platform
helm upgrade --install pms-platform . -n pms
```

## 6. Get Access Information

```bash
# ArgoCD
echo "ArgoCD URL: http://$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo "Username: admin"
echo "Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"

# Check services
kubectl get pods -n pms
kubectl get svc -n pms
```

## 7. Verify Deployment

```bash
# All pods should be Running
kubectl get pods -n pms

# Expected output:
# apigateway-xxx    1/1     Running
# auth-xxx          1/1     Running
# simulation-xxx    1/1     Running
# trade-capture-xxx 1/1     Running
# validation-xxx    1/1     Running
# postgres-xxx      1/1     Running
# rabbitmq-xxx      1/1     Running
# redis-xxx         1/1     Running
# kafka-xxx         1/1     Running
```

## Cleanup

```bash
# Delete applications
helm uninstall pms-platform -n pms

# Delete ArgoCD
kubectl delete -k argocd/install
kubectl delete namespace argocd

# Destroy infrastructure
cd terraform/environments/dev
terraform destroy -auto-approve
```

## Troubleshooting

### Pods not starting?
```bash
kubectl describe pod <pod-name> -n pms
kubectl logs <pod-name> -n pms
```

### Secrets not syncing?
```bash
kubectl get externalsecret -n pms
kubectl annotate externalsecret -n pms auth-secrets force-sync=$(date +%s) --overwrite
```

### Need to restart a service?
```bash
kubectl rollout restart deployment <service-name> -n pms
```

For detailed documentation, see [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)
