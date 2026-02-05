# PMS Service Images - Service-wise List

## Current Image References (Before Update)

| Service | Current Image | Status |
|---------|---------------|--------|
| analytics | sboomisnow/pms-analytics-app:latest | ✅ Keep |
| apigateway | niishantdev/pms-apigateway:latest | 🔄 Update to nehanawork1/pms-apigateway:latest |
| auth | niishantdev/pms-auth:latest | 🔄 Update to neha544/pms-auth:latest |
| crosscutting | niishantdev/pms-crosscutting:latest | ✅ Keep |
| frontend | niishantdev/pms-frontend:latest | ✅ Keep |
| leaderboard | niishantdev/pms-leaderboard:latest | ✅ Keep |
| portfolio | niishantdev/pms-portfolio:latest | 🔄 Update to nehanawork1/pms-portfolio:latest |
| rttm | sureshvasantha/pms-rttm:latest | ✅ Keep |
| simulation | niishantdev/pms-simulation:latest | 🔄 Update to nehanawork1/pms-simulation:latest |
| trade-capture | niishantdev/pms-trade-capture:latest | ✅ Keep |
| transactional | kovidms/pms-transactional:latest | ✅ Keep |
| validation | sureshvasantha/pms-validation:latest | ✅ Keep |

## Updated Image References (After Update)

| Service | Updated Image | Change |
|---------|---------------|--------|
| analytics | sboomisnow/pms-analytics-app:latest | No change |
| apigateway | nehanawork1/pms-apigateway:latest | Updated |
| auth | neha544/pms-auth:latest | Updated |
| crosscutting | niishantdev/pms-crosscutting:latest | No change |
| frontend | niishantdev/pms-frontend:latest | No change |
| leaderboard | niishantdev/pms-leaderboard:latest | No change |
| portfolio | nehanawork1/pms-portfolio:latest | Updated |
| rttm | sureshvasantha/pms-rttm:latest | No change |
| simulation | nehanawork1/pms-simulation:latest | Updated |
| trade-capture | niishantdev/pms-trade-capture:latest | No change |
| transactional | kovidms/pms-transactional:latest | No change |
| validation | sureshvasantha/pms-validation:latest | No change |

## Summary of Changes

**Services Updated (4):**
- simulation: `niishantdev/pms-simulation:latest` → `nehanawork1/pms-simulation:latest`
- auth: `niishantdev/pms-auth:latest` → `neha544/pms-auth:latest`
- portfolio: `niishantdev/pms-portfolio:latest` → `nehanawork1/pms-portfolio:latest`
- apigateway: `niishantdev/pms-apigateway:latest` → `nehanawork1/pms-apigateway:latest`

**Services Unchanged (8):**
- analytics, crosscutting, frontend, leaderboard, rttm, trade-capture, transactional, validation

## Deployment Instructions

After updating the values.yaml files, redeploy the affected services:

```bash
# Update Helm releases for changed services
helm upgrade simulation ./pms-infra/k8s/charts/services/simulation -n pms
helm upgrade auth ./pms-infra/k8s/charts/services/auth -n pms
helm upgrade portfolio ./pms-infra/k8s/charts/services/portfolio -n pms
helm upgrade apigateway ./pms-infra/k8s/charts/services/apigateway -n pms

# Verify deployments
kubectl get pods -n pms -l app.kubernetes.io/name=simulation
kubectl get pods -n pms -l app.kubernetes.io/name=auth
kubectl get pods -n pms -l app.kubernetes.io/name=portfolio
kubectl get pods -n pms -l app.kubernetes.io/name=apigateway
```

## Files Modified

- `/pms-infra/k8s/charts/services/simulation/values.yaml`
- `/pms-infra/k8s/charts/services/auth/values.yaml`
- `/pms-infra/k8s/charts/services/portfolio/values.yaml`
- `/pms-infra/k8s/charts/services/apigateway/values.yaml`

## Date: 2026-02-04
## Updated By: AI Assistant