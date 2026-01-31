# ✅ Endpoint Testing & Frontend Deployment Checklist

## Overview
This checklist guides you through testing all PMS platform endpoints and deploying the frontend to EKS.

---

## Phase 1: Environment Preparation

### 1.1 Verify EKS Cluster Access
- [ ] Verify kubectl is configured
  ```bash
  kubectl cluster-info
  kubectl get nodes
  ```
- [ ] Verify namespace exists
  ```bash
  kubectl get ns pms || kubectl create ns pms
  ```
- [ ] Check AWS credentials
  ```bash
  aws sts get-caller-identity
  ```

### 1.2 Verify Backend Services
- [ ] Check all services are deployed
  ```bash
  kubectl get pods -n pms
  ```
- [ ] Verify services are healthy
  ```bash
  kubectl get deployments -n pms
  ```
- [ ] Check API Gateway LoadBalancer
  ```bash
  kubectl get svc apigateway-service -n pms
  ```

Expected services:
- ✅ API Gateway (apigateway-service)
- ✅ Auth Service (auth-service)
- ✅ Portfolio Service (portfolio-service)
- ✅ Analytics Service (analytics-service)
- ✅ Leaderboard Service (leaderboard-service)
- ✅ RTTM Service (rttm-service)
- ✅ Simulation Service (simulation-service)

---

## Phase 2: Endpoint Testing

### 2.1 Get LoadBalancer URLs
- [ ] Get API Gateway URL
  ```bash
  GATEWAY_LB=$(kubectl get svc apigateway-service -n pms \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
  GATEWAY_PORT=$(kubectl get svc apigateway-service -n pms \
    -o jsonpath='{.spec.ports[0].port}')
  
  echo "API Gateway: http://${GATEWAY_LB}:${GATEWAY_PORT}"
  ```

### 2.2 Run Automated Endpoint Tests
- [ ] Make test script executable
  ```bash
  cd /mnt/c/Developer/pms-org/pms-infra/scripts
  chmod +x test-endpoints.sh
  ```
- [ ] Run endpoint tests
  ```bash
  ./test-endpoints.sh --namespace pms
  ```
- [ ] Review test results
  - Expected: All tests should pass
  - If failures: Check service logs
    ```bash
    kubectl logs <pod-name> -n pms
    ```

### 2.3 Manual Endpoint Verification

#### API Gateway
- [ ] Test fallback endpoint
  ```bash
  curl http://${GATEWAY_LB}:${GATEWAY_PORT}/fallback
  ```
  Expected: HTTP 200

#### Auth Service
- [ ] Test signup
  ```bash
  curl -X POST http://${GATEWAY_LB}:${GATEWAY_PORT}/api/auth/signup \
    -H "Content-Type: application/json" \
    -d '{"username":"testuser","password":"test123","email":"test@example.com"}'
  ```
- [ ] Test login
  ```bash
  curl -X POST http://${GATEWAY_LB}:${GATEWAY_PORT}/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"testuser","password":"test123"}'
  ```

#### Portfolio Service
- [ ] Get all portfolios
  ```bash
  curl http://${GATEWAY_LB}:${GATEWAY_PORT}/api/portfolio/all
  ```
- [ ] Create portfolio
  ```bash
  curl -X POST http://${GATEWAY_LB}:${GATEWAY_PORT}/api/portfolio/create \
    -H "Content-Type: application/json" \
    -d '{"name":"Test Portfolio"}'
  ```

#### Analytics Service
- [ ] Get all analysis
  ```bash
  curl http://${GATEWAY_LB}:${GATEWAY_PORT}/api/analysis/all
  ```
- [ ] Get sector overview
  ```bash
  curl http://${GATEWAY_LB}:${GATEWAY_PORT}/api/sectors/overall
  ```
- [ ] Get unrealized PnL
  ```bash
  curl http://${GATEWAY_LB}:${GATEWAY_PORT}/api/unrealized
  ```

#### Leaderboard Service
- [ ] Get top performers
  ```bash
  curl http://${GATEWAY_LB}:${GATEWAY_PORT}/api/leaderboard/top
  ```
- [ ] Get around portfolio
  ```bash
  curl "http://${GATEWAY_LB}:${GATEWAY_PORT}/api/leaderboard/around?portfolioId=P001"
  ```

#### RTTM Service
- [ ] Get metrics
  ```bash
  curl http://${GATEWAY_LB}:${GATEWAY_PORT}/api/rttm/metrics
  ```
- [ ] Get pipeline
  ```bash
  curl http://${GATEWAY_LB}:${GATEWAY_PORT}/api/rttm/pipeline
  ```
- [ ] Get telemetry
  ```bash
  curl http://${GATEWAY_LB}:${GATEWAY_PORT}/api/rttm/telemetry-snapshot
  ```
- [ ] Get DLQ
  ```bash
  curl http://${GATEWAY_LB}:${GATEWAY_PORT}/api/rttm/dlq
  ```
- [ ] Get alerts
  ```bash
  curl http://${GATEWAY_LB}:${GATEWAY_PORT}/api/rttm/alerts
  ```

#### Simulation Service
- [ ] Create simulated portfolio
  ```bash
  curl -X POST http://${GATEWAY_LB}:${GATEWAY_PORT}/simulation/create-portfolio \
    -H "Content-Type: application/json" \
    -d '{}'
  ```

### 2.4 WebSocket Testing (Optional)
- [ ] Install wscat
  ```bash
  npm install -g wscat
  ```
- [ ] Test Analytics WebSocket
  ```bash
  wscat -c ws://${GATEWAY_LB}:${GATEWAY_PORT}/ws
  ```
- [ ] Test Leaderboard WebSocket
  ```bash
  wscat -c ws://${GATEWAY_LB}:${GATEWAY_PORT}/ws/updates
  ```
- [ ] Test RTTM WebSocket
  ```bash
  wscat -c ws://${GATEWAY_LB}:${GATEWAY_PORT}/ws/rttm/metrics
  ```

### 2.5 Document Test Results
- [ ] Save successful endpoint URLs
- [ ] Document any failing endpoints
- [ ] Create issue tickets for failures

---

## Phase 3: Frontend Preparation

### 3.1 Verify Frontend Code
- [ ] Navigate to frontend directory
  ```bash
  cd /mnt/c/Developer/pms-org/pms-frontend
  ```
- [ ] Verify Dockerfile exists
  ```bash
  ls -la Dockerfile
  ```
- [ ] Verify nginx.conf exists
  ```bash
  ls -la nginx.conf
  ```
- [ ] Verify package.json
  ```bash
  cat package.json
  ```

### 3.2 Build Docker Image
- [ ] Login to Docker registry
  ```bash
  docker login
  ```
- [ ] Build frontend image
  ```bash
  docker build -t niishantdev/pms-frontend:latest .
  ```
  Expected: Build succeeds
- [ ] Verify image
  ```bash
  docker images | grep pms-frontend
  ```

### 3.3 Push Docker Image
- [ ] Push to registry
  ```bash
  docker push niishantdev/pms-frontend:latest
  ```
- [ ] Verify in registry
  - Login to Docker Hub
  - Verify image exists

---

## Phase 4: Frontend Deployment

### 4.1 Configure Helm Values
- [ ] Get API Gateway LoadBalancer URL
  ```bash
  GATEWAY_LB=$(kubectl get svc apigateway-service -n pms \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
  echo "API Gateway: http://${GATEWAY_LB}:8088"
  ```
- [ ] Update values file
  ```bash
  cd /mnt/c/Developer/pms-org/pms-infra
  nano k8s/pms-platform/values.yaml
  ```
- [ ] Update runtime config section with actual LoadBalancer URL:
  ```yaml
  frontend:
    runtimeConfig:
      API_GATEWAY_HTTP: "http://<GATEWAY_LB>:8088"
      API_GATEWAY_WS: "ws://<GATEWAY_LB>:8088"
      # ... update all other URLs
  ```

### 4.2 Deploy Frontend (Option A: Automated)
- [ ] Make deploy script executable
  ```bash
  cd /mnt/c/Developer/pms-org/pms-infra/scripts
  chmod +x deploy-frontend.sh
  ```
- [ ] Run deployment script
  ```bash
  ./deploy-frontend.sh --namespace pms
  ```
- [ ] Wait for completion

### 4.2 Deploy Frontend (Option B: Manual)
- [ ] Deploy using Helm
  ```bash
  cd /mnt/c/Developer/pms-org/pms-infra
  
  helm upgrade --install pms-platform k8s/pms-platform \
    --namespace pms \
    --create-namespace \
    --wait \
    --timeout 5m
  ```

### 4.3 Verify Frontend Deployment
- [ ] Check pod status
  ```bash
  kubectl get pods -n pms -l app=frontend
  ```
  Expected: STATUS = Running, READY = 1/1
  
- [ ] Check logs
  ```bash
  kubectl logs -f deployment/frontend -n pms
  ```
  Expected: NGINX started successfully
  
- [ ] Check service
  ```bash
  kubectl get svc frontend-service -n pms
  ```
  Expected: TYPE = LoadBalancer, EXTERNAL-IP = <hostname>
  
- [ ] Get frontend URL
  ```bash
  FRONTEND_URL=$(kubectl get svc frontend-service -n pms \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
  echo "Frontend URL: http://${FRONTEND_URL}"
  ```

---

## Phase 5: Frontend Verification

### 5.1 Test Frontend Static Files
- [ ] Test index page
  ```bash
  curl http://${FRONTEND_URL}/
  ```
  Expected: HTML content with `<!doctype html>`
  
- [ ] Test runtime config
  ```bash
  curl http://${FRONTEND_URL}/env.js
  ```
  Expected: JavaScript with `window.__ENV__`
  
- [ ] Verify env.js content
  ```bash
  curl -s http://${FRONTEND_URL}/env.js | grep API_GATEWAY_HTTP
  ```
  Expected: Shows correct API Gateway URL

### 5.2 Browser Testing
- [ ] Open frontend in browser
  ```
  http://<FRONTEND_URL>
  ```
- [ ] Open browser DevTools (F12)
- [ ] Check Console for errors
  - No JavaScript errors
  - No network errors
  
- [ ] Verify runtime config loaded
  ```javascript
  // In browser console
  console.log(window.__ENV__)
  ```
  Expected: Object with all service URLs
  
- [ ] Test navigation
  - [ ] Login page loads
  - [ ] Dashboard route works
  - [ ] Portfolio page works
  - [ ] Leaderboard page works
  - [ ] RTTM page works

### 5.3 Test Backend Integration
- [ ] Test login functionality
  - Enter credentials
  - Submit form
  - Verify API call in Network tab
  - Check response
  
- [ ] Test dashboard data
  - Navigate to dashboard
  - Verify API calls to analytics
  - Check data displays correctly
  
- [ ] Test WebSocket connections
  - Monitor Network tab → WS
  - Verify WebSocket connections established
  - Check for real-time updates

### 5.4 Performance Check
- [ ] Check page load time
  - Should be < 3 seconds
  
- [ ] Verify gzip compression
  ```bash
  curl -H "Accept-Encoding: gzip" -I http://${FRONTEND_URL}/
  ```
  Expected: `Content-Encoding: gzip`
  
- [ ] Check resource caching
  - Open Network tab
  - Reload page
  - Verify static assets cached (304 responses)

---

## Phase 6: Health & Monitoring

### 6.1 Check Health Probes
- [ ] Verify liveness probe
  ```bash
  kubectl describe pod <frontend-pod> -n pms | grep -A 5 Liveness
  ```
  
- [ ] Verify readiness probe
  ```bash
  kubectl describe pod <frontend-pod> -n pms | grep -A 5 Readiness
  ```

### 6.2 Monitor Resources
- [ ] Check resource usage
  ```bash
  kubectl top pod -n pms -l app=frontend
  ```
  
- [ ] Verify within limits
  - CPU: < 200m
  - Memory: < 128Mi

### 6.3 Check Events
- [ ] Review pod events
  ```bash
  kubectl describe pod <frontend-pod> -n pms
  ```
  Expected: No error events

---

## Phase 7: Documentation

### 7.1 Document URLs
Create a file with all URLs for easy access:

```bash
# Save to urls.txt
cat > /mnt/c/Developer/pms-org/pms-infra/DEPLOYMENT_URLS.txt << EOF
PMS Platform URLs
=================

API Gateway: http://${GATEWAY_LB}:${GATEWAY_PORT}
Frontend: http://${FRONTEND_URL}

Services (via API Gateway):
- Auth: ${GATEWAY_LB}:${GATEWAY_PORT}/api/auth
- Portfolio: ${GATEWAY_LB}:${GATEWAY_PORT}/api/portfolio
- Analytics: ${GATEWAY_LB}:${GATEWAY_PORT}/api/analysis
- Leaderboard: ${GATEWAY_LB}:${GATEWAY_PORT}/api/leaderboard
- RTTM: ${GATEWAY_LB}:${GATEWAY_PORT}/api/rttm
- Simulation: ${GATEWAY_LB}:${GATEWAY_PORT}/simulation

Last Updated: $(date)
EOF
```

### 7.2 Share Access
- [ ] Share frontend URL with team
- [ ] Share API Gateway URL with team
- [ ] Document test credentials (if any)

---

## Troubleshooting Quick Reference

### Frontend Pod Not Starting
```bash
kubectl describe pod <pod-name> -n pms
kubectl logs <pod-name> -n pms
```

### LoadBalancer Pending
```bash
# Wait a few minutes, then check
kubectl get svc frontend-service -n pms -w

# Check AWS Load Balancer Controller
kubectl get pods -n kube-system | grep aws-load-balancer
```

### Can't Access Frontend
```bash
# Verify pod is running
kubectl get pods -n pms -l app=frontend

# Test from within cluster
kubectl run curl --image=curlimages/curl -i --rm --restart=Never -- \
  curl -s http://frontend-service.pms.svc.cluster.local

# Check security groups (AWS)
# Verify LoadBalancer security group allows port 80
```

### Backend API Calls Fail
```bash
# Verify API Gateway is accessible
curl http://${GATEWAY_LB}:${GATEWAY_PORT}/fallback

# Check env.js has correct URLs
curl http://${FRONTEND_URL}/env.js

# Verify CORS headers
curl -H "Origin: http://test.com" -I \
  http://${GATEWAY_LB}:${GATEWAY_PORT}/api/analysis/all
```

---

## Success Criteria

✅ **Endpoint Testing Complete:**
- All HTTP endpoints return expected status codes
- WebSocket connections can be established
- No 404 or 500 errors

✅ **Frontend Deployed:**
- Pod is running and healthy
- LoadBalancer is provisioned
- Frontend accessible in browser

✅ **Integration Working:**
- Frontend can call backend APIs
- WebSocket connections established
- Real-time updates working
- No CORS errors

✅ **Performance Acceptable:**
- Page load < 3 seconds
- No memory leaks
- Resources within limits

---

## Next Steps After Deployment

1. **Setup Monitoring**
   - Configure CloudWatch dashboards
   - Setup alerts for errors
   - Monitor resource usage

2. **Enable HTTPS**
   - Get SSL certificate
   - Configure ALB with HTTPS
   - Update frontend URLs

3. **Configure Custom Domain**
   - Setup Route53 DNS
   - Point to LoadBalancer
   - Update CORS configuration

4. **Setup CI/CD**
   - Configure GitHub Actions
   - Automate deployments
   - Add staging environment

5. **User Acceptance Testing**
   - Invite team to test
   - Collect feedback
   - Fix any issues

---

**Prepared:** January 30, 2026  
**Status:** Ready for execution  
**Estimated Time:** 2-3 hours
