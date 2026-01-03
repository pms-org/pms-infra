# PMS EKS Deployment Playbook

**Minimal, step-by-step guide to deploy PMS to AWS EKS**

This playbook evolves the existing `pms-infra` for EKS deployment while keeping local development intact.

---

## 📋 Prerequisites

- AWS CLI configured with appropriate credentials
- kubectl installed
- Terraform >= 1.5.0
- Helm >= 3.0

```bash
# Verify tools
aws sts get-caller-identity
terraform version
kubectl version --client
helm version
```

---

## 🏗️ Phase 1: Deploy AWS Infrastructure

### Step 1.1: Navigate to Terraform directory

```bash
cd pms-infra/terraform/envs/dev
```

### Step 1.2: Initialize Terraform

```bash
terraform init
```

### Step 1.3: Review the plan

```bash
terraform plan -out=tfplan
```

**What this creates:**
- VPC with 2 AZs (public + private subnets)
- EKS cluster (1.28) with managed node group (2-6 nodes, t3.large)
- RDS PostgreSQL 16.1 (db.t3.medium, single-AZ for dev)
- IAM roles for:
  - EBS CSI Driver
  - AWS Load Balancer Controller
  - External Secrets Operator
- AWS Load Balancer Controller (via Helm)
- Secrets Manager secret for RDS credentials

### Step 1.4: Apply infrastructure

```bash
terraform apply tfplan
```

⏱️ **Estimated time: 15-20 minutes**

### Step 1.5: Capture outputs

```bash
terraform output -json > outputs.json

# Important values
terraform output update_kubeconfig_command
terraform output external_secrets_role_arn
terraform output aws_account_id
terraform output rds_endpoint
```

---

## ⚙️ Phase 2: Configure kubectl

### Step 2.1: Update kubeconfig

```bash
aws eks update-kubeconfig --region us-east-1 --name pms-dev
```

### Step 2.2: Verify cluster access

```bash
kubectl get nodes
kubectl get pods -n kube-system
```

Expected: 2-3 nodes in Ready state

---

## 🔐 Phase 3: Install External Secrets Operator

### Step 3.1: Install via Helm

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm install external-secrets \
  external-secrets/external-secrets \
  -n external-secrets-system \
  --create-namespace \
  --set installCRDs=true
```

### Step 3.2: Verify installation

```bash
kubectl get pods -n external-secrets-system
kubectl get crd | grep external-secrets
```

Expected: external-secrets-* pod running, CRDs installed

---

## 📝 Phase 4: Update Kubernetes Manifests with Real Values

### Step 4.1: Get AWS Account ID and IAM Role ARN

```bash
export AWS_ACCOUNT_ID=$(terraform output -raw aws_account_id)
export CLUSTER_NAME="pms-dev"
export EXTERNAL_SECRETS_ROLE_ARN=$(terraform output -raw external_secrets_role_arn)

echo "Account ID: $AWS_ACCOUNT_ID"
echo "Role ARN: $EXTERNAL_SECRETS_ROLE_ARN"
```

### Step 4.2: Update ServiceAccount annotation

Edit `pms-infra/k8s/base/aws-addons/service-account.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-secrets-sa
  namespace: pms
  annotations:
    eks.amazonaws.com/role-arn: <PASTE_EXTERNAL_SECRETS_ROLE_ARN_HERE>
```

**OR** use sed:

```bash
cd pms-infra/k8s/base/aws-addons/

sed -i "s|\${AWS_ACCOUNT_ID}|$AWS_ACCOUNT_ID|g" service-account.yaml
sed -i "s|\${CLUSTER_NAME}|$CLUSTER_NAME|g" service-account.yaml
```

---

## 🚀 Phase 5: Deploy Applications to EKS

### Step 5.1: Build and push Docker images

```bash
cd /mnt/c/Developer/pms-new

# Build images (assumes Docker is configured)
docker build -t niishantdev/pms-simulation:dev-latest ./pms-simulation
docker build -t niishantdev/pms-trade-capture:dev-latest ./pms-trade-capture
docker build -t niishantdev/pms-validation:dev-latest ./pms-validation

# Push to registry
docker push niishantdev/pms-simulation:dev-latest
docker push niishantdev/pms-trade-capture:dev-latest
docker push niishantdev/pms-validation:dev-latest
```

### Step 5.2: Deploy via Kustomize

```bash
cd pms-infra/k8s/overlays/dev

kubectl apply -k .
```

### Step 5.3: Verify deployment

```bash
# Check all pods
kubectl get pods -n pms

# Check services
kubectl get svc -n pms

# Check ingress (ALB should be provisioned)
kubectl get ingress -n pms

# Get ALB URL
kubectl get ingress trade-capture-ingress -n pms -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

⏱️ **Estimated time: 5-10 minutes for ALB provisioning**

---

## ✅ Phase 6: Verification

### 6.1 Check External Secrets

```bash
# Verify SecretStore
kubectl get secretstore -n pms

# Verify ExternalSecret
kubectl get externalsecret -n pms

# Check if K8s secret was created
kubectl get secret postgres-credentials -n pms

# Decode secret to verify
kubectl get secret postgres-credentials -n pms -o jsonpath='{.data.POSTGRES_HOST}' | base64 -d
```

Expected: RDS endpoint visible

### 6.2 Check RDS Connectivity

```bash
# Get a shell in trade-capture pod
POD=$(kubectl get pod -n pms -l app=trade-capture -o jsonpath='{.items[0].metadata.name}')

kubectl exec -it $POD -n pms -- sh

# Inside pod
nc -zv $POSTGRES_HOST 5432
```

Expected: Connection succeeds

### 6.3 Check Application Logs

```bash
kubectl logs -n pms -l app=trade-capture --tail=50

# Look for:
# - Successful DB migration (Liquibase)
# - RabbitMQ connection
# - Kafka connection
```

### 6.4 Health Check via ALB

```bash
ALB_URL=$(kubectl get ingress trade-capture-ingress -n pms -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

curl http://$ALB_URL/actuator/health
```

Expected: `{"status":"UP"}`

---

## 🐛 Troubleshooting

### External Secrets not syncing

```bash
# Check ESO logs
kubectl logs -n external-secrets-system -l app.kubernetes.io/name=external-secrets

# Check ExternalSecret status
kubectl describe externalsecret rds-postgres-credentials -n pms
```

Common issues:
- IAM role not properly attached to ServiceAccount
- Secrets Manager secret doesn't exist
- Wrong secret name/region

### Pods stuck in Init

```bash
# Check init container logs
kubectl logs $POD -n pms -c wait-for-postgres
```

Common issues:
- RDS security group not allowing EKS node traffic
- Wrong RDS endpoint in secret

### ALB not provisioning

```bash
# Check AWS Load Balancer Controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check service account
kubectl describe sa aws-load-balancer-controller -n kube-system
```

Common issues:
- IAM role not attached
- Subnet tags missing
- Security group misconfiguration

---

## 🧹 Cleanup (When Done Testing)

### Delete Kubernetes resources

```bash
kubectl delete -k pms-infra/k8s/overlays/dev
```

### Delete AWS infrastructure

```bash
cd pms-infra/terraform/envs/dev
terraform destroy
```

**Note:** This will delete:
- EKS cluster
- RDS instance (data will be lost unless you disable `skip_final_snapshot`)
- VPC and all networking
- IAM roles
- Secrets Manager secrets

---

## 📊 Cost Estimation (Dev Environment)

**Monthly costs (us-east-1):**

| Resource | Type | Monthly Cost |
|----------|------|-------------|
| EKS cluster | Control plane | ~$73 |
| EC2 nodes | 2x t3.large | ~$120 |
| NAT Gateway | Single NAT | ~$32 |
| RDS | db.t3.micro | ~$25 |
| ALB | Application Load Balancer | ~$18 |
| **Total** | | **~$268/month** |

**Cost optimization tips:**
- Stop EKS nodes when not in use
- Use Spot instances for non-prod
- Consider Fargate for intermittent workloads

---

## 🔄 What Changed from Local to EKS?

| Component | Local | Dev (EKS) |
|-----------|-------|-----------|
| PostgreSQL | In-cluster | RDS (managed) |
| Secrets | .env file | AWS Secrets Manager |
| Load Balancer | None/NodePort | AWS ALB |
| Storage | hostPath | EBS (via CSI) |
| Kafka | In-cluster | In-cluster (same) |
| RabbitMQ | In-cluster | In-cluster (same) |
| Redis | In-cluster | In-cluster (same) |

**Local deployment still works!** Just use:

```bash
kubectl apply -k pms-infra/k8s/overlays/local
```

---

## 🎯 Next Steps

1. **Enable TLS/HTTPS** on ALB (requires ACM certificate)
2. **Add Prometheus + Grafana** for monitoring
3. **Move Kafka to MSK** (if needed at scale)
4. **Add autoscaling** for EKS nodes
5. **Set up CI/CD** (GitHub Actions → ECR → EKS)
6. **Production overlay** with multi-AZ RDS, larger instances

---

## 📚 Reference

- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [External Secrets Operator](https://external-secrets.io/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Kustomize Documentation](https://kustomize.io/)

---

**Maintained by:** Platform Team  
**Last updated:** 2025-12-31
