# PMS Platform Ingress Setup Guide

## Overview

This document describes the production-grade ingress setup for the PMS platform on AWS EKS.

## Architecture

```
Internet (HTTPS)
   ↓
Route 53: pms.yourdomain.com
   ↓
AWS ALB (Application Load Balancer)
   ├── Port 80  → Redirect to 443
   └── Port 443 → Ingress Controller
       ├── /       → frontend service (Angular SPA)
       ├── /api/*  → apigateway service (REST)
       └── /ws/*   → apigateway service (WebSocket)
```

## Benefits

1. **Single Public Endpoint**: One domain, one origin
2. **No CORS Issues**: Same-origin for frontend + backend
3. **HTTPS Everywhere**: TLS termination at ALB via ACM
4. **WebSocket Support**: Native HTTP/1.1 upgrade headers
5. **Cost Efficient**: Single ALB (~$20/month)
6. **GitOps Ready**: Helm-templated, ArgoCD compatible

## Prerequisites

1. **AWS Load Balancer Controller** installed in cluster
2. **ACM Certificate** for your domain
3. **Route 53 Hosted Zone** (or external DNS)
4. **IAM Permissions** for ALB controller

## Step 1: Install AWS Load Balancer Controller

### 1.1 Create IAM Policy

```bash
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.1/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam-policy.json
```

### 1.2 Create IAM Service Account

```bash
# Get your cluster name and AWS account ID
CLUSTER_NAME=<your-cluster-name>
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create IRSA (IAM Role for Service Account)
eksctl create iamserviceaccount \
  --cluster=$CLUSTER_NAME \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::${AWS_ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --approve
```

### 1.3 Install Controller via Helm

```bash
# Add Helm repo
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

### 1.4 Verify Installation

```bash
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

## Step 2: Request ACM Certificate

### Option A: Automated (Route 53)

```bash
# Request certificate
aws acm request-certificate \
  --domain-name pms.yourdomain.com \
  --validation-method DNS \
  --region us-east-1

# Note the CertificateArn from output
```

AWS will automatically validate via Route 53 DNS records.

### Option B: Manual DNS Validation

1. Request certificate in ACM console
2. Add CNAME records to your DNS provider
3. Wait for validation (5-30 minutes)

**Important**: Certificate MUST be in `us-east-1` for ALB.

## Step 3: Update Service Types

Change both frontend and apigateway from `LoadBalancer` to `ClusterIP`:

```bash
# Update values in Helm charts
# pms-infra/k8s/charts/services/frontend/values.yaml
# pms-infra/k8s/charts/services/apigateway/values.yaml

service:
  type: ClusterIP  # Changed from LoadBalancer
```

## Step 4: Deploy Ingress Resource

See `pms-infra/k8s/charts/platform/pms-ingress/` for Helm chart.

## Step 5: Configure DNS

After ingress creates ALB, get the ALB DNS name:

```bash
kubectl get ingress -n pms pms-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Create Route 53 ALIAS record:
- **Name**: `pms.yourdomain.com`
- **Type**: A (Alias)
- **Target**: ALB DNS name

## Step 6: Update Frontend Configuration

Frontend will use relative URLs (same origin):

```typescript
// Before (hardcoded LoadBalancer URLs)
API_GATEWAY_HTTP: "http://a3ed40b...elb.amazonaws.com:8088"

// After (same origin)
API_GATEWAY_HTTP: ""  // Relative to window.location.origin
```

All requests automatically go to `https://pms.yourdomain.com/api/*`

## Validation Checklist

- [ ] ALB created with 2 listeners (80, 443)
- [ ] HTTPS certificate attached
- [ ] HTTP→HTTPS redirect working
- [ ] Frontend loads at `https://pms.yourdomain.com/`
- [ ] API calls work: `https://pms.yourdomain.com/api/auth/login`
- [ ] WebSockets work: `wss://pms.yourdomain.com/ws/rttm/metrics`
- [ ] No CORS errors in browser console
- [ ] No localhost references anywhere

## Troubleshooting

### ALB Not Creating

```bash
# Check controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Check ingress events
kubectl describe ingress -n pms pms-ingress
```

### Certificate Not Working

- Verify certificate ARN is correct
- Ensure certificate is in same region as ALB
- Check ACM validation status

### WebSocket Failing

- Verify idle timeout annotations
- Check ALB target group health
- Test with `wscat`: `wscat -c wss://pms.yourdomain.com/ws/rttm/metrics`

## Cost Estimate

- **ALB**: ~$22/month (0.0225/hour + LCU charges)
- **Data Transfer**: Variable
- **ACM Certificate**: Free
- **Route 53**: ~$0.50/month per hosted zone

**Total**: ~$25-30/month (vs $45-50 with dual LoadBalancers)

## Security

- [x] HTTPS enforced (HTTP redirects to HTTPS)
- [x] TLS 1.2+ only
- [x] ACM managed certificates (auto-renewal)
- [x] WAF-ready (can attach AWS WAF to ALB)
- [x] Security groups on ALB targets
- [x] No direct pod exposure

## Rollback Plan

If issues occur, revert to LoadBalancer services:

```bash
helm upgrade frontend ./charts/services/frontend \
  --set service.type=LoadBalancer \
  -n pms

helm upgrade apigateway ./charts/services/apigateway \
  --set service.type=LoadBalancer \
  -n pms
```

Old LoadBalancer IPs remain in Helm values as backup.
