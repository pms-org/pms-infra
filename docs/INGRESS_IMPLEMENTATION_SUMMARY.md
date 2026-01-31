# PMS Platform - Production-Grade Ingress Implementation Summary

## 📋 Executive Summary

This document provides a complete production-grade Kubernetes Ingress solution for the PMS platform on Amazon EKS. The solution replaces the current dual-LoadBalancer architecture with a single AWS Application Load Balancer (ALB), eliminating CORS issues, reducing costs, and improving security.

---

## 🎯 Business Impact

### Problems Solved

| Problem | Current State | After Ingress | Impact |
|---------|---------------|---------------|--------|
| **CORS Complexity** | 2 origins, complex CORS config | Same origin, no CORS | ✅ Developer productivity |
| **Security** | HTTP only, no TLS | HTTPS enforced, ACM certs | ✅ Compliance ready |
| **Cost** | 2 LoadBalancers ($45/mo) | 1 ALB ($25/mo) | 💰 40% savings |
| **User Experience** | Ugly ELB URLs | Clean domain name | ✅ Professional |
| **Monitoring** | 2 endpoints to monitor | 1 centralized endpoint | ✅ Ops simplicity |
| **DDoS Protection** | Limited | WAF-ready | 🔒 Security |

### Key Benefits

- ✅ **Single Public Endpoint**: `https://pms.yourdomain.com`
- ✅ **HTTPS Everywhere**: TLS termination via AWS Certificate Manager
- ✅ **Zero CORS Issues**: Same-origin architecture
- ✅ **WebSocket Ready**: Battle-tested support for RTTM, Analytics, Leaderboard
- ✅ **Cost Efficient**: ~40% infrastructure cost reduction
- ✅ **Production Security**: WAF/Shield ready, proper TLS, security headers
- ✅ **GitOps Native**: Helm-templated, ArgoCD compatible

---

## 🏗️ Architecture Overview

### Before (Current State)

```
Internet
   ├── LoadBalancer #1 (a391e234...elb.amazonaws.com)
   │   └── frontend:80 (HTTP only)
   │
   └── LoadBalancer #2 (a3ed40b7...elb.amazonaws.com:8088)
       └── apigateway:8088 (HTTP only)

Problems:
❌ Two origins → CORS hell
❌ No HTTPS → insecure
❌ Ugly URLs → unprofessional
❌ Higher cost → wasteful
```

### After (Target State)

```
Internet (HTTPS only)
   ↓
Route 53: pms.yourdomain.com
   ↓
ACM Certificate (free, auto-renewed)
   ↓
AWS Application Load Balancer
   ├── Listener 80  → HTTP → 301 redirect to 443
   └── Listener 443 → HTTPS/WSS
       ├── /       → frontend:80 (Angular SPA)
       ├── /api/*  → apigateway:8088 (REST)
       └── /ws/*   → apigateway:8088 (WebSocket)

Benefits:
✅ One origin → no CORS
✅ HTTPS enforced → secure
✅ Clean URL → professional
✅ Lower cost → efficient
```

---

## 🔧 Technical Design

### Ingress Controller Selection

**Decision: AWS Load Balancer Controller (ALB)**

**Why ALB over NGINX?**

| Factor | ALB | NGINX+NLB |
|--------|-----|-----------|
| Cost | $25/mo | $45/mo |
| Ops Overhead | Zero (AWS managed) | High (manage pods) |
| TLS | ACM (free) | cert-manager (complex) |
| WebSocket | Native support | Manual config |
| AWS Integration | First-class | Via annotations |

**Justification:**
- Native AWS service (no pods to manage)
- Free ACM certificate integration
- Lower cost (single ALB vs NLB+ALB)
- Battle-tested WebSocket support
- CloudWatch metrics out-of-the-box

### Routing Strategy

```yaml
# Path-based routing (order matters!)
/api/*  → apigateway:8088  # Specific path first
/ws/*   → apigateway:8088  # WebSocket paths
/       → frontend:80       # Catch-all last (Angular routing)
```

**Why this order?**
- ALB matches paths in order
- Most specific (`/api/*`, `/ws/*`) MUST come before generic (`/`)
- Frontend catch-all handles Angular client-side routing

### TLS Strategy

**Termination Point**: AWS ALB (not in pods)

**Why?**
- Simpler certificate management (one place)
- Better performance (ALB hardware acceleration)
- Automatic renewal via ACM
- Pods don't need TLS configuration

**Configuration:**
```yaml
alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:us-east-1:ACCOUNT:certificate/ID"
alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
alb.ingress.kubernetes.io/ssl-redirect: '443'
```

### CORS Strategy

**Current Problem:**
```
Frontend: http://a391e234...elb.amazonaws.com
API:      http://a3ed40b7...elb.amazonaws.com

Different origins → Browser blocks → Need CORS
```

**Solution:**
```
Frontend: https://pms.yourdomain.com/
API:      https://pms.yourdomain.com/api/*

SAME origin → Browser allows → NO CORS NEEDED!
```

**Migration Plan:**
1. Deploy ingress → same origin established
2. Test → verify no CORS headers needed
3. Simplify API Gateway CORS config
4. Eventually remove CORS entirely

### WebSocket Design

**Requirements:**
- Long-lived connections (minutes to hours)
- Multiple protocols: SockJS, STOMP, raw WebSocket
- 8 endpoints: Analytics (1), RTTM (6), Leaderboard (1)

**ALB Configuration:**
```yaml
# Increase timeout for long-lived connections
alb.ingress.kubernetes.io/load-balancer-attributes: |
  idle_timeout.timeout_seconds=300

# Sticky sessions (WebSocket connections are stateful)
alb.ingress.kubernetes.io/target-group-attributes: |
  stickiness.enabled=true,
  stickiness.lb_cookie.duration_seconds=86400
```

**Why sticky sessions?**
- WebSocket connections are stateful
- Must hit same pod for entire session
- ALB uses cookies to maintain affinity

---

## 📦 Implementation Deliverables

### 1. Helm Chart: `pms-ingress`

**Location**: `pms-infra/k8s/charts/platform/pms-ingress/`

**Files:**
```
pms-ingress/
├── Chart.yaml                 # Chart metadata
├── values.yaml                # Default configuration
├── values-dev.yaml            # Development overrides (optional)
├── values-prod.yaml           # Production overrides (optional)
├── templates/
│   ├── _helpers.tpl          # Helm helper functions
│   └── ingress.yaml          # Ingress resource template
└── README.md                  # Usage instructions
```

**Key Features:**
- Environment-aware (dev/stage/prod via values files)
- Configurable certificate ARN
- Configurable domain name
- Optional WAF integration
- Optional access logs to S3

**Installation:**
```bash
helm install pms-ingress ./charts/platform/pms-ingress \
  -f values.yaml \
  -f values-prod.yaml \
  --namespace pms
```

### 2. Documentation

| Document | Purpose | Audience |
|----------|---------|----------|
| `docs/INGRESS_SETUP.md` | Step-by-step setup guide | DevOps/Platform Engineers |
| `docs/INGRESS_ADR.md` | Architectural decision record | Tech Leads/Architects |
| `docs/INGRESS_VALIDATION.md` | Testing & validation plan | QA/DevOps |
| `charts/platform/pms-ingress/README.md` | Helm chart usage | Developers |

### 3. Configuration Changes

**Frontend Service** (`charts/services/frontend/values.yaml`):
```yaml
# Before
service:
  type: LoadBalancer

# After
service:
  type: ClusterIP
```

**API Gateway Service** (`charts/services/apigateway/values.yaml`):
```yaml
# Before
service:
  type: LoadBalancer

# After
service:
  type: ClusterIP
```

**Frontend ConfigMap** (after ingress deployed):
```javascript
// env.js - Same-origin configuration
window.__ENV__ = {
  API_GATEWAY_HTTP: "",  // Empty = use window.location.origin
  API_GATEWAY_WS: "",    // Empty = use same origin with ws/wss protocol
  // ... other services
};
```

### 4. Frontend Code Changes

**RuntimeConfigService** enhancement:
```typescript
get apiGateway() {
  const http = window.__ENV__?.API_GATEWAY_HTTP || '';
  const ws = window.__ENV__?.API_GATEWAY_WS || '';
  
  return {
    // Empty string → derive from window.location
    baseHttp: http || window.location.origin,
    baseWs: ws || `ws${window.location.protocol === 'https:' ? 's' : ''}://${window.location.host}`
  };
}
```

**Result:**
- Production: Uses `https://pms.yourdomain.com` automatically
- Development: Uses `http://localhost:4200` (or configured value)
- No code changes needed between environments

---

## 🚀 Implementation Roadmap

### Phase 1: Prerequisites (Day 1) - 2 hours

**Tasks:**
- [x] Design architecture ✅
- [x] Create documentation ✅
- [x] Create Helm chart ✅
- [ ] Install AWS Load Balancer Controller
- [ ] Request ACM certificate
- [ ] Validate certificate

**Deliverables:**
- AWS LB Controller running in kube-system namespace
- ACM certificate in ISSUED status
- Documentation ready for team

**Success Criteria:**
```bash
kubectl get deployment -n kube-system aws-load-balancer-controller
# READY: 2/2

aws acm describe-certificate --certificate-arn ... --query 'Certificate.Status'
# OUTPUT: ISSUED
```

---

### Phase 2: Service Changes (Day 1-2) - 1 hour

**Tasks:**
- [ ] Update frontend Helm chart: `service.type: ClusterIP`
- [ ] Update apigateway Helm chart: `service.type: ClusterIP`
- [ ] Deploy changes via Helm
- [ ] Verify LoadBalancers removed

**Commands:**
```bash
# Update charts
helm upgrade frontend ./charts/services/frontend \
  --set service.type=ClusterIP -n pms

helm upgrade apigateway ./charts/services/apigateway \
  --set service.type=ClusterIP -n pms

# Verify
kubectl get svc -n pms frontend apigateway
# TYPE: ClusterIP (not LoadBalancer)
```

**Success Criteria:**
- Frontend service: `ClusterIP`, no EXTERNAL-IP
- API Gateway service: `ClusterIP`, no EXTERNAL-IP
- Old LoadBalancer URLs no longer accessible

---

### Phase 3: Ingress Deployment (Day 2) - 1 hour

**Tasks:**
- [ ] Update `values.yaml` with certificate ARN
- [ ] Configure domain name (optional)
- [ ] Deploy ingress chart
- [ ] Verify ALB creation
- [ ] Check target group health

**Commands:**
```bash
# Deploy ingress
helm install pms-ingress ./charts/platform/pms-ingress \
  --namespace pms

# Watch creation
kubectl get ingress -n pms -w

# Verify ALB
kubectl describe ingress -n pms pms-ingress
```

**Success Criteria:**
- Ingress resource shows ALB ADDRESS
- ALB created in AWS console
- 2 listeners (80, 443) configured
- Certificate attached to port 443
- All target groups healthy

---

### Phase 4: DNS Configuration (Day 2) - 30 minutes

**Tasks:**
- [ ] Get ALB DNS name from ingress
- [ ] Create Route 53 ALIAS record
- [ ] Wait for DNS propagation
- [ ] Verify resolution

**Commands:**
```bash
# Get ALB DNS
ALB_DNS=$(kubectl get ingress -n pms pms-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Create Route 53 record (via AWS console or CLI)
# Type: A (Alias)
# Target: $ALB_DNS

# Test resolution
dig pms.yourdomain.com +short
```

**Success Criteria:**
- Domain resolves to ALB IP addresses
- `curl https://pms.yourdomain.com` returns 200 OK
- HTTP→HTTPS redirect works

---

### Phase 5: Frontend Integration (Day 3) - 2 hours

**Tasks:**
- [ ] Update RuntimeConfigService for same-origin
- [ ] Update frontend ConfigMap (empty strings for API Gateway)
- [ ] Rebuild frontend Docker image
- [ ] Deploy new frontend
- [ ] Test in browser

**Changes:**
```yaml
# frontend ConfigMap (env.js)
config:
  API_GATEWAY_HTTP: ""  # Empty = use window.location.origin
  API_GATEWAY_WS: ""    # Empty = use ws/wss same origin
```

**Success Criteria:**
- Frontend loads at `https://pms.yourdomain.com`
- Browser console: NO localhost references
- Browser console: NO CORS errors
- Network tab: All requests to `pms.yourdomain.com`

---

### Phase 6: Validation (Day 3) - 3 hours

**Tasks:**
- [ ] Run full validation suite (see INGRESS_VALIDATION.md)
- [ ] Test all REST endpoints
- [ ] Test all WebSocket endpoints
- [ ] Load testing
- [ ] Security scanning

**Key Tests:**
```bash
# HTTPS enforcement
curl -I http://pms.yourdomain.com
# Expected: 301 → https

# Frontend loads
curl -I https://pms.yourdomain.com/
# Expected: 200 OK

# API works
curl https://pms.yourdomain.com/api/actuator/health
# Expected: {"status":"UP"}

# WebSocket connects
wscat -c wss://pms.yourdomain.com/ws/rttm/metrics
# Expected: Connected
```

**Success Criteria:**
- All validation tests pass (see INGRESS_VALIDATION.md)
- Zero CORS errors
- Zero localhost references
- WebSocket success rate: 100%
- Response time: <200ms

---

### Phase 7: CORS Cleanup (Day 4) - 1 hour

**Tasks:**
- [ ] Simplify API Gateway CORS configuration
- [ ] Test without CORS headers
- [ ] Consider removing CORS entirely

**API Gateway Config:**
```yaml
# Before (permissive)
GATEWAY_CORS_ORIGINS: "*"
GATEWAY_CORS_CREDENTIALS: "false"

# After (strict, or remove)
GATEWAY_CORS_ORIGINS: "https://pms.yourdomain.com"
GATEWAY_CORS_CREDENTIALS: "true"

# Future (remove entirely - not needed for same origin)
# Remove CORS configuration completely
```

**Success Criteria:**
- Same-origin requests work without CORS headers
- Cross-origin requests blocked (as expected)
- API Gateway config simplified

---

### Phase 8: Monitoring & Observability (Day 5) - 2 hours

**Tasks:**
- [ ] Enable ALB access logs → S3
- [ ] Configure CloudWatch alarms
- [ ] Create CloudWatch dashboard
- [ ] Set up alerts (Slack/PagerDuty)

**CloudWatch Alarms:**
- Unhealthy targets > 1 for 2 minutes
- Target response time > 500ms
- 5xx errors > 10/minute
- Request count drops > 50%

**Success Criteria:**
- Access logs flowing to S3
- CloudWatch alarms configured
- Dashboard shows key metrics
- Team receives test alert successfully

---

## 📊 Validation Checklist

### Pre-Deployment
- [ ] AWS Load Balancer Controller installed
- [ ] ACM certificate validated (ISSUED status)
- [ ] Documentation reviewed by team
- [ ] Rollback plan documented

### Deployment
- [ ] Services changed to ClusterIP
- [ ] Ingress resource created
- [ ] ALB provisioned successfully
- [ ] Target groups healthy (100%)

### Security
- [ ] HTTPS works
- [ ] HTTP→HTTPS redirect works
- [ ] Valid TLS certificate
- [ ] No certificate warnings
- [ ] Security headers present

### Functionality
- [ ] Frontend loads at `https://pms.yourdomain.com`
- [ ] Angular routing works (SPA routes)
- [ ] API endpoints respond correctly
- [ ] WebSocket connections establish
- [ ] Real-time data flows (RTTM, Analytics, Leaderboard)

### Browser Testing
- [ ] No console errors
- [ ] No CORS errors
- [ ] No "Mixed Content" warnings
- [ ] No localhost references
- [ ] All requests to domain

### Performance
- [ ] Response time < 200ms
- [ ] WebSocket latency acceptable
- [ ] Load test passed (>99% success)
- [ ] No degradation vs baseline

### Monitoring
- [ ] CloudWatch metrics flowing
- [ ] Alarms configured
- [ ] Dashboard created
- [ ] Alerts tested

---

## 💰 Cost Analysis

### Before (Dual LoadBalancers)

| Resource | Monthly Cost |
|----------|--------------|
| Frontend LoadBalancer (CLB) | ~$22 |
| API Gateway LoadBalancer (CLB) | ~$22 |
| **Total** | **~$45** |

### After (Single ALB)

| Resource | Monthly Cost |
|----------|--------------|
| Application Load Balancer | ~$22 |
| ACM Certificate | Free |
| Route 53 (Hosted Zone) | $0.50 |
| **Total** | **~$25** |

### Savings

- **Monthly Savings**: ~$20/month
- **Annual Savings**: ~$240/year
- **Percentage Reduction**: ~40%

**Additional Benefits:**
- Free TLS certificates (vs $100/year for commercial)
- Centralized monitoring (reduced ops overhead)
- Better security posture (WAF-ready)

---

## 🔒 Security Enhancements

### Current State
- ❌ HTTP only (no encryption)
- ❌ No HTTPS
- ❌ No centralized security controls
- ❌ Cannot apply WAF
- ❌ Frontend directly exposed

### After Ingress
- ✅ HTTPS enforced everywhere
- ✅ TLS 1.2+ minimum
- ✅ ACM-managed certificates (auto-renewal)
- ✅ WAF-ready (can attach AWS WAF)
- ✅ Shield Standard (DDoS protection)
- ✅ Centralized security headers
- ✅ Single attack surface (easier to defend)

### Future Security Enhancements
- AWS WAF rules (SQL injection, XSS prevention)
- Rate limiting per path
- Geo-blocking
- IP whitelisting for admin paths
- Request size limits
- Advanced DDoS protection (Shield Advanced)

---

## 🎯 Success Metrics

### Technical Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Uptime | 99.9%+ | CloudWatch ALB availability |
| Response Time | <200ms | CloudWatch TargetResponseTime |
| Error Rate | <1% | CloudWatch 5xx errors |
| WebSocket Success | 100% | Application logs |
| CORS Errors | 0 | Browser console |

### Business Metrics

| Metric | Target | Impact |
|--------|--------|--------|
| Cost Reduction | 40% | $20/month savings |
| Security Compliance | 100% HTTPS | SOC2/PCI ready |
| User Experience | Zero errors | Professional URL |
| Developer Productivity | Reduced CORS debugging | Hours saved |

---

## 🆘 Rollback Plan

### Immediate Rollback (< 5 minutes)

If critical issues occur:

```bash
# 1. Restore LoadBalancer services
helm upgrade frontend ./charts/services/frontend \
  --set service.type=LoadBalancer -n pms

helm upgrade apigateway ./charts/services/apigateway \
  --set service.type=LoadBalancer -n pms

# 2. Delete ingress
helm uninstall pms-ingress -n pms

# 3. Restore frontend ConfigMap
kubectl edit configmap frontend-env-config -n pms
# (Restore old LoadBalancer URLs)

# 4. Restart frontend
kubectl rollout restart deployment frontend -n pms
```

### Rollback Triggers

Rollback immediately if:
- ALB targets unhealthy for >5 minutes
- >10% error rate on API calls
- WebSocket connections failing >50%
- Frontend not loading
- Certificate errors
- DNS not resolving after 30 minutes

---

## 📚 Documentation Index

1. **[INGRESS_SETUP.md](./docs/INGRESS_SETUP.md)** - Step-by-step setup guide
   - AWS Load Balancer Controller installation
   - ACM certificate request
   - Service type changes
   - Ingress deployment
   - DNS configuration
   - Troubleshooting

2. **[INGRESS_ADR.md](./docs/INGRESS_ADR.md)** - Architectural Decision Record
   - Problem statement
   - Options considered (ALB vs NGINX)
   - Decision rationale
   - Implementation architecture
   - Security design
   - WebSocket design
   - CORS strategy
   - Migration plan

3. **[INGRESS_VALIDATION.md](./docs/INGRESS_VALIDATION.md)** - Testing & Validation
   - Pre-deployment validation
   - Deployment validation
   - Security validation
   - Functional validation
   - Performance testing
   - Monitoring validation
   - Rollback triggers

4. **[pms-ingress/README.md](./k8s/charts/platform/pms-ingress/README.md)** - Helm Chart Usage
   - Chart overview
   - Installation instructions
   - Configuration options
   - Environment-specific values
   - Troubleshooting
   - Upgrade/rollback procedures

---

## 👥 Team Responsibilities

### Platform/DevOps Team
- Install AWS Load Balancer Controller
- Request and validate ACM certificate
- Deploy ingress Helm chart
- Configure DNS (Route 53)
- Monitor ALB health
- Set up CloudWatch alarms

### Frontend Team
- Review RuntimeConfigService changes
- Test frontend with same-origin URLs
- Verify no console errors
- Validate Angular routing works
- Test all features end-to-end

### Backend Team
- Review API Gateway CORS changes
- Test API endpoints via ingress
- Verify WebSocket routing works
- Monitor application logs
- Assist with troubleshooting

### QA Team
- Execute full validation suite
- Perform load testing
- Security testing (TLS, headers)
- Cross-browser testing
- Mobile testing

---

## 🔮 Future Roadmap

### Short-term (Month 1-2)
- Enable ALB access logs
- Configure CloudWatch dashboards
- Set up alerting (Slack/PagerDuty)
- Document runbooks

### Medium-term (Month 3-6)
- Enable AWS WAF
- Add security headers (HSTS, CSP)
- Configure rate limiting
- Multi-environment setup (dev/stage/prod)

### Long-term (Month 7+)
- Multi-region failover
- CDN integration (CloudFront)
- Blue/green deployments via ingress
- Canary releases (weighted routing)
- gRPC support

---

## ✅ Acceptance Criteria

The ingress implementation is considered **COMPLETE** when:

- ✅ **Architecture**: Single ALB serves entire platform
- ✅ **Security**: HTTPS enforced, valid certificate
- ✅ **Functionality**: All features work (REST + WebSocket)
- ✅ **Performance**: <200ms response time
- ✅ **Reliability**: 99.9%+ uptime
- ✅ **Cost**: ~40% reduction vs dual LoadBalancers
- ✅ **Documentation**: Complete and team-reviewed
- ✅ **Monitoring**: CloudWatch alarms configured
- ✅ **Validation**: All tests passed
- ✅ **Rollback**: Tested and documented

---

## 📞 Support & Escalation

**For issues during implementation:**

1. **First**: Check documentation (INGRESS_SETUP.md, INGRESS_VALIDATION.md)
2. **Second**: Review AWS console (ALB, target groups, certificates)
3. **Third**: Check logs:
   ```bash
   kubectl logs -n kube-system deployment/aws-load-balancer-controller
   kubectl describe ingress -n pms pms-ingress
   ```
4. **Fourth**: Consult team Slack channel
5. **Fifth**: Escalate to platform team lead

**Critical Issues:**
- Contact on-call engineer immediately
- Follow rollback plan if needed
- Document issue for post-mortem

---

## 🎓 Learning Resources

- [AWS Load Balancer Controller Docs](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [AWS ALB Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [AWS Certificate Manager](https://docs.aws.amazon.com/acm/)
- [WebSocket on ALB](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/application-load-balancers.html#websocket-support)

---

**Document Version**: 1.0  
**Last Updated**: 2026-01-30  
**Status**: Ready for Implementation  
**Owner**: Platform Team
