# AWS EKS Migration - Quick Reference Card

## 🎯 Current Status
✅ **ALL PHASES PREPARED** - Ready for execution

---

## 📋 Quick Commands

### Deploy to Local (Working Now)
```bash
cd /mnt/c/Developer/pms-new/pms-infra
./scripts/deploy-local.sh
```

### Deploy to AWS EKS Dev (After Terraform)
```bash
# 1. Create infrastructure
cd terraform/envs/dev
terraform init && terraform apply

# 2. Configure kubectl  
aws eks update-kubeconfig --region us-east-1 --name pms-dev

# 3. Deploy apps
cd ../../..
kubectl apply -k k8s/overlays/dev

# 4. Verify
kubectl get pods -n pms  # Should show 7 pods
```

---

## 🗂️ File Locations

| Purpose | Location |
|---------|----------|
| **Local K8s** | `k8s/overlays/local/` |
| **EKS Dev** | `k8s/overlays/dev/` |
| **EKS Prod** | `k8s/overlays/prod/` |
| **Terraform Dev** | `terraform/envs/dev/` |
| **RDS Module** | `terraform/modules/rds/` |
| **Migration Guide** | `docs/EKS_MIGRATION_PLAYBOOK.md` |
| **Architecture** | `docs/AWS_EKS_READY.md` |

---

## 🔑 Key Differences

| Environment | Postgres | Replicas | Resources | Image Tags |
|-------------|----------|----------|-----------|------------|
| **Local** | In-cluster | 1 | Minimal | `latest` |
| **Dev** | RDS | 1 | Moderate | `dev-latest` |
| **Prod** | RDS Multi-AZ | 2-3 | Production | `v1.0.0` |

---

## 💰 Costs

**Dev Environment**: ~$315/month
- EKS: $73
- Nodes (3x t3.large): $150
- RDS (db.t3.medium): $50
- NAT Gateway: $32
- EBS: $10

**Save Money**:
```bash
# Stop nodes after hours (save ~$150/month)
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name <name> \
  --desired-capacity 0

# Stop RDS when not needed
aws rds stop-db-instance --db-instance-identifier pms-dev-postgres
```

---

## 🔍 Verification

```bash
# Check deployments
kubectl kustomize k8s/overlays/dev | grep "kind: Deployment" | wc -l
# Expected: 7 (no postgres)

# Check local
kubectl kustomize k8s/overlays/local | grep "kind: Deployment" | wc -l
# Expected: 8 (with postgres)

# Test connectivity
kubectl exec -it -n pms deployment/trade-capture -- \
  nc -zv $DB_HOST $DB_PORT
```

---

## 📊 Pod Count by Environment

```
Local:  8 pods (postgres + kafka + rabbitmq + redis + schema-registry + 3 apps)
Dev:    7 pods (kafka + rabbitmq + redis + schema-registry + 3 apps) - NO postgres
Prod:   7 pods (kafka + rabbitmq + redis + schema-registry + 3 apps) - NO postgres
```

---

## 🚀 Execution Order

1. **PHASE 0**: Install tools (aws-cli, terraform, kubectl, helm)
2. **PHASE 2**: Create EKS (`terraform apply`)
3. **PHASE 4**: RDS created automatically
4. **PHASE 5**: Install External Secrets Operator
5. **PHASE 8**: Deploy apps (`kubectl apply -k k8s/overlays/dev`)
6. **PHASE 7**: Set up monitoring (CloudWatch)
7. **PHASE 9**: Hardening (PDB, HPA, alerts)

---

## 🔐 Secrets Location

| Environment | Location |
|-------------|----------|
| **Local** | `k8s/overlays/local/secrets.env` (gitignored) |
| **Dev** | AWS Secrets Manager: `pms/dev/postgres` |
| **Prod** | AWS Secrets Manager: `pms/prod/postgres` |

---

## 📖 Documentation

- **Start Here**: `docs/AWS_EKS_READY.md`
- **Step-by-Step**: `docs/EKS_MIGRATION_PLAYBOOK.md`
- **Troubleshooting**: `docs/troubleshooting.md`
- **Architecture**: `docs/architecture.md`

---

## ⚠️ Important

1. RDS credentials auto-generated (32 chars)
2. PostgreSQL excluded from dev/prod overlays
3. All secrets in AWS Secrets Manager (not in Git)
4. EKS uses IRSA (no static credentials)
5. Private subnets only (no public IPs)

---

## 📞 Quick Help

```bash
# Get cluster info
kubectl cluster-info

# Get RDS endpoint
cd terraform/envs/dev && terraform output rds_endpoint

# View secrets (local)
cat k8s/overlays/local/secrets.env

# View secrets (EKS)
aws secretsmanager get-secret-value \
  --secret-id pms/dev/postgres \
  --query SecretString \
  --output text | jq

# Port forward to service
kubectl port-forward -n pms svc/trade-capture 8082:8082
```

---

**Last Updated**: December 31, 2025  
**Version**: 1.0.0  
**Status**: ✅ Production-Ready
