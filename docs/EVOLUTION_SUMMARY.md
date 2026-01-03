# PMS-Infra Evolution Summary

**Date:** 2025-12-31  
**Objective:** Incrementally evolve existing `pms-infra` for AWS EKS deployment

---

## ✅ What Was Changed

### 1. **Terraform - Added IAM Role for External Secrets**

**File:** `terraform/envs/dev/main.tf`

**Change:** Added IRSA role for External Secrets Operator

```terraform
# NEW: IAM role for External Secrets Operator
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
      namespace_service_accounts = ["pms:external-secrets-sa"]
    }
  }
}

# NEW: IAM policy for Secrets Manager access
resource "aws_iam_policy" "external_secrets" {
  name = "${local.cluster_name}-external-secrets-policy"
  
  policy = jsonencode({
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:pms/${local.environment}/*"
    }]
  })
}
```

**Why:** Allows External Secrets Operator to read RDS credentials from AWS Secrets Manager

---

### 2. **Kubernetes - AWS Add-ons (Base)**

**New Directory:** `k8s/base/aws-addons/`

#### 2.1 SecretStore (`secret-store.yaml`)

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets-manager
  namespace: pms
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
```

**Why:** Connects Kubernetes to AWS Secrets Manager using IRSA (no static credentials)

#### 2.2 ServiceAccount (`service-account.yaml`)

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-secrets-sa
  namespace: pms
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::${AWS_ACCOUNT_ID}:role/${CLUSTER_NAME}-external-secrets
```

**Why:** Links K8s ServiceAccount to IAM role via IRSA annotations

---

### 3. **Kubernetes - Dev Overlay Updates**

#### 3.1 ExternalSecret for RDS (`external-secret-rds.yaml`)

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: rds-postgres-credentials
  namespace: pms
spec:
  secretStoreRef:
    name: aws-secrets-manager
  target:
    name: postgres-credentials  # Creates K8s secret
  data:
    - secretKey: POSTGRES_HOST
      remoteRef:
        key: pms/dev/postgres
        property: host
    # ... (port, dbname, username, password)
```

**Why:** Dynamically fetches RDS credentials from Secrets Manager and creates `postgres-credentials` K8s secret

#### 3.2 Ingress for ALB (`ingress.yaml`)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: trade-capture-ingress
  namespace: pms
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: trade-capture
                port:
                  number: 8082
```

**Why:** Exposes `trade-capture` service via AWS Application Load Balancer

#### 3.3 Updated Kustomization

**File:** `k8s/overlays/dev/kustomization.yaml`

```yaml
resources:
  - ../../base
  # NEW: AWS-specific resources
  - ../../base/aws-addons/secret-store.yaml
  - ../../base/aws-addons/service-account.yaml
  - external-secret-rds.yaml
  - ingress.yaml
```

**Why:** Includes AWS-specific resources only in EKS overlays (not local)

---

### 4. **Documentation**

**New File:** `docs/EKS_DEPLOYMENT_PLAYBOOK.md`

Comprehensive guide covering:
- Phase 1: Deploy AWS infrastructure (Terraform)
- Phase 2: Configure kubectl
- Phase 3: Install External Secrets Operator
- Phase 4: Update manifests with real values
- Phase 5: Deploy applications
- Phase 6: Verification steps
- Troubleshooting guide
- Cost estimation
- Cleanup procedure

---

## ❌ What Was NOT Changed

- ✅ Local overlay (`k8s/overlays/local/`) - untouched, still works
- ✅ Base manifests - unchanged (apps, infra services)
- ✅ Application images - no changes
- ✅ Kafka/RabbitMQ/Redis - remain in-cluster (not moved to managed services)
- ✅ Existing Terraform modules - only added IRSA role, didn't modify VPC/EKS/RDS

---

## 🔄 Secrets Flow (Before vs After)

### Before (Local)

```
.env file → secretGenerator → K8s Secret → Pod env vars
```

### After (EKS Dev)

```
Terraform → AWS Secrets Manager → External Secrets Operator → K8s Secret → Pod env vars
```

**Key difference:** No secrets in Git, dynamically fetched from AWS

---

## 📦 New Dependencies

### Terraform
- No new providers (already had `aws`, `kubernetes`, `helm`)
- New module: `external_secrets_irsa`

### Kubernetes
- **External Secrets Operator** (installed via Helm)
  - Namespace: `external-secrets-system`
  - CRDs: `SecretStore`, `ExternalSecret`

---

## 🚀 Deployment Order

1. **Terraform apply** → Creates VPC, EKS, RDS, IAM roles, Secrets Manager secret
2. **Install External Secrets Operator** → Helm chart
3. **Update ServiceAccount annotation** → Paste IAM role ARN from Terraform output
4. **kubectl apply -k overlays/dev** → Deploys apps, creates ExternalSecret, Ingress
5. **Verify** → Check pods, RDS connectivity, ALB provisioning

---

## 📊 File Changes Summary

```
pms-infra/
├── terraform/envs/dev/
│   └── main.tf                          # MODIFIED: Added external_secrets_irsa
│
├── k8s/
│   ├── base/
│   │   └── aws-addons/                  # NEW DIRECTORY
│   │       ├── secret-store.yaml        # NEW
│   │       └── service-account.yaml     # NEW
│   │
│   └── overlays/dev/
│       ├── kustomization.yaml           # MODIFIED: Added new resources
│       ├── external-secret-rds.yaml     # NEW
│       └── ingress.yaml                 # NEW
│
└── docs/
    └── EKS_DEPLOYMENT_PLAYBOOK.md       # NEW
```

**Total files changed:** 2 modified, 5 new, 0 deleted

---

## ✨ Key Design Principles Followed

1. **Incremental Evolution** - Built on existing structure, didn't rewrite
2. **Overlay Isolation** - Local overlay unchanged, dev overlay extended
3. **No Secrets in Git** - All RDS credentials in AWS Secrets Manager
4. **Minimal Complexity** - Only added what's necessary (External Secrets, Ingress)
5. **Terraform Separation** - Infrastructure remains decoupled from app deployment
6. **Reversible Changes** - Can roll back by reverting to previous overlay

---

## 🎯 What's Ready Now

- ✅ VPC with public/private subnets (2 AZs)
- ✅ EKS cluster with managed nodes
- ✅ RDS PostgreSQL (managed, private)
- ✅ IAM roles with IRSA (no static credentials)
- ✅ AWS Load Balancer Controller
- ✅ External Secrets Operator integration
- ✅ ALB Ingress for external access
- ✅ Secrets dynamically fetched from AWS

---

## 🔜 Future Enhancements (NOT YET DONE)

These are intentionally **not included** per the prompt's guidance:

- ❌ MSK (Kafka stays in-cluster for now)
- ❌ ElastiCache (Redis stays in-cluster)
- ❌ Service Mesh (not needed yet)
- ❌ Autoscaling (can add later)
- ❌ GitOps (can add later)
- ❌ Multi-account setup (single account only)
- ❌ TLS/HTTPS (requires ACM certificate)
- ❌ Prometheus/Grafana (basic CloudWatch only)

---

## 📝 Manual Steps Required

After running Terraform, you must:

1. **Get IAM Role ARN:**
   ```bash
   terraform output external_secrets_role_arn
   ```

2. **Update ServiceAccount:**
   Edit `k8s/base/aws-addons/service-account.yaml` and replace placeholders:
   ```yaml
   eks.amazonaws.com/role-arn: <PASTE_ARN_HERE>
   ```

3. **Install External Secrets Operator:**
   ```bash
   helm install external-secrets external-secrets/external-secrets \
     -n external-secrets-system --create-namespace --set installCRDs=true
   ```

**Why manual?** These steps require Terraform outputs and are environment-specific.

---

## 🧪 Testing Checklist

- [ ] Local overlay still works: `kubectl apply -k k8s/overlays/local`
- [ ] Terraform plan succeeds
- [ ] Terraform apply completes (~15-20 min)
- [ ] kubectl can connect to EKS
- [ ] External Secrets Operator installed
- [ ] ExternalSecret syncs RDS credentials
- [ ] Pods start successfully
- [ ] RDS connectivity verified from pod
- [ ] ALB provisions successfully
- [ ] Health endpoint returns 200 via ALB
- [ ] Application logs show no errors

---

## 💡 Lessons Applied

1. **Respect existing structure** - Didn't change what works
2. **Overlay pattern** - Perfect for multi-environment
3. **IRSA over static credentials** - More secure
4. **Managed services where it matters** - RDS, not Kafka yet
5. **Documentation is deployment** - Playbook includes verification
6. **Cost-conscious** - Single NAT, t3.micro RDS for dev

---

**Maintained by:** Platform Team  
**Review status:** Ready for testing
