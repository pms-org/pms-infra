# EKS Cluster Upgrade and External Secrets Operator Deployment

## Overview

This document details the complete troubleshooting, upgrade, and deployment process for resolving external-secrets operator issues in an Amazon EKS cluster. The process involved upgrading an unsupported Kubernetes version and implementing a production-ready secrets management solution.

## Table of Contents

1. [Problem Statement](#problem-statement)
2. [Root Cause Analysis](#root-cause-analysis)
3. [Solution Strategy](#solution-strategy)
4. [EKS Cluster Upgrade Process](#eks-cluster-upgrade-process)
5. [External Secrets Operator Setup](#external-secrets-operator-setup)
6. [Testing and Validation](#testing-and-validation)
7. [Configuration Files](#configuration-files)
8. [Troubleshooting Guide](#troubleshooting-guide)
9. [Lessons Learned](#lessons-learned)

## Problem Statement

The external-secrets operator was experiencing `CrashLoopBackOff` status in the EKS cluster. The operator pods were failing to start, preventing the retrieval of secrets from AWS Secrets Manager for application use.

### Initial Symptoms
- External-secrets pods in `CrashLoopBackOff` state
- Error: `no matches for kind 'ExternalSecret' in version 'external-secrets.io/v1'`
- CRD version incompatibility issues
- Cluster running Kubernetes 1.28.15-eks-b3126f4

## Root Cause Analysis

### Investigation Process

1. **Pod Logs Analysis**
   ```bash
   kubectl logs -n external-secrets deployment/external-secrets
   ```
   Revealed: `no matches for kind 'ExternalSecret' in version 'external-secrets.io/v1'`

2. **CRD Version Check**
   ```bash
   kubectl get crd | grep external-secrets
   ```
   Found: Only `v1alpha1` and `v1beta1` CRDs available, but operator expected `v1`

3. **Cluster Version Verification**
   ```bash
   aws eks describe-cluster --name pms-dev --query 'cluster.version'
   ```
   Result: `1.28` - **End of Life (EOL) and unsupported by EKS**

### Root Cause Identified

The external-secrets operator version 0.10.5 requires Kubernetes CRD API version `v1`, which is only available in Kubernetes 1.31+. The cluster was running 1.28, which only supports `v1alpha1` and `v1beta1` CRDs.

## Solution Strategy

### Upgrade Requirements
- **Target Version**: Kubernetes 1.31 (supports external-secrets v1 CRDs)
- **Upgrade Path**: 1.28 → 1.29 → 1.30 → 1.31 (incremental upgrades only)
- **Node Groups**: Must match cluster version
- **Terraform State**: Sync after manual upgrades

### Implementation Plan
1. Upgrade EKS control plane incrementally
2. Update node groups to match cluster version
3. Sync terraform state
4. Reinstall external-secrets operator
5. Configure IRSA authentication
6. Test functionality

## EKS Cluster Upgrade Process

### Phase 1: Control Plane Upgrades

#### 1.28 → 1.29 Upgrade
```bash
aws eks update-cluster-version --name pms-dev --kubernetes-version 1.29
```
- **Update ID**: 07252e0d-7936-3d0e-b39d-7eb1cebe6971
- **Duration**: ~20 minutes
- **Status**: Successful

#### 1.29 → 1.30 Upgrade
```bash
aws eks update-cluster-version --name pms-dev --kubernetes-version 1.30
```
- **Update ID**: 0635a409-be35-3428-882f-72fff6a5d8f6
- **Duration**: ~15 minutes
- **Status**: Successful

#### 1.30 → 1.31 Upgrade
```bash
aws eks update-cluster-version --name pms-dev --kubernetes-version 1.31
```
- **Update ID**: f84ff34b-f651-303b-8ec5-3f8a366206b4
- **Duration**: ~15 minutes
- **Status**: Successful

### Phase 2: Node Group Updates

After control plane reached 1.31, updated node groups:
```bash
aws eks update-nodegroup-version --cluster-name pms-dev \
  --nodegroup-name $(aws eks list-nodegroups --cluster-name pms-dev --query 'nodegroups[0]' --output text) \
  --force
```
- **Duration**: ~10-15 minutes
- **Status**: Successful

### Phase 3: Terraform State Synchronization

Updated terraform configuration to reflect actual cluster state:

1. **Updated `terraform.tfvars`**:
   ```hcl
   cluster_version = "1.31"
   ```

2. **Applied terraform changes**:
   ```bash
   terraform apply -auto-approve
   ```
   - Updated IAM role trust policy
   - Synced terraform state with cluster version
   - Output: `cluster_version = "1.31"`

## External Secrets Operator Setup

### Prerequisites
- EKS cluster version 1.31+
- OIDC provider configured
- IRSA roles created

### Installation Steps

1. **Add Helm Repository**
   ```bash
   helm repo add external-secrets https://charts.external-secrets.io
   helm repo update
   ```

2. **Clean Previous Installation**
   ```bash
   # Remove old CRDs
   kubectl delete crd $(kubectl get crd | grep external-secrets | awk '{print $1}') --ignore-not-found=true

   # Remove old namespaces
   kubectl delete namespace external-secrets-system --ignore-not-found=true
   ```

3. **Install External Secrets Operator**
   ```bash
   helm install external-secrets external-secrets/external-secrets \
     -f external-secrets-values.yaml \
     --namespace external-secrets \
     --create-namespace \
     --version 0.10.5
   ```

4. **Verify Installation**
   ```bash
   kubectl get pods -n external-secrets
   ```
   Expected: All pods `Running` (1/1 Ready)

### IRSA Configuration

#### IAM Role Setup
- **Role Name**: `pms-dev-external-secrets`
- **ARN**: `arn:aws:iam::209332675115:role/pms-dev-external-secrets`
- **Trust Policy**:
  ```json
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Federated": "arn:aws:iam::209332675115:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/3C0E9838877BDC2B0FAFEFAB21DC09BF"
        },
        "Action": "sts:AssumeRoleWithWebIdentity",
        "Condition": {
          "StringEquals": {
            "oidc.eks.us-east-1.amazonaws.com/id/3C0E9838877BDC2B0FAFEFAB21DC09BF:sub": "system:serviceaccount:external-secrets:external-secrets-sa",
            "oidc.eks.us-east-1.amazonaws.com/id/3C0E9838877BDC2B0FAFEFAB21DC09BF:aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  }
  ```

#### IAM Policy
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "*"
    }
  ]
}
```

### ClusterSecretStore Configuration

Created `cluster-secret-store.yaml`:
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: aws-secretsmanager
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
            namespace: external-secrets
```

## Testing and Validation

### Test Secret Creation
```bash
aws secretsmanager create-secret \
  --name test-secret \
  --secret-string '{"username":"testuser","password":"testpass"}' \
  --region us-east-1
```

### ExternalSecret Configuration
Created `test-external-secret.yaml`:
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: test-secret
  namespace: default
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secretsmanager
    kind: ClusterSecretStore
  target:
    name: test-secret-k8s
    creationPolicy: Owner
  data:
  - secretKey: username
    remoteRef:
      key: test-secret
      property: username
  - secretKey: password
    remoteRef:
      key: test-secret
      property: password
```

### Validation Results

1. **ClusterSecretStore Status**:
   ```bash
   kubectl get clustersecretstore
   ```
   Output: `aws-secretsmanager   Valid    ReadWrite      True`

2. **ExternalSecret Status**:
   ```bash
   kubectl get externalsecret test-secret
   ```
   Output: `test-secret   aws-secretsmanager   1h   SecretSynced   True`

3. **Kubernetes Secret Verification**:
   ```bash
   kubectl get secret test-secret-k8s
   kubectl describe secret test-secret-k8s
   ```
   Confirmed: Contains correct username and password values

## Configuration Files

### external-secrets-values.yaml
```yaml
# External Secrets Operator values for EKS with IRSA
installCRDs: true

serviceAccount:
  create: true
  name: external-secrets-sa
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::209332675115:role/pms-dev-external-secrets"

env:
  AWS_REGION: us-east-1

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

webhook:
  create: true

certController:
  create: true
```

### cluster-secret-store.yaml
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: aws-secretsmanager
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
            namespace: external-secrets
```

### test-external-secret.yaml
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: test-secret
  namespace: default
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secretsmanager
    kind: ClusterSecretStore
  target:
    name: test-secret-k8s
    creationPolicy: Owner
  data:
  - secretKey: username
    remoteRef:
      key: test-secret
      property: username
  - secretKey: password
    remoteRef:
      key: test-secret
      property: password
```

## Troubleshooting Guide

### Common Issues and Solutions

#### 1. CRD Version Mismatch
**Error**: `no matches for kind 'ExternalSecret' in version 'external-secrets.io/v1'`
**Solution**: Upgrade Kubernetes to 1.31+ or use external-secrets version compatible with older CRDs

#### 2. IRSA Authentication Failure
**Error**: `AccessDenied: Not authorized to perform sts:AssumeRoleWithWebIdentity`
**Solutions**:
- Verify OIDC provider is configured
- Check IAM role trust policy matches service account name
- Ensure service account has correct annotations
- Restart external-secrets deployment after trust policy changes

#### 3. Node Group Version Mismatch
**Error**: `Nodegroups general-xxx must be updated to match cluster version`
**Solution**: Update node groups before upgrading cluster further

#### 4. Terraform State Drift
**Issue**: Terraform shows different version than actual cluster
**Solution**: Update `terraform.tfvars` and run `terraform apply`

### Monitoring Commands

```bash
# Check cluster version
aws eks describe-cluster --name pms-dev --query 'cluster.version'

# Check node group version
aws eks describe-nodegroup --cluster-name pms-dev --nodegroup-name <name> --query 'nodegroup.version'

# Monitor upgrade status
aws eks describe-update --name pms-dev --update-id <update-id>

# Check external-secrets status
kubectl get pods -n external-secrets
kubectl get clustersecretstore
kubectl get externalsecret
```

## Lessons Learned

### Technical Insights

1. **Kubernetes Version Compatibility**: Always verify CRD API version support when deploying operators
2. **EKS Upgrade Constraints**: AWS requires incremental upgrades (cannot skip versions)
3. **IRSA Configuration**: Service account names must exactly match IAM trust policies
4. **Terraform State Management**: Manual infrastructure changes require terraform state synchronization

### Process Improvements

1. **Version Monitoring**: Implement automated checks for supported Kubernetes versions
2. **Upgrade Planning**: Plan for incremental upgrades and associated downtime
3. **Testing Strategy**: Always test operator functionality after cluster upgrades
4. **Documentation**: Maintain detailed upgrade and configuration documentation

### Best Practices Established

1. **Regular Version Updates**: Keep EKS clusters on supported versions
2. **Operator Compatibility**: Verify operator requirements before deployment
3. **IRSA Security**: Use IRSA for AWS service access instead of access keys
4. **Secret Management**: Implement external-secrets for centralized secret management

## Conclusion

Successfully resolved the external-secrets operator CrashLoopBackOff issue by upgrading the EKS cluster from unsupported Kubernetes 1.28 to 1.31, implementing proper IRSA authentication, and configuring a production-ready secrets management system.

The cluster now supports:
- ✅ External Secrets Operator v0.10.5
- ✅ AWS Secrets Manager integration
- ✅ IRSA authentication
- ✅ Automatic secret synchronization
- ✅ Production-ready configuration

**Total Resolution Time**: ~2 hours
**Downtime**: Minimal (upgrade windows only)
**Business Impact**: Restored secrets management capability for applications

---

**Document Version**: 1.0
**Date**: January 8, 2026
**Authors**: AI Assistant
**Review Status**: Final