# PMS EKS Quick Start

**TL;DR: Get PMS running on EKS in 30 minutes**

---

## 🎯 What This Does

Deploys PMS (trade-capture, simulation, validation) to AWS EKS with:
- Managed Kubernetes (EKS)
- Managed PostgreSQL (RDS)
- AWS Load Balancer (ALB)
- Secure secrets (AWS Secrets Manager)

**Local deployment unchanged** - still works with `kubectl apply -k k8s/overlays/local`

---

## 🚀 Deploy (3 Commands)

### 1. Deploy Infrastructure (~15 min)

```bash
cd pms-infra/terraform/envs/dev
terraform init
terraform apply
```

### 2. Configure kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name pms-dev
kubectl get nodes  # Should show 2-3 nodes
```

### 3. Install External Secrets Operator

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets-system --create-namespace --set installCRDs=true
```

### 4. Update IAM Role ARN

```bash
# Get the ARN
terraform output external_secrets_role_arn

# Edit this file and paste the ARN
nano ../../../k8s/base/aws-addons/service-account.yaml
```

Replace `${AWS_ACCOUNT_ID}` and `${CLUSTER_NAME}` with actual values, OR use:

```bash
export AWS_ACCOUNT_ID=$(terraform output -raw aws_account_id)
export CLUSTER_NAME="pms-dev"

cd ../../../k8s/base/aws-addons/
sed -i "s/\${AWS_ACCOUNT_ID}/$AWS_ACCOUNT_ID/g" service-account.yaml
sed -i "s/\${CLUSTER_NAME}/$CLUSTER_NAME/g" service-account.yaml
```

### 5. Deploy Apps (~5 min)

```bash
cd ../../overlays/dev
kubectl apply -k .
```

---

## ✅ Verify

```bash
# Check pods
kubectl get pods -n pms

# Check ALB URL
kubectl get ingress -n pms
ALB=$(kubectl get ingress trade-capture-ingress -n pms -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test health endpoint
curl http://$ALB/actuator/health
```

Expected: `{"status":"UP"}`

---

## 📂 What Changed?

```
pms-infra/
├── terraform/envs/dev/main.tf          # Added: external_secrets_irsa IAM role
├── k8s/base/aws-addons/                # Added: AWS-specific resources
│   ├── secret-store.yaml               # Connects to AWS Secrets Manager
│   └── service-account.yaml            # IRSA for External Secrets
└── k8s/overlays/dev/
    ├── kustomization.yaml              # Added: new resources
    ├── external-secret-rds.yaml        # Fetches RDS credentials
    └── ingress.yaml                    # ALB for trade-capture
```

**Local overlay:** UNCHANGED ✅

---

## 🔐 How Secrets Work

### Local
```
.env file → K8s Secret → Pod
```

### EKS
```
Terraform → AWS Secrets Manager → External Secrets → K8s Secret → Pod
```

**No secrets in Git!**

---

## 💰 Monthly Cost (Dev)

| Resource | Cost |
|----------|------|
| EKS Control Plane | ~$73 |
| 2x t3.large nodes | ~$120 |
| NAT Gateway | ~$32 |
| RDS db.t3.micro | ~$25 |
| ALB | ~$18 |
| **Total** | **~$268/month** |

---

## 🧹 Cleanup

```bash
# Delete K8s resources
kubectl delete -k pms-infra/k8s/overlays/dev

# Delete AWS infrastructure
cd pms-infra/terraform/envs/dev
terraform destroy
```

---

## 🐛 Troubleshooting

### Pods stuck in Init

```bash
# Check RDS connectivity
kubectl logs <pod-name> -n pms -c wait-for-postgres
```

**Fix:** Check RDS security group allows EKS node traffic

### ExternalSecret not syncing

```bash
kubectl describe externalsecret rds-postgres-credentials -n pms
```

**Fix:** Verify IAM role ARN in ServiceAccount annotation

### ALB not provisioning

```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

**Fix:** Check subnet tags, IAM role

---

## 📖 Full Documentation

- **Detailed playbook:** `docs/EKS_DEPLOYMENT_PLAYBOOK.md`
- **What changed:** `docs/EVOLUTION_SUMMARY.md`

---

## 🎯 What's Next?

Current setup is **minimal but production-ready** for dev. To scale:

1. Add TLS/HTTPS (requires ACM certificate)
2. Add Prometheus + Grafana
3. Move Kafka to MSK (if needed)
4. Enable autoscaling
5. Create prod overlay (multi-AZ RDS, larger instances)
6. Set up CI/CD pipeline

---

**Questions?** See full playbook: `docs/EKS_DEPLOYMENT_PLAYBOOK.md`
