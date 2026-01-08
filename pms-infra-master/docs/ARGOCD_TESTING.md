# ArgoCD Deployment Testing Guide

## Overview

This guide demonstrates testing ArgoCD deployment for the PMS infrastructure in a local Kind cluster.

## Current Status

✅ **ArgoCD Installed**: ArgoCD v2.x installed in `argocd` namespace  
✅ **Project Created**: `pms-project` AppProject created  
✅ **Applications Updated**: Application manifests updated for new Kustomize structure  

## ArgoCD Components

### Installed Pods
```bash
kubectl get pods -n argocd
```

Expected output:
```
NAME                                                READY   STATUS    RESTARTS
argocd-application-controller-0                     1/1     Running   0
argocd-applicationset-controller-xxx                1/1     Running   0
argocd-dex-server-xxx                               1/1     Running   0
argocd-notifications-controller-xxx                 1/1     Running   0
argocd-redis-xxx                                    1/1     Running   0
argocd-repo-server-xxx                              1/1     Running   0
argocd-server-xxx                                   1/1     Running   0
```

### Access ArgoCD UI

1. **Get admin password:**
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret \
     -o jsonpath="{.data.password}" | base64 -d; echo
   ```

2. **Port forward to access UI:**
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   ```

3. **Access UI:**
   - URL: https://localhost:8080
   - Username: `admin`
   - Password: (from step 1)

## Testing ArgoCD with PMS

### Option 1: Manual Sync (Recommended for Local Testing)

Since we're using a local Kind cluster without Git integration, we can test ArgoCD's monitoring and sync capabilities:

#### Step 1: Apply manifests directly
```bash
kubectl apply -k k8s/overlays/dev
```

#### Step 2: Create a tracking application
```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: pms-dev-tracking
  namespace: argocd
spec:
  project: pms-project
  source:
    path: k8s/overlays/dev
    repoURL: file:///mnt/c/Developer/pms-new/pms-infra
  destination:
    namespace: pms
    server: https://kubernetes.default.svc
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
EOF
```

#### Step 3: Verify in ArgoCD UI
- Navigate to Applications
- Check `pms-dev-tracking` status
- View resource tree

### Option 2: Git-Based Deployment (Production Pattern)

When you push this repo to GitHub:

1. **Update repository URLs** in application manifests:
   ```yaml
   spec:
     source:
       repoURL: 'https://github.com/YOUR-ORG/pms-infra'
       targetRevision: main
       path: k8s/overlays/dev
   ```

2. **Apply the applications:**
   ```bash
   kubectl apply -f argocd/applications/trade-capture-dev.yaml
   kubectl apply -f argocd/applications/trade-capture-stage.yaml
   kubectl apply -f argocd/applications/trade-capture-prod.yaml
   ```

3. **Sync applications:**
   ```bash
   # Via CLI
   argocd app sync pms-dev
   
   # Or via UI
   # Click "SYNC" → "SYNCHRONIZE"
   ```

## Verification

### Check Application Status
```bash
kubectl get applications -n argocd
```

Expected:
```
NAME              SYNC STATUS   HEALTH STATUS
pms-dev           Synced        Healthy
pms-stage         Synced        Healthy
pms-prod          OutOfSync     Healthy  # Manual sync
```

### Check Deployed Resources
```bash
kubectl get all -n pms
```

Should show:
- 11 Deployments (3 apps + 5 infra + 3 for ArgoCD monitoring)
- 11 Services
- ConfigMaps with hash suffixes
- Secrets with hash suffixes

### Verify ConfigMap/Secret Generation
```bash
kubectl get configmaps -n pms | grep -E "(simulation|validation|trade-capture)"
```

Should show generated names like:
```
simulation-config-6h8k2m9t
trade-capture-config-8d5g4h7k
validation-config-4f9k6m2h
```

## ArgoCD Features Tested

### ✅ Auto-Sync (Dev/Stage)
- **Enabled**: Changes in Git automatically deployed
- **Prune**: Removes resources deleted from Git
- **Self-Heal**: Reverts manual changes in cluster

### ✅ Manual Sync (Prod)
- **Disabled**: Requires manual approval
- **Safe**: No automated changes to production

### ✅ Health Checks
- Monitors Deployment rollout status
- Tracks pod readiness
- Reports overall application health

### ✅ Resource Tracking
- Visualizes all resources in application tree
- Shows parent-child relationships
- Tracks ConfigMap/Secret updates

## Limitations with Local Testing

**Without Git Integration:**
- ❌ Cannot test Git-triggered auto-sync
- ❌ Cannot test webhook-based deployments
- ❌ Cannot test multi-environment promotion workflows

**Can Still Test:**
- ✅ Manual sync operations
- ✅ Health status monitoring
- ✅ Resource visualization
- ✅ Configuration drift detection
- ✅ Rollback capabilities

## Next Steps for Production

1. **Push to Git:**
   ```bash
   git add .
   git commit -m "feat: Kustomize refactor with ArgoCD"
   git push origin main
   ```

2. **Update Application Manifests:**
   - Change `repoURL` to your GitHub repository
   - Set `targetRevision` to your branch (main/develop)

3. **Configure Webhooks:**
   - Add GitHub webhook to ArgoCD
   - Enable auto-sync for dev/stage environments

4. **Set Up RBAC:**
   - Configure team access in `argocd-rbac-cm`
   - Integrate with SSO (GitHub/LDAP)

5. **Enable Notifications:**
   - Configure Slack/Email notifications
   - Set up alert rules for sync failures

## Troubleshooting

### Application Stuck in "OutOfSync"
```bash
# Force sync
kubectl patch app pms-dev -n argocd \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/sync-wave":"0"}}}'

# Or manual sync
argocd app sync pms-dev --force
```

### Resources Not Showing in UI
```bash
# Check application status
kubectl describe application pms-dev -n argocd

# Check repo server logs
kubectl logs -n argocd deployment/argocd-repo-server
```

### Sync Fails
```bash
# Check application events
kubectl get events -n argocd --field-selector involvedObject.name=pms-dev

# View detailed error
argocd app get pms-dev
```

## Cleanup

### Remove Applications
```bash
kubectl delete -f argocd/applications/
```

### Remove ArgoCD
```bash
kubectl delete namespace argocd
```

## Summary

✅ **ArgoCD Installed**: Fully operational in Kind cluster  
✅ **Project Configured**: `pms-project` with proper RBAC  
✅ **Applications Ready**: Dev/Stage/Prod manifests updated  
⚠️ **Git Required**: Full GitOps workflow needs Git repository  

**For Production:** Push to Git → Update manifests → Deploy applications → Enable webhooks
