# PMS Platform Ingress - Architectural Decision Record (ADR)

**Status**: Proposed  
**Date**: 2026-01-30  
**Deciders**: Platform Team  
**Context**: Production-grade ingress setup for EKS-hosted PMS platform

---

## 🎯 Decision

Implement a **single AWS Application Load Balancer (ALB)** managed by the **AWS Load Balancer Controller** to replace the current dual-LoadBalancer architecture.

---

## 📊 Context

### Current Architecture (Problems)

```
Internet
   ├── LoadBalancer #1 → frontend:80
   │   URL: a391e234f414d47c8bf54c04acf53719-1442273814.us-east-1.elb.amazonaws.com
   └── LoadBalancer #2 → apigateway:8088
       URL: a3ed40b7b10934382a4b04887e88ef29-164917452.us-east-1.elb.amazonaws.com
```

**Issues:**
1. ❌ **Two origins** → CORS complexity
2. ❌ **HTTP only** → no TLS encryption
3. ❌ **Ugly URLs** → hardcoded ELB DNS names in frontend config
4. ❌ **Higher cost** → dual LoadBalancers (~$45/month)
5. ❌ **No centralized security** → cannot apply WAF to frontend
6. ❌ **No single entry point** → harder to monitor, rate limit, DDoS protect

### Requirements

1. **Single public endpoint** for entire platform
2. **HTTPS everywhere** with proper TLS termination
3. **No CORS issues** (same-origin architecture)
4. **WebSocket support** for RTTM, analytics, leaderboard
5. **Production-grade** security and monitoring
6. **Cost-efficient** infrastructure
7. **GitOps-friendly** (Helm + ArgoCD)

---

## 🔍 Options Considered

### Option 1: AWS Load Balancer Controller (ALB) ✅ SELECTED

**Architecture:**
```
Internet → ALB → Ingress → {frontend:80, apigateway:8088}
```

**Pros:**
- ✅ Native AWS integration (no extra infrastructure)
- ✅ Free ACM certificates with auto-renewal
- ✅ Native WebSocket support (HTTP/1.1 upgrade)
- ✅ Lower cost (single ALB ~$22/month)
- ✅ Standard Kubernetes Ingress resource (no vendor lock-in)
- ✅ Path-based routing built-in
- ✅ WAF/Shield integration ready
- ✅ CloudWatch metrics out-of-the-box
- ✅ Zero operational overhead (AWS manages ALB)

**Cons:**
- ⚠️ Requires IAM setup for controller
- ⚠️ ALB-specific annotations (some lock-in)
- ⚠️ Certificate must be in us-east-1

**Cost:**
- ALB: ~$22/month (0.0225/hour + LCU)
- ACM: Free
- **Total: ~$25-30/month**

---

### Option 2: NGINX Ingress Controller + NLB

**Architecture:**
```
Internet → NLB → NGINX Pods → Ingress → {frontend, apigateway}
```

**Pros:**
- ✅ More flexible (full NGINX config)
- ✅ Works across cloud providers
- ✅ Advanced features (rate limiting, caching)
- ✅ No AWS-specific annotations

**Cons:**
- ❌ Requires managing NGINX pods (more ops overhead)
- ❌ Requires cert-manager for TLS (complexity)
- ❌ Higher cost: NLB + ALB ~$40/month
- ❌ Must configure TLS ourselves (no ACM integration)
- ❌ Extra hops (Internet → NLB → NGINX → Service)
- ❌ Need to tune NGINX for WebSockets manually

**Cost:**
- NLB: ~$18/month
- ALB (optional): ~$22/month
- **Total: ~$40-50/month**

---

### Option 3: Keep Dual LoadBalancers + Custom CORS

**Architecture:**
```
Internet → Frontend LB → frontend:80
Internet → API Gateway LB → apigateway:8088
```

**Pros:**
- ✅ No changes needed (keep current setup)
- ✅ Simple (what we have now)

**Cons:**
- ❌ Still two origins → CORS forever
- ❌ Still no TLS → insecure
- ❌ Still ugly URLs
- ❌ Higher cost (~$45/month)
- ❌ Cannot apply WAF to frontend
- ❌ No centralized rate limiting

**Cost:**
- 2x LoadBalancers: ~$45/month
- **Total: ~$45/month**

---

## ✅ Decision Rationale

We selected **Option 1: AWS Load Balancer Controller (ALB)** because:

1. **Cost**: Saves ~$15-20/month vs NGINX+NLB, ~$20/month vs dual LBs
2. **Simplicity**: Zero pods to manage, AWS handles ALB lifecycle
3. **Native AWS**: ACM integration, CloudWatch metrics, VPC integration
4. **WebSocket**: Proven at scale for SockJS/STOMP
5. **Security**: WAF/Shield ready, TLS termination included
6. **Standard**: Uses Kubernetes Ingress resource (portable)
7. **Team familiarity**: Team already knows AWS, not adding new tech

---

## 🏗️ Implementation Architecture

### Target State

```
Internet (HTTPS only)
   ↓
Route 53: pms.yourdomain.com
   ↓
ACM Certificate (*.yourdomain.com) - auto-renewed
   ↓
AWS ALB (managed by LB Controller)
   ├── Listener 80  → HTTP → 301 redirect to 443
   └── Listener 443 → HTTPS/WSS
       ├── Target Group #1: frontend:80
       │   Health: GET /
       │   Targets: frontend pods (10.0.x.x:80)
       │
       └── Target Group #2: apigateway:8088
           Health: GET /actuator/health
           Targets: apigateway pods (10.0.x.x:8088)

Path Routing:
  /            → Target Group #1 (frontend)
  /api/*       → Target Group #2 (apigateway)
  /ws/*        → Target Group #2 (apigateway)
```

### Request Flow

**HTTP Request:**
```
https://pms.yourdomain.com/api/auth/login
   ↓
ALB (TLS termination)
   ↓
Ingress Controller (path matching: /api/*)
   ↓
apigateway Service (ClusterIP)
   ↓
apigateway Pod
   ↓
auth Service (internal)
```

**WebSocket Request:**
```
wss://pms.yourdomain.com/ws/rttm/metrics
   ↓
ALB (TLS termination, upgrade to WebSocket)
   ↓
Ingress Controller (path matching: /ws/*)
   ↓
apigateway Service (ClusterIP)
   ↓
apigateway Pod (Spring Cloud Gateway WebSocket route)
   ↓
rttm Service (internal)
```

**Frontend Request:**
```
https://pms.yourdomain.com/
   ↓
ALB (TLS termination)
   ↓
Ingress Controller (path matching: /)
   ↓
frontend Service (ClusterIP)
   ↓
frontend Pod (NGINX)
   ↓
index.html (loads env.js from ConfigMap)
```

---

## 🔒 Security Design

### TLS Strategy

- **Termination Point**: ALB (not in pods)
- **Certificate Management**: AWS Certificate Manager (ACM)
- **Auto-renewal**: ACM handles automatically
- **Minimum TLS Version**: 1.2 (ALB default)
- **HTTP Traffic**: Redirected to HTTPS (301)

**Why terminate at ALB?**
- Simpler certificate management (one place)
- Better performance (ALB optimized for TLS)
- Easier to rotate certificates
- Pods don't need TLS configuration

### CORS Strategy

**Current Problem:**
```
Frontend Origin:  http://a391e234f414d47c8bf54c04acf53719....elb.amazonaws.com
API Origin:       http://a3ed40b7b10934382a4b04887e88ef29....elb.amazonaws.com

Different origins → Browser blocks requests → Need CORS headers
```

**Solution with Ingress:**
```
Frontend Origin:  https://pms.yourdomain.com
API Origin:       https://pms.yourdomain.com

SAME origin → Browser allows requests → NO CORS NEEDED!
```

**Migration Plan:**
1. Deploy ingress
2. Test same-origin requests work
3. Simplify API Gateway CORS config:
   ```yaml
   # Before: Permissive wildcard
   GATEWAY_CORS_ORIGINS: "*"
   GATEWAY_CORS_CREDENTIALS: "false"
   
   # After: Strict same-origin (or remove entirely)
   GATEWAY_CORS_ORIGINS: "https://pms.yourdomain.com"
   GATEWAY_CORS_CREDENTIALS: "true"
   ```
4. Eventually remove CORS entirely (not needed for same-origin)

### Security Headers

Add via ingress annotations:

```yaml
alb.ingress.kubernetes.io/actions.ssl-redirect: |
  {
    "Type": "redirect",
    "RedirectConfig": {
      "Protocol": "HTTPS",
      "Port": "443",
      "StatusCode": "HTTP_301"
    }
  }
```

Future: Add custom headers via API Gateway filters:
- `Strict-Transport-Security: max-age=31536000`
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`

---

## 🌐 WebSocket Design

### Requirements

- **Protocols**: SockJS, STOMP, raw WebSocket
- **Services**: RTTM (6 endpoints), Analytics (1), Leaderboard (1)
- **Connection lifetime**: Long-lived (minutes to hours)
- **Idle timeout**: 300 seconds minimum

### ALB Configuration

```yaml
# Increase idle timeout for WebSocket connections
alb.ingress.kubernetes.io/load-balancer-attributes: |
  idle_timeout.timeout_seconds=300

# Enable sticky sessions (important for WebSocket)
alb.ingress.kubernetes.io/target-group-attributes: |
  stickiness.enabled=true,
  stickiness.lb_cookie.duration_seconds=86400
```

**Why sticky sessions?**
- WebSocket connections are stateful
- Must hit same pod for entire session
- ALB uses cookies to ensure consistency

### WebSocket Paths

```
wss://pms.yourdomain.com/ws → Analytics STOMP
wss://pms.yourdomain.com/ws/rttm/metrics → RTTM metrics
wss://pms.yourdomain.com/ws/rttm/pipeline → RTTM pipeline
wss://pms.yourdomain.com/ws/rttm/telemetry → RTTM telemetry
wss://pms.yourdomain.com/ws/rttm/dlq → RTTM DLQ
wss://pms.yourdomain.com/ws/rttm/alerts → RTTM alerts
wss://pms.yourdomain.com/ws/leaderboard → Leaderboard
```

All WebSocket paths match `/ws/*` → routed to `apigateway:8088`

---

## 🔧 Frontend Integration

### Current State (localhost fallback issue)

**Problem:**
```typescript
// environment.docker.ts - COMPILED into bundle
export const ENDPOINTS = {
  apiGateway: {
    baseHttp: 'http://localhost:8088',
    baseWs: 'ws://localhost:8088'
  }
};

// Services import ENDPOINTS directly → hardcoded at build time
```

**Solution Applied:**
```typescript
// RuntimeConfigService reads from window.__ENV__ (loaded from env.js)
private readonly runtimeConfig = inject(RuntimeConfigService);
private readonly baseUrl = this.runtimeConfig.apiGateway.baseHttp;
```

### Migration to Same-Origin

**After ingress is deployed:**

```typescript
// env.js (ConfigMap) - NEW VALUES
window.__ENV__ = {
  API_GATEWAY_HTTP: "",  // Empty = use same origin
  API_GATEWAY_WS: "",    // Empty = use same origin
  // ... other services route through API Gateway
};
```

**RuntimeConfigService changes:**

```typescript
get apiGateway() {
  const http = window.__ENV__?.API_GATEWAY_HTTP || '';
  const ws = window.__ENV__?.API_GATEWAY_WS || '';
  
  return {
    // Empty string → use window.location.origin
    baseHttp: http || window.location.origin,
    baseWs: ws || `ws${window.location.protocol === 'https:' ? 's' : ''}://${window.location.host}`
  };
}
```

**Result:**
```
Frontend loads from: https://pms.yourdomain.com/
API calls go to:     https://pms.yourdomain.com/api/*
WebSockets go to:    wss://pms.yourdomain.com/ws/*

Same origin → No CORS → No configuration needed!
```

### Local Development

**Local dev still works:**

```typescript
// In development (ng serve on localhost:4200)
window.location.origin = "http://localhost:4200"

// env.js sets different values for local dev
window.__ENV__ = {
  API_GATEWAY_HTTP: "http://localhost:8088",  // Local Spring Boot
  API_GATEWAY_WS: "ws://localhost:8088"
};
```

**No frontend code changes needed** - just different env.js values.

---

## 📦 Helm Integration

### Chart Structure

```
pms-infra/k8s/charts/platform/pms-ingress/
├── Chart.yaml
├── values.yaml
├── values-dev.yaml       (optional)
├── values-prod.yaml      (optional)
├── templates/
│   ├── _helpers.tpl
│   └── ingress.yaml
└── README.md
```

### Environment-specific Deployment

**Development:**
```yaml
# values-dev.yaml
host: "pms-dev.yourdomain.com"
ingress:
  annotations:
    alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:...:certificate/dev-cert"
```

**Production:**
```yaml
# values-prod.yaml
host: "pms.yourdomain.com"
ingress:
  annotations:
    alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:...:certificate/prod-cert"

features:
  waf:
    enabled: true
  accessLogs:
    enabled: true
```

### ArgoCD Application

```yaml
# argocd/pms-ingress.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: pms-ingress
  namespace: argocd
spec:
  project: pms
  source:
    repoURL: https://github.com/yourorg/pms-infra
    targetRevision: main
    path: k8s/charts/platform/pms-ingress
    helm:
      valueFiles:
        - values.yaml
        - values-prod.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: pms
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

## 🚀 Migration Plan

### Phase 1: Prerequisites (Day 1)

- [x] ~~Document current architecture~~
- [ ] Install AWS Load Balancer Controller
- [ ] Request ACM certificate
- [ ] Validate certificate

### Phase 2: Service Changes (Day 1-2)

- [ ] Update `frontend/values.yaml`: `service.type: ClusterIP`
- [ ] Update `apigateway/values.yaml`: `service.type: ClusterIP`
- [ ] Deploy changes (LoadBalancers will be deleted)

### Phase 3: Ingress Deployment (Day 2)

- [ ] Update ingress values with certificate ARN
- [ ] Deploy ingress chart
- [ ] Verify ALB creation
- [ ] Verify target groups healthy

### Phase 4: DNS Configuration (Day 2)

- [ ] Get ALB DNS name from ingress
- [ ] Create Route 53 ALIAS record
- [ ] Wait for DNS propagation

### Phase 5: Frontend Config Update (Day 3)

- [ ] Update frontend ConfigMap with empty strings
- [ ] Update RuntimeConfigService to handle same-origin
- [ ] Restart frontend pods
- [ ] Test in browser

### Phase 6: Validation (Day 3)

- [ ] HTTPS works
- [ ] HTTP→HTTPS redirect works
- [ ] Frontend loads correctly
- [ ] API calls work (no CORS errors)
- [ ] WebSockets connect
- [ ] Real-time data flows

### Phase 7: CORS Cleanup (Day 4)

- [ ] Simplify API Gateway CORS config
- [ ] Test again
- [ ] Consider removing CORS entirely

### Phase 8: Monitoring Setup (Day 5)

- [ ] Enable ALB access logs
- [ ] Configure CloudWatch alarms
- [ ] Set up dashboards

---

## 📊 Success Metrics

### Technical Metrics

- ✅ **Single endpoint**: `https://pms.yourdomain.com`
- ✅ **Zero CORS errors** in browser console
- ✅ **TLS everywhere**: All HTTP traffic redirected to HTTPS
- ✅ **WebSocket success rate**: 100%
- ✅ **ALB healthy targets**: 100%

### Business Metrics

- 💰 **Cost reduction**: ~40% (from $45 to $25/month)
- ⚡ **Latency**: <50ms added by ALB
- 🔒 **Security score**: A+ (HTTPS, proper headers)
- 📈 **Uptime**: 99.9%+

---

## 🔄 Rollback Plan

If critical issues occur:

**Step 1: Immediate Rollback**
```bash
# Restore LoadBalancer services
helm upgrade frontend ./charts/services/frontend \
  --set service.type=LoadBalancer -n pms

helm upgrade apigateway ./charts/services/apigateway \
  --set service.type=LoadBalancer -n pms

# Delete ingress
helm uninstall pms-ingress -n pms
```

**Step 2: Restore Frontend Config**
```bash
# Update ConfigMap with old LoadBalancer URLs
kubectl edit configmap frontend-env-config -n pms

# Restart frontend
kubectl rollout restart deployment frontend -n pms
```

**Step 3: Verify**
```bash
# Check services are exposed
kubectl get svc -n pms | grep LoadBalancer

# Test old URLs work
curl http://a391e234f414d47c8bf54c04acf53719....elb.amazonaws.com
```

**Time to rollback**: <5 minutes

---

## 🔮 Future Enhancements

### Phase 2 (Month 2-3)

- [ ] Enable AWS WAF for DDoS protection
- [ ] Add custom security headers
- [ ] Configure rate limiting per path
- [ ] Set up ALB access logs → S3 → Athena

### Phase 3 (Month 4-6)

- [ ] Multi-region setup (Route 53 + failover)
- [ ] CDN integration (CloudFront in front of ALB)
- [ ] Advanced monitoring (Prometheus + Grafana)
- [ ] Cost optimization (reserved capacity)

### Phase 4 (Month 7+)

- [ ] Blue/green deployments via ingress
- [ ] Canary releases (weighted routing)
- [ ] API versioning via path (v1, v2)
- [ ] gRPC support for high-performance APIs

---

## 📚 References

- [AWS Load Balancer Controller Docs](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Ingress Annotations](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.7/guide/ingress/annotations/)
- [AWS ALB Best Practices](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/best-practices.html)
- [WebSocket on ALB](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/application-load-balancers.html#websocket-support)

---

## ✍️ Sign-off

**Decision Status**: ✅ **APPROVED**

This architecture provides:
- Production-grade security (HTTPS, WAF-ready)
- Cost efficiency (40% reduction)
- Operational simplicity (managed ALB)
- Developer experience (same-origin, no CORS)
- WebSocket reliability (proven at scale)

**Next Step**: Proceed with Phase 1 (Prerequisites)
