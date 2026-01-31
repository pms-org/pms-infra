# 🚀 Frontend EKS Deployment Guide

## Overview
This guide walks through preparing and deploying the PMS Frontend Angular application to Amazon EKS (Elastic Kubernetes Service).

## 📋 Table of Contents
1. [Prerequisites](#prerequisites)
2. [Frontend Architecture](#frontend-architecture)
3. [Configuration Strategy](#configuration-strategy)
4. [Build and Push Docker Image](#build-and-push-docker-image)
5. [Configure for EKS](#configure-for-eks)
6. [Deploy to EKS](#deploy-to-eks)
7. [Verify Deployment](#verify-deployment)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools
- ✅ Docker (for building images)
- ✅ kubectl (configured for your EKS cluster)
- ✅ Helm 3.x
- ✅ AWS CLI (configured with appropriate credentials)
- ✅ Node.js 20.x (for local builds)

### Verify EKS Cluster Access
```bash
# Verify kubectl is configured
kubectl cluster-info

# Check namespace
kubectl get ns pms || kubectl create ns pms

# Verify API Gateway is deployed and has LoadBalancer
kubectl get svc apigateway-service -n pms
```

### Get API Gateway LoadBalancer URL
```bash
# Get the LoadBalancer hostname
GATEWAY_LB=$(kubectl get svc apigateway-service -n pms \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
GATEWAY_PORT=$(kubectl get svc apigateway-service -n pms \
  -o jsonpath='{.spec.ports[0].port}')

echo "API Gateway URL: http://${GATEWAY_LB}:${GATEWAY_PORT}"
```

---

## Frontend Architecture

### How Frontend Works in Kubernetes

```
┌─────────────────────────────────────────────────────────┐
│                    Browser (Client)                      │
└──────────────────┬──────────────────────────────────────┘
                   │
                   │ HTTP Request
                   ↓
┌─────────────────────────────────────────────────────────┐
│          Frontend (NGINX + Static Angular Files)         │
│  ┌───────────────────────────────────────────────────┐  │
│  │  /usr/share/nginx/html/                           │  │
│  │  ├── index.html                                   │  │
│  │  ├── env.js  ← Runtime Config (ConfigMap)        │  │
│  │  ├── main.js                                      │  │
│  │  └── assets/                                      │  │
│  └───────────────────────────────────────────────────┘  │
└──────────────────┬──────────────────────────────────────┘
                   │
                   │ API Calls (reads env.js)
                   ↓
┌─────────────────────────────────────────────────────────┐
│              API Gateway LoadBalancer                    │
│         http://xxx.elb.amazonaws.com:8088               │
└──────────────────┬──────────────────────────────────────┘
                   │
                   │ Routes to services
                   ↓
            Backend Services
```

### Key Concepts

1. **Static Build:** Angular app is compiled to static files during Docker build
2. **Runtime Configuration:** Backend URLs are injected at deployment time via ConfigMap
3. **No Rebuild Required:** Same Docker image works across all environments (dev/staging/prod)
4. **NGINX Serving:** Production-optimized NGINX serves static files

---

## Configuration Strategy

### The Problem
- Angular apps typically bake environment config into the build (`environment.ts`)
- This means different builds for dev/staging/prod
- Not ideal for Kubernetes where we want environment-agnostic images

### The Solution: Runtime Configuration
1. **Build Time:** Angular is built with a placeholder configuration
2. **Deploy Time:** Kubernetes ConfigMap creates `env.js` with actual URLs
3. **Runtime:** Angular reads `window.__ENV__` from `env.js`

### Configuration Flow

```typescript
// 1. Build uses environment.docker.ts (internal K8s service names)
export const environment = {
  analytics: {
    baseHttp: 'http://analytics-service:8082',
    baseWs: 'ws://analytics-service:8082',
  },
  // ...
};

// 2. At deployment, ConfigMap creates env.js
(function(window) {
  window.__ENV__ = {
    API_GATEWAY_HTTP: "http://a3ed40b7b10934382a4b04887e88ef29-164917452.us-east-1.elb.amazonaws.com:8088",
    ANALYTICS_HTTP: "http://a3ed40b7b10934382a4b04887e88ef29-164917452.us-east-1.elb.amazonaws.com:8088",
    // ...
  };
})(window);

// 3. Frontend reads runtime config
const apiUrl = window.__ENV__?.API_GATEWAY_HTTP || environment.analytics.baseHttp;
```

---

## Build and Push Docker Image

### Step 1: Review Dockerfile

The frontend Dockerfile uses multi-stage build:

```dockerfile
# Build stage - Compile Angular app
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build -- --configuration=docker

# Production stage - Serve with NGINX
FROM nginx:alpine
COPY --from=build /app/dist/pms-frontend/browser /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### Step 2: Build Docker Image

```bash
# Navigate to frontend directory
cd /mnt/c/Developer/pms-org/pms-frontend

# Build the image
docker build -t niishantdev/pms-frontend:latest .

# Tag for specific version (optional)
docker tag niishantdev/pms-frontend:latest niishantdev/pms-frontend:v1.0.0
```

### Step 3: Push to Docker Registry

```bash
# Login to Docker Hub (or your registry)
docker login

# Push latest tag
docker push niishantdev/pms-frontend:latest

# Push version tag (optional)
docker push niishantdev/pms-frontend:v1.0.0
```

### Alternative: Build and Push in One Command

```bash
cd /mnt/c/Developer/pms-org/pms-frontend

# Build and push
docker build -t niishantdev/pms-frontend:latest . && \
docker push niishantdev/pms-frontend:latest
```

---

## Configure for EKS

### Step 1: Update Runtime Configuration

Edit the values file to point to your actual API Gateway LoadBalancer:

**File:** `/mnt/c/Developer/pms-org/pms-infra/k8s/pms-platform/values.yaml`

```yaml
frontend:
  enabled: true
  service:
    type: LoadBalancer
  deployment:
    image:
      repository: niishantdev/pms-frontend
      tag: latest
      pullPolicy: Always
    healthChecks:
      enabled: true
  
  # Runtime configuration - UPDATE THESE VALUES
  runtimeConfig:
    # Get these from: kubectl get svc apigateway-service -n pms
    API_GATEWAY_HTTP: "http://<YOUR-API-GATEWAY-LB>:8088"
    API_GATEWAY_WS: "ws://<YOUR-API-GATEWAY-LB>:8088"
    
    # All services route through API Gateway
    AUTH_HTTP: "http://<YOUR-API-GATEWAY-LB>:8088"
    PORTFOLIO_HTTP: "http://<YOUR-API-GATEWAY-LB>:8088"
    PORTFOLIO_WS: "ws://<YOUR-API-GATEWAY-LB>:8088"
    ANALYTICS_HTTP: "http://<YOUR-API-GATEWAY-LB>:8088"
    ANALYTICS_WS: "ws://<YOUR-API-GATEWAY-LB>:8088"
    LEADERBOARD_HTTP: "http://<YOUR-API-GATEWAY-LB>:8088"
    LEADERBOARD_WS: "ws://<YOUR-API-GATEWAY-LB>:8088"
    RTTM_HTTP: "http://<YOUR-API-GATEWAY-LB>:8088"
    RTTM_WS: "ws://<YOUR-API-GATEWAY-LB>:8088"
```

### Step 2: Quick Update Script

```bash
#!/bin/bash
# Get API Gateway LoadBalancer URL
GATEWAY_LB=$(kubectl get svc apigateway-service -n pms \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
GATEWAY_PORT=$(kubectl get svc apigateway-service -n pms \
  -o jsonpath='{.spec.ports[0].port}')

GATEWAY_URL="http://${GATEWAY_LB}:${GATEWAY_PORT}"
GATEWAY_WS_URL="ws://${GATEWAY_LB}:${GATEWAY_PORT}"

echo "API Gateway HTTP: $GATEWAY_URL"
echo "API Gateway WS: $GATEWAY_WS_URL"

# Update values.yaml (manual step - see above)
echo ""
echo "Update pms-platform/values.yaml with these values:"
echo "  API_GATEWAY_HTTP: \"$GATEWAY_URL\""
echo "  API_GATEWAY_WS: \"$GATEWAY_WS_URL\""
```

### Step 3: Verify NGINX Configuration

The frontend uses a custom NGINX config optimized for Angular:

**File:** `/mnt/c/Developer/pms-org/pms-frontend/nginx.conf`

Key features:
- Gzip compression for performance
- SPA routing (all routes → index.html)
- Proper caching headers
- Security headers

---

## Deploy to EKS

### Method 1: Using Helm (Recommended)

```bash
# Navigate to infra directory
cd /mnt/c/Developer/pms-org/pms-infra

# Deploy entire platform (includes frontend)
helm upgrade --install pms-platform k8s/pms-platform \
  --namespace pms \
  --create-namespace \
  --values k8s/environments/dev/values.yaml \
  --wait

# Or deploy only frontend
helm upgrade --install pms-platform k8s/pms-platform \
  --namespace pms \
  --set frontend.enabled=true \
  --set apigateway.enabled=false \
  --set analytics.enabled=false \
  --set leaderboard.enabled=false \
  --set rttm.enabled=false \
  --wait
```

### Method 2: Using kubectl

```bash
# Apply frontend chart directly
cd /mnt/c/Developer/pms-org/pms-infra

# Generate manifests
helm template frontend k8s/charts/services/frontend \
  --namespace pms \
  > frontend-manifests.yaml

# Apply
kubectl apply -f frontend-manifests.yaml -n pms
```

### Method 3: Rolling Update (Update Image Only)

```bash
# Update image without redeploying
kubectl set image deployment/frontend \
  frontend=niishantdev/pms-frontend:latest \
  -n pms

# Or use Helm upgrade
helm upgrade pms-platform k8s/pms-platform \
  --namespace pms \
  --reuse-values \
  --set frontend.deployment.image.tag=latest
```

---

## Verify Deployment

### Step 1: Check Pod Status

```bash
# Watch pods starting up
kubectl get pods -n pms -l app=frontend -w

# Expected output:
# NAME                        READY   STATUS    RESTARTS   AGE
# frontend-xxxxxxxxxx-xxxxx   1/1     Running   0          30s
```

### Step 2: Check Logs

```bash
# View frontend logs
kubectl logs -f deployment/frontend -n pms

# Should show NGINX starting:
# nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
# nginx: configuration file /etc/nginx/nginx.conf test is successful
```

### Step 3: Verify Service and LoadBalancer

```bash
# Get service details
kubectl get svc frontend-service -n pms

# Expected output:
# NAME               TYPE           CLUSTER-IP       EXTERNAL-IP                        PORT(S)
# frontend-service   LoadBalancer   10.100.xxx.xxx   xxx.elb.amazonaws.com              80:xxxxx/TCP

# Get LoadBalancer URL
FRONTEND_URL=$(kubectl get svc frontend-service -n pms \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Frontend URL: http://$FRONTEND_URL"
```

### Step 4: Test Frontend Access

```bash
# Test index page
curl http://$FRONTEND_URL/

# Should return HTML content with <!doctype html>

# Test runtime config
curl http://$FRONTEND_URL/env.js

# Should return:
# (function(window) {
#   window.__ENV__ = {
#     API_GATEWAY_HTTP: "http://...",
#     ...
#   };
# })(window);
```

### Step 5: Browser Testing

1. Open browser: `http://<FRONTEND_URL>`
2. Open DevTools → Console
3. Check for errors
4. Verify `window.__ENV__` is populated:
   ```javascript
   console.log(window.__ENV__)
   // Should show all runtime config values
   ```

### Step 6: Test Backend Connectivity

```bash
# From your local machine
# Test login through frontend → API Gateway → Auth service

curl -X POST http://$FRONTEND_URL/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"test123"}'
```

---

## Troubleshooting

### Issue: Pod Not Starting

**Symptoms:**
```bash
kubectl get pods -n pms
# frontend-xxx   0/1   ImagePullBackOff
```

**Solution:**
```bash
# Check events
kubectl describe pod <pod-name> -n pms

# Common causes:
# 1. Image doesn't exist
docker pull niishantdev/pms-frontend:latest

# 2. Wrong image name in values.yaml
# Check: frontend.deployment.image.repository

# 3. Need to pull from private registry
kubectl create secret docker-registry regcred \
  --docker-server=<your-registry> \
  --docker-username=<username> \
  --docker-password=<password> \
  -n pms
```

### Issue: LoadBalancer Pending

**Symptoms:**
```bash
kubectl get svc frontend-service -n pms
# EXTERNAL-IP shows <pending>
```

**Solution:**
```bash
# Wait for AWS to provision (can take 2-5 minutes)
kubectl get svc frontend-service -n pms -w

# Check AWS Load Balancer Controller is running
kubectl get pods -n kube-system | grep aws-load-balancer

# If not installed, install AWS Load Balancer Controller:
# https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html
```

### Issue: 404 for All Routes

**Symptoms:**
- Frontend loads on `/` but returns 404 on `/dashboard`, `/portfolio`, etc.

**Solution:**
Check NGINX config has SPA routing:
```nginx
location / {
    try_files $uri $uri/ /index.html;
}
```

This is already in `nginx.conf` - verify it's being copied in Dockerfile.

### Issue: env.js Not Loading

**Symptoms:**
- `window.__ENV__` is undefined
- Browser shows 404 for `/env.js`

**Solution:**
```bash
# Verify ConfigMap exists
kubectl get configmap frontend-env-config -n pms

# Check ConfigMap content
kubectl describe configmap frontend-env-config -n pms

# Verify it's mounted in pod
kubectl exec -it <frontend-pod> -n pms -- ls -la /usr/share/nginx/html/env.js

# Restart pod to pick up ConfigMap changes
kubectl rollout restart deployment/frontend -n pms
```

### Issue: Can't Connect to Backend Services

**Symptoms:**
- CORS errors in browser console
- Network errors when calling API

**Solution:**
```bash
# 1. Verify API Gateway is running and has LoadBalancer
kubectl get svc apigateway-service -n pms

# 2. Test API Gateway directly
GATEWAY=$(kubectl get svc apigateway-service -n pms \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl http://$GATEWAY:8088/api/analysis/all

# 3. Check frontend is using correct API Gateway URL
kubectl exec -it <frontend-pod> -n pms -- cat /usr/share/nginx/html/env.js

# 4. Verify CORS headers in API Gateway
curl -v -H "Origin: http://example.com" \
  http://$GATEWAY:8088/api/analysis/all
```

### Issue: WebSocket Connection Failures

**Symptoms:**
- WebSocket connections fail or disconnect
- Error: "WebSocket connection failed"

**Solution:**
```bash
# 1. Verify LoadBalancer supports WebSocket
# AWS ALB supports WebSocket by default
# Check target groups have connection draining configured

# 2. Test WebSocket upgrade
wscat -c ws://$GATEWAY:8088/ws

# 3. Check backend service WebSocket config
kubectl logs <analytics-pod> -n pms | grep -i websocket

# 4. Verify frontend uses ws:// not http:// for WebSocket URLs
grep -r "ANALYTICS_WS" pms-infra/k8s/pms-platform/values.yaml
```

---

## Health Checks

The frontend deployment includes health checks:

```yaml
livenessProbe:
  httpGet:
    path: /
    port: 80
  initialDelaySeconds: 30
  periodSeconds: 30
  
readinessProbe:
  httpGet:
    path: /
    port: 80
  initialDelaySeconds: 10
  periodSeconds: 10

startupProbe:
  httpGet:
    path: /
    port: 80
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 10
```

**Check Health:**
```bash
# View probe status
kubectl describe pod <frontend-pod> -n pms | grep -A 5 "Liveness\|Readiness"
```

---

## Performance Optimization

### NGINX Tuning

The included `nginx.conf` already has:
- ✅ Gzip compression (HTML, CSS, JS)
- ✅ Browser caching for static assets
- ✅ Security headers
- ✅ SPA routing support

### Resource Limits

Current settings in `values.yaml`:
```yaml
resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 128Mi
```

**Adjust if needed:**
```bash
helm upgrade pms-platform k8s/pms-platform \
  --namespace pms \
  --reuse-values \
  --set frontend.deployment.resources.limits.memory=256Mi
```

---

## Quick Reference

### Common Commands

```bash
# Get frontend URL
kubectl get svc frontend-service -n pms \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# View logs
kubectl logs -f deployment/frontend -n pms

# Restart frontend
kubectl rollout restart deployment/frontend -n pms

# Update runtime config
# 1. Edit pms-platform/values.yaml
# 2. Run:
helm upgrade pms-platform k8s/pms-platform --namespace pms

# Scale replicas
kubectl scale deployment frontend --replicas=3 -n pms

# Delete frontend
kubectl delete deployment,svc,configmap -l app=frontend -n pms
```

### Deployment Checklist

- [ ] Build Docker image
- [ ] Push to registry
- [ ] Get API Gateway LoadBalancer URL
- [ ] Update `pms-platform/values.yaml` with correct URLs
- [ ] Deploy using Helm
- [ ] Verify pod is running
- [ ] Verify LoadBalancer is provisioned
- [ ] Test frontend access in browser
- [ ] Verify `env.js` is loaded
- [ ] Test backend API calls work
- [ ] Run endpoint test script

---

## Next Steps

1. **Enable HTTPS:**
   - Use AWS Certificate Manager
   - Configure ALB with SSL certificate
   - Update URLs to use `https://`

2. **Configure Custom Domain:**
   - Add Route53 DNS record
   - Point to LoadBalancer
   - Update CORS in API Gateway

3. **Setup CI/CD:**
   - See `pms-infra/ci/github-actions/`
   - Automate build → push → deploy

4. **Enable Monitoring:**
   - Add Prometheus metrics
   - Setup CloudWatch logs
   - Configure alerts

---

**Last Updated:** January 30, 2026
