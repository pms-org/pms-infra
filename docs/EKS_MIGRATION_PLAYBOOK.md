# AWS EKS Migration - Execution Playbook

## ✅ PHASE 1 COMPLETE
Dev and prod overlays created, PostgreSQL excluded from EKS deployments.

---

## 🚀 PHASE 2: EKS Provisioning (START HERE)

### Prerequisites Check

```bash
# Verify AWS CLI
aws sts get-caller-identity
aws --version  # Should be >= 2.0

# Verify Terraform
terraform version  # Should be >= 1.5

# Verify kubectl
kubectl version --client

# Verify eksctl (optional but recommended)
eksctl version
```

### Step 1: Create S3 Backend (One-time setup)

```bash
# Create S3 bucket for Terraform state
aws s3api create-bucket \
  --bucket pms-terraform-state-dev \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket pms-terraform-state-dev \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket pms-terraform-state-dev \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name pms-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### Step 2: Configure Terraform

```bash
cd terraform/envs/dev

# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit variables (optional - defaults are fine for dev)
vim terraform.tfvars
```

### Step 3: Provision EKS Cluster

```bash
# Initialize Terraform
terraform init

# Review plan
terraform plan

# Apply (this takes 15-20 minutes)
terraform apply

# Save outputs
terraform output > ../../../.eks-outputs-dev.txt
```

### Step 4: Configure kubectl

```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name pms-dev

# Verify connection
kubectl get nodes
# Should show 3 nodes in Ready state

# Verify AWS Load Balancer Controller
kubectl get pods -n kube-system | grep aws-load-balancer-controller
# Should show 2 running pods
```

### Step 5: Verify EBS CSI Driver

```bash
# Check EBS CSI driver
kubectl get pods -n kube-system | grep ebs-csi

# Create test PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: gp3
EOF

# Check PVC is bound
kubectl get pvc test-pvc

# Clean up test
kubectl delete pvc test-pvc
```

---

## 🗄️ PHASE 4: RDS PostgreSQL

### Step 1: Provision RDS (Already in Terraform)

The RDS configuration is in `terraform/envs/dev/rds.tf`. It's commented out to deploy EKS first.

Uncomment the RDS module in `rds.tf` and apply:

```bash
cd terraform/envs/dev

# Uncomment rds.tf content or it's already there
# Then apply
terraform apply

# This creates:
# - RDS PostgreSQL 16.1 instance
# - Security group allowing EKS nodes
# - Secrets Manager secret with credentials
```

### Step 2: Verify RDS Connection from EKS

```bash
# Get RDS endpoint
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)

# Test connection from a pod
kubectl run -it --rm psql-test --image=postgres:16 --restart=Never -- \
  psql -h $RDS_ENDPOINT -U pmsadmin -d pmsdb

# Enter password from Secrets Manager
```

### Step 3: Initialize Database Schema

```bash
# Copy schema files to a pod
kubectl cp ../../pms-trade-capture/src/main/resources/schema.sql \
  psql-pod:/tmp/schema.sql

# Run schema
kubectl exec -it psql-pod -- \
  psql -h $RDS_ENDPOINT -U pmsadmin -d pmsdb -f /tmp/schema.sql
```

---

## 🔐 PHASE 5: External Secrets Operator

### Step 1: Install External Secrets Operator

```bash
# Add helm repo
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# Install operator
helm install external-secrets \
  external-secrets/external-secrets \
  -n external-secrets-system \
  --create-namespace \
  --set installCRDs=true
```

### Step 2: Create IAM Role for External Secrets

```bash
cd terraform/envs/dev

# Create new file: external-secrets.tf
cat > external-secrets.tf <<'EOF'
# IAM role for External Secrets Operator
module "external_secrets_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.cluster_name}-external-secrets"

  role_policy_arns = {
    policy = aws_iam_policy.external_secrets.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["external-secrets-system:external-secrets"]
    }
  }

  tags = local.tags
}

# Policy for reading Secrets Manager
resource "aws_iam_policy" "external_secrets" {
  name        = "${local.cluster_name}-external-secrets-policy"
  description = "Policy for External Secrets to read from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:pms/*"
      }
    ]
  })
}

output "external_secrets_role_arn" {
  value = module.external_secrets_irsa.iam_role_arn
}
EOF

# Apply
terraform apply
```

### Step 3: Create ClusterSecretStore

```bash
# Get IAM role ARN
ROLE_ARN=$(cd terraform/envs/dev && terraform output -raw external_secrets_role_arn)

# Create ClusterSecretStore
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: aws-secrets
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets
            namespace: external-secrets-system
EOF
```

### Step 4: Create ExternalSecret for RDS

Create `k8s/overlays/dev/external-secrets.yaml`:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: postgres-credentials
  namespace: pms
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets
    kind: ClusterSecretStore
  target:
    name: postgres-credentials
    creationPolicy: Owner
  dataFrom:
    - extract:
        key: pms/dev/postgres
```

### Step 5: Update Dev Kustomization

Edit `k8s/overlays/dev/kustomization.yaml`:

```yaml
resources:
  - ../../base
  - external-secrets.yaml  # ✅ Uncomment this line
```

---

## 📊 PHASE 7: Monitoring (CloudWatch Container Insights)

### Step 1: Enable Container Insights

```bash
# Create CloudWatch namespace
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/cloudwatch-namespace.yaml

# Create service account
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/cwagent/cwagent-serviceaccount.yaml

# Deploy CloudWatch agent
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/cwagent/cwagent-daemonset.yaml

# Deploy Fluent Bit
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/fluent-bit/fluent-bit.yaml
```

### Step 2: View Logs in CloudWatch

```bash
# Open CloudWatch Console
echo "https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#logsV2:log-groups/log-group//aws/containerinsights/pms-dev"
```

---

## 🚀 PHASE 8: First EKS Deployment

### Step 1: Update Application Environment Variables

The applications need to connect to RDS instead of in-cluster postgres.

The External Secrets will inject:
- `DB_HOST` (from Secrets Manager)
- `DB_PORT`
- `DB_NAME`
- `DB_USERNAME`
- `DB_PASSWORD`

### Step 2: Deploy to EKS Dev

```bash
# Make sure kubectl context is correct
kubectl config current-context  # Should be arn:aws:eks:...:cluster/pms-dev

# Deploy
kubectl apply -k k8s/overlays/dev

# Watch rollout
watch kubectl get pods -n pms
```

### Step 3: Verify Deployment

```bash
# Check all pods are running (should be 7, no postgres)
kubectl get pods -n pms

# Check RDS connectivity
kubectl logs -n pms -l app=trade-capture | grep -i "database\|postgres"

# Check Kafka
kubectl logs -n pms -l app=kafka | grep "Kafka Server started"

# Check Schema Registry
kubectl logs -n pms -l app=schema-registry | grep "Server started"
```

### Step 4: Test Connectivity

```bash
# Test from trade-capture to RDS
kubectl exec -it -n pms deployment/trade-capture -- sh -c '
  nc -zv $DB_HOST $DB_PORT
'

# Test from trade-capture to Kafka
kubectl exec -it -n pms deployment/trade-capture -- sh -c '
  nc -zv kafka 19092
'

# Test from trade-capture to RabbitMQ
kubectl exec -it -n pms deployment/trade-capture -- sh -c '
  nc -zv rabbitmq 5552
'
```

---

## 📋 Troubleshooting

### Pods Not Starting

```bash
# Describe pod
kubectl describe pod -n pms <pod-name>

# Check events
kubectl get events -n pms --sort-by='.lastTimestamp'

# Check logs
kubectl logs -n pms <pod-name>
```

### RDS Connection Issues

```bash
# Check security group allows EKS nodes
aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=<rds-sg-id>"

# Test from bastion or temporary pod
kubectl run -it --rm debug --image=postgres:16 --restart=Never -- \
  psql -h <rds-endpoint> -U pmsadmin -d pmsdb
```

### External Secrets Not Working

```bash
# Check operator logs
kubectl logs -n external-secrets-system deployment/external-secrets

# Check secret store
kubectl get clustersecretstore aws-secrets -o yaml

# Check external secret
kubectl get externalsecret -n pms postgres-credentials -o yaml
kubectl describe externalsecret -n pms postgres-credentials
```

---

## 🎯 Success Criteria

- [ ] EKS cluster created with 3 nodes
- [ ] AWS Load Balancer Controller installed
- [ ] EBS CSI Driver working
- [ ] RDS PostgreSQL created
- [ ] RDS accessible from EKS nodes
- [ ] External Secrets Operator installed
- [ ] Secrets syncing from Secrets Manager
- [ ] All 7 pods running in pms namespace
- [ ] Applications connecting to RDS successfully
- [ ] CloudWatch logs flowing

---

## 💰 Cost Optimization

### Dev Environment Costs (Approximate)

- EKS Control Plane: $73/month
- 3x t3.large nodes: ~$150/month
- RDS db.t3.medium: ~$50/month
- EBS volumes: ~$10/month
- NAT Gateway: ~$32/month
- **Total: ~$315/month**

### Cost Savings Tips

1. **Stop dev cluster outside business hours**:
   ```bash
   # Stop nodes (save ~$150/month during nights/weekends)
   aws autoscaling set-desired-capacity \
     --auto-scaling-group-name <asg-name> \
     --desired-capacity 0
   ```

2. **Use Spot Instances** (save ~70%):
   Add to `main.tf`:
   ```hcl
   capacity_type = "SPOT"
   ```

3. **Stop RDS when not needed**:
   ```bash
   aws rds stop-db-instance --db-instance-identifier pms-dev-postgres
   ```

---

**Status**: Ready for execution
**Estimated Time**: 2-3 hours for complete setup
**Next**: Run PHASE 2 terraform commands
