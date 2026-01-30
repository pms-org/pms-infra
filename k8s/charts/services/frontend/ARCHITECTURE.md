# Frontend Kubernetes-Native Architecture

## Overview

The PMS frontend is now fully Kubernetes-native with **runtime configuration** instead of build-time environment variables. The same Docker image works across all environments (dev, staging, production) without rebuilding.

## Architecture Components

### 1. Runtime Configuration Injection

**ConfigMap Template:** `templates/env-configmap.yaml`
- Generates `env.js` from Helm values at deployment time
- Contains all backend service endpoints
- Mounted into NGINX container at `/usr/share/nginx/html/env.js`

**Deployment Volume Mount:** `templates/deployment.yaml`
```yaml
volumeMounts:
  - name: env-config
    mountPath: /usr/share/nginx/html/env.js
    subPath: env.js

volumes:
  - name: env-config
    configMap:
      name: frontend-env-config
```

### 2. Frontend Configuration Pattern

**Environment File:** `src/environments/environment.ts`
```typescript
const runtimeEnv = (window as any).__ENV__ || {};

export const environment = {
  apiGateway: {
    baseHttp: runtimeEnv.API_GATEWAY_HTTP || 'http://localhost:8088',
    baseWs: runtimeEnv.API_GATEWAY_WS || 'ws://localhost:8088',
  },
  // ... other services
};
```

**Index HTML:** `src/index.html`
```html
<head>
  <!-- Runtime configuration injected by Kubernetes ConfigMap -->
  <script src="env.js"></script>
</head>
```

### 3. Kubernetes Service Discovery

All backend services are referenced using **Kubernetes DNS names**:

```yaml
runtimeConfig:
  API_GATEWAY_HTTP: "http://apigateway:8088"
  API_GATEWAY_WS: "ws://apigateway:8088"
  AUTH_HTTP: "http://auth:8081"
  PORTFOLIO_HTTP: "http://portfolio:8095"
  PORTFOLIO_WS: "ws://portfolio:8095"
  ANALYTICS_HTTP: "http://analytics:8086"
  ANALYTICS_WS: "ws://analytics:8086"
  LEADERBOARD_HTTP: "http://leaderboard:8000"
  LEADERBOARD_WS: "ws://leaderboard:8000"
  RTTM_HTTP: "http://rttm:8087"
  RTTM_WS: "ws://rttm:8087"
```

These resolve to `<service-name>.<namespace>.svc.cluster.local` internally.

## Configuration Management

### Single Source of Truth

**File:** `pms-infra/k8s/pms-platform/values.yaml`

All frontend configuration is centralized under:
```yaml
frontend:
  enabled: true
  service:
    type: LoadBalancer
  runtimeConfig:
    # All service endpoints defined here
```

### Updating Configuration

**No Image Rebuild Required!**

1. Edit `pms-platform/values.yaml`:
   ```yaml
   frontend:
     runtimeConfig:
       API_GATEWAY_HTTP: "https://api.production.example.com"
   ```

2. Deploy changes:
   ```bash
   cd pms-infra/k8s/pms-platform
   helm upgrade --install pms-platform . --namespace pms
   ```

3. Frontend pods automatically pick up new configuration from the updated ConfigMap

### For Different Environments

The same approach works for dev/staging/prod:

**Option 1: Single values.yaml with conditionals**
```yaml
frontend:
  runtimeConfig:
    API_GATEWAY_HTTP: "{{ if eq .Values.global.environment \"prod\" }}https://api.prod.com{{ else }}http://apigateway:8088{{ end }}"
```

**Option 2: Per-environment values files (via `helm -f`)**
```bash
helm upgrade --install pms-platform . \
  --namespace pms \
  -f values.yaml \
  -f environments/prod/values-override.yaml
```

## Backend Service Endpoints

### REST APIs

| Service | Port | Health Check | Config Key |
|---------|------|--------------|------------|
| API Gateway | 8088 | /actuator/health | API_GATEWAY_HTTP |
| Auth | 8081 | /actuator/health | AUTH_HTTP |
| Portfolio | 8095 | /actuator/health | PORTFOLIO_HTTP |
| Analytics | 8086 | /actuator/health | ANALYTICS_HTTP |
| Leaderboard | 8000 | /actuator/health | LEADERBOARD_HTTP |
| RTTM | 8087 | /actuator/health | RTTM_HTTP |

### WebSocket Endpoints

| Service | WebSocket Path | Config Key |
|---------|----------------|------------|
| API Gateway | /ws/* | API_GATEWAY_WS |
| Portfolio | /ws/portfolio/* | PORTFOLIO_WS |
| Analytics | /ws/analytics/* | ANALYTICS_WS |
| Leaderboard | /ws/leaderboard/* | LEADERBOARD_WS |
| RTTM | /ws/rttm/* | RTTM_WS |

### RTTM WebSocket Endpoints

The RTTM service exposes multiple WebSocket endpoints:
- `/ws/rttm/metrics` - Real-time metrics
- `/ws/rttm/pipeline` - Pipeline status
- `/ws/rttm/dlq` - Dead letter queue
- `/ws/rttm/telemetry` - System telemetry
- `/ws/rttm/alerts` - Alert notifications

## Benefits

### ✅ Environment-Agnostic Container Image
- Same image for dev/staging/prod
- No environment-specific builds
- Faster CI/CD pipelines

### ✅ Runtime Configuration
- Change endpoints without rebuilding
- Instant configuration updates
- No frontend build required

### ✅ Kubernetes-Native Service Discovery
- Uses K8s internal DNS
- No hardcoded IPs or external URLs
- Automatic load balancing via K8s Services

### ✅ GitOps Compatible
- All config in Helm charts
- Version-controlled configuration
- ArgoCD can deploy automatically

### ✅ Local Development Support
- Falls back to localhost when `window.__ENV__` is undefined
- Developers can run `ng serve` locally
- No K8s cluster required for local dev

## Deployment Flow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Developer edits pms-platform/values.yaml                 │
│    (frontend.runtimeConfig section)                          │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. Helm template renders env-configmap.yaml                 │
│    - Loops through runtimeConfig values                      │
│    - Generates JavaScript window.__ENV__ object              │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. Kubernetes creates ConfigMap: frontend-env-config        │
│    - Contains env.js with all service URLs                   │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. Frontend Deployment mounts ConfigMap as volume           │
│    - Volume mounted to /usr/share/nginx/html/env.js          │
│    - NGINX serves env.js alongside static files              │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. Browser loads index.html                                 │
│    - Executes <script src="env.js"></script>                 │
│    - Sets window.__ENV__ with all backend URLs               │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ 6. Angular environment.ts reads window.__ENV__              │
│    - Falls back to localhost if undefined                    │
│    - Services use environment.apiGateway.baseHttp etc.       │
└─────────────────────────────────────────────────────────────┘
```

## Verification Commands

### Check ConfigMap
```bash
kubectl get configmap -n pms frontend-env-config -o yaml
```

### Verify Volume Mount
```bash
kubectl describe pod -n pms -l app=frontend | grep -A 5 "Mounts:"
```

### Test env.js in Container
```bash
kubectl exec -n pms <frontend-pod> -- cat /usr/share/nginx/html/env.js
```

### Get Frontend URL
```bash
kubectl get svc -n pms frontend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## Troubleshooting

### Frontend shows localhost URLs in production

**Cause:** ConfigMap not mounted or env.js not loaded

**Fix:**
```bash
# Check if ConfigMap exists
kubectl get configmap -n pms frontend-env-config

# Check if volume is mounted
kubectl describe pod -n pms -l app=frontend

# Verify env.js inside container
kubectl exec -n pms <pod-name> -- cat /usr/share/nginx/html/env.js

# Force pod restart to pick up ConfigMap
kubectl delete pod -n pms -l app=frontend
```

### WebSocket connections fail

**Cause:** WebSocket URLs using wrong protocol (http instead of ws)

**Fix:** Ensure `runtimeConfig` uses `ws://` or `wss://` for WebSocket URLs:
```yaml
runtimeConfig:
  API_GATEWAY_WS: "ws://apigateway:8088"  # Correct
  # NOT: "http://apigateway:8088"
```

### Configuration changes not reflected

**Cause:** Old ConfigMap cached or pods not restarted

**Fix:**
```bash
# Update ConfigMap via Helm
helm upgrade --install pms-platform . --namespace pms

# Force pod restart
kubectl rollout restart deployment/frontend -n pms
```

## Migration from Old Approach

### Before (Build-Time Configuration)
```dockerfile
# Multiple Dockerfiles or build args
ENV API_URL=http://production-api.com
RUN npm run build
```

**Problems:**
- Separate images for each environment
- Rebuild required for config changes
- Slow CI/CD pipelines
- No GitOps compatibility

### After (Runtime Configuration)
```yaml
# Single Dockerfile, runtime config via ConfigMap
runtimeConfig:
  API_GATEWAY_HTTP: "http://apigateway:8088"
```

**Benefits:**
- One image for all environments
- No rebuild for config changes
- Fast deployments
- Full GitOps support

## Related Files

- `pms-infra/k8s/charts/services/frontend/values.yaml` - Chart defaults
- `pms-infra/k8s/charts/services/frontend/templates/env-configmap.yaml` - ConfigMap template
- `pms-infra/k8s/charts/services/frontend/templates/deployment.yaml` - Deployment with volume
- `pms-infra/k8s/pms-platform/values.yaml` - Main configuration source of truth
- `pms-frontend/src/environments/environment.ts` - Frontend config consumer
- `pms-frontend/src/index.html` - Loads env.js script
- `pms-frontend/nginx.conf` - NGINX configuration

## Summary

The frontend is now a **first-class Kubernetes citizen** with:
- ✅ Runtime configuration via ConfigMap
- ✅ Kubernetes DNS-based service discovery  
- ✅ Environment-agnostic container images
- ✅ No hardcoded endpoints in source code
- ✅ No environment-specific builds
- ✅ Full GitOps and ArgoCD compatibility
- ✅ Single source of truth in `pms-platform/values.yaml`

**Configuration changes:** Edit Helm values → Deploy → Done (no image rebuild!)
