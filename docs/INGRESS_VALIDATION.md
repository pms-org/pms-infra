# PMS Platform Ingress - Validation & Testing Plan

## Overview

Comprehensive validation strategy to prove the ingress setup is production-ready.

---

## ✅ Pre-Deployment Validation

### 1. AWS Load Balancer Controller Installation

**Verify controller is running:**

```bash
kubectl get deployment -n kube-system aws-load-balancer-controller

# Expected output:
# NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
# aws-load-balancer-controller   2/2     2            2           5m
```

**Check controller logs for errors:**

```bash
kubectl logs -n kube-system deployment/aws-load-balancer-controller --tail=50

# Should see: "controller started successfully"
# Should NOT see: permission errors, certificate errors
```

**Verify IAM permissions:**

```bash
# Check service account annotation
kubectl get sa aws-load-balancer-controller -n kube-system -o yaml | grep eks.amazonaws.com/role-arn

# Expected: eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/...
```

---

### 2. ACM Certificate Validation

**Check certificate status:**

```bash
aws acm describe-certificate \
  --certificate-arn "arn:aws:acm:us-east-1:ACCOUNT:certificate/ID" \
  --region us-east-1 \
  --query 'Certificate.Status' \
  --output text

# Expected: ISSUED
```

**Verify domain validation:**

```bash
aws acm describe-certificate \
  --certificate-arn "arn:aws:acm:us-east-1:ACCOUNT:certificate/ID" \
  --region us-east-1 \
  --query 'Certificate.DomainValidationOptions[0].ValidationStatus' \
  --output text

# Expected: SUCCESS
```

**Check certificate domain:**

```bash
aws acm describe-certificate \
  --certificate-arn "arn:aws:acm:us-east-1:ACCOUNT:certificate/ID" \
  --region us-east-1 \
  --query 'Certificate.DomainName' \
  --output text

# Expected: pms.yourdomain.com or *.yourdomain.com
```

---

### 3. Service Type Changes

**Before deployment, verify current services:**

```bash
kubectl get svc -n pms frontend apigateway -o wide

# Should show:
# TYPE           EXTERNAL-IP                               
# LoadBalancer   a391e234...elb.amazonaws.com  (frontend)
# LoadBalancer   a3ed40b7...elb.amazonaws.com  (apigateway)
```

**After updating Helm charts to ClusterIP:**

```bash
kubectl get svc -n pms frontend apigateway -o wide

# Should show:
# TYPE        CLUSTER-IP      EXTERNAL-IP
# ClusterIP   172.20.225.40   <none>       (frontend)
# ClusterIP   172.20.151.194  <none>       (apigateway)
```

✅ **Pass Criteria**: No EXTERNAL-IP for frontend or apigateway

---

## 🚀 Deployment Validation

### 4. Ingress Resource Creation

**Deploy ingress chart:**

```bash
helm install pms-ingress ./charts/platform/pms-ingress \
  --namespace pms \
  --create-namespace

# Watch for completion
kubectl get ingress -n pms -w
```

**Verify ingress created:**

```bash
kubectl get ingress -n pms

# Expected output:
# NAME          CLASS   HOSTS   ADDRESS                                PORTS     AGE
# pms-ingress   alb     *       k8s-pms-pmsingre-xxx.us-east-1.elb...  80, 443   2m
```

**Check ingress details:**

```bash
kubectl describe ingress -n pms pms-ingress

# Should see:
# - Certificate ARN in annotations
# - Rules for /, /api, /ws
# - No errors in Events section
```

✅ **Pass Criteria**: Ingress shows ADDRESS (ALB DNS name) within 2-3 minutes

---

### 5. ALB Creation Verification

**Check AWS console:**

Go to EC2 → Load Balancers → Find ALB with tag `kubernetes.io/ingress-name: pms-ingress`

**Check ALB via CLI:**

```bash
# Get ALB ARN from ingress
ALB_NAME=$(kubectl get ingress -n pms pms-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' | cut -d'-' -f1-3)

# Describe ALB
aws elbv2 describe-load-balancers \
  --names $ALB_NAME \
  --region us-east-1 \
  --query 'LoadBalancers[0].[LoadBalancerName,State.Code,Scheme,IpAddressType]' \
  --output table

# Expected:
# State: active
# Scheme: internet-facing
# IpAddressType: ipv4
```

**Verify listeners:**

```bash
aws elbv2 describe-listeners \
  --load-balancer-arn $(aws elbv2 describe-load-balancers --names $ALB_NAME --query 'LoadBalancers[0].LoadBalancerArn' --output text) \
  --region us-east-1 \
  --query 'Listeners[*].[Port,Protocol,DefaultActions[0].Type]' \
  --output table

# Expected:
# Port 80:  HTTP  → redirect (to 443)
# Port 443: HTTPS → forward
```

**Verify certificate attached:**

```bash
aws elbv2 describe-listeners \
  --load-balancer-arn $(aws elbv2 describe-load-balancers --names $ALB_NAME --query 'LoadBalancers[0].LoadBalancerArn' --output text) \
  --region us-east-1 \
  --query 'Listeners[?Port==`443`].Certificates[0].CertificateArn' \
  --output text

# Should match your ACM certificate ARN
```

✅ **Pass Criteria**: ALB active with 2 listeners (80, 443) and certificate attached

---

### 6. Target Group Health

**List target groups:**

```bash
kubectl get targetgroupbinding -n pms

# Expected: 2 target groups (frontend, apigateway)
```

**Check target health:**

```bash
# Get target group ARN
TG_ARN=$(kubectl get targetgroupbinding -n pms -o jsonpath='{.items[0].status.targetGroupARN}')

# Check health status
aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --region us-east-1 \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]' \
  --output table

# Expected for ALL targets:
# State: healthy
# Reason: <empty>
```

**If unhealthy, check reason:**

```bash
aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --region us-east-1 \
  --query 'TargetHealthDescriptions[?TargetHealth.State!=`healthy`]' \
  --output json

# Common reasons:
# - "Target.FailedHealthChecks": Pod not responding
# - "Target.NotRegistered": Pod not found
# - "Target.InvalidState": Pod terminating
```

✅ **Pass Criteria**: All targets healthy for both frontend and apigateway

---

## 🌐 DNS Validation

### 7. DNS Configuration

**Get ALB DNS name:**

```bash
ALB_DNS=$(kubectl get ingress -n pms pms-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "ALB DNS: $ALB_DNS"

# Example: k8s-pms-pmsingre-abc123xyz-1234567890.us-east-1.elb.amazonaws.com
```

**Test ALB directly (before DNS):**

```bash
# Test HTTP (should redirect to HTTPS)
curl -I http://$ALB_DNS

# Expected:
# HTTP/1.1 301 Moved Permanently
# Location: https://...

# Test HTTPS
curl -k -I https://$ALB_DNS

# Expected:
# HTTP/2 200 OK
```

**Create Route 53 record:**

```bash
# Example (adjust for your hosted zone)
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "pms.yourdomain.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "Z35SXDOTRQ7X7K",
          "DNSName": "'$ALB_DNS'",
          "EvaluateTargetHealth": true
        }
      }
    }]
  }'
```

**Verify DNS propagation:**

```bash
# Check DNS resolution
dig pms.yourdomain.com +short

# Should return ALB IP addresses
# May take 5-30 minutes to propagate
```

**Test via domain:**

```bash
curl -I https://pms.yourdomain.com

# Expected:
# HTTP/2 200 OK
```

✅ **Pass Criteria**: Domain resolves to ALB and returns 200 OK

---

## 🔒 Security Validation

### 8. HTTPS Enforcement

**Test HTTP → HTTPS redirect:**

```bash
curl -I http://pms.yourdomain.com

# Expected:
# HTTP/1.1 301 Moved Permanently
# Location: https://pms.yourdomain.com/
```

**Test HTTPS works:**

```bash
curl -I https://pms.yourdomain.com

# Expected:
# HTTP/2 200 OK
```

**Verify TLS version:**

```bash
openssl s_client -connect pms.yourdomain.com:443 -tls1_2 < /dev/null 2>&1 | grep "Protocol"

# Expected: TLSv1.2 or TLSv1.3
```

**Check certificate:**

```bash
openssl s_client -connect pms.yourdomain.com:443 -servername pms.yourdomain.com < /dev/null 2>&1 | openssl x509 -noout -subject -issuer

# Expected:
# subject=CN=pms.yourdomain.com
# issuer=C=US, O=Amazon, CN=Amazon RSA 2048 M01
```

✅ **Pass Criteria**: HTTPS works, HTTP redirects, valid certificate

---

### 9. CORS Validation (Should Not Be Needed)

**Test same-origin request:**

```bash
# This should work WITHOUT CORS headers (same origin)
curl https://pms.yourdomain.com/api/auth/login \
  -H "Origin: https://pms.yourdomain.com" \
  -I

# Should return 200/401 WITHOUT Access-Control-Allow-Origin header
# (Same origin = no CORS needed)
```

**Test cross-origin request (should fail):**

```bash
curl https://pms.yourdomain.com/api/auth/login \
  -H "Origin: https://evil.com" \
  -I

# Should return 403 or ignore request
# Browser would block this
```

✅ **Pass Criteria**: Same-origin requests work, no CORS headers needed

---

## 🎯 Functional Validation

### 10. Frontend Loading

**Test frontend loads:**

```bash
curl -I https://pms.yourdomain.com/

# Expected:
# HTTP/2 200 OK
# Content-Type: text/html
```

**Test SPA routing (Angular routes):**

```bash
# Angular routes should return index.html (not 404)
curl -I https://pms.yourdomain.com/portfolio
curl -I https://pms.yourdomain.com/dashboard
curl -I https://pms.yourdomain.com/leaderboard

# All should return:
# HTTP/2 200 OK
# (ALB configured with success-codes: '200-404')
```

**Browser test:**

1. Open `https://pms.yourdomain.com` in browser
2. Open DevTools → Console
3. Check for errors:
   - ❌ No "localhost" references
   - ❌ No CORS errors
   - ❌ No "Mixed Content" warnings
4. Check Network tab:
   - ✅ All requests to `pms.yourdomain.com`
   - ✅ Status: 200 OK

✅ **Pass Criteria**: Frontend loads, no console errors, Angular routing works

---

### 11. API Gateway Routing

**Test API endpoints:**

```bash
# Health check
curl https://pms.yourdomain.com/api/actuator/health

# Expected: {"status":"UP"}
```

**Test auth endpoint:**

```bash
curl -X POST https://pms.yourdomain.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"test"}'

# Expected: 401 Unauthorized (expected - proves routing works)
```

**Test proxied services:**

```bash
# Portfolio (via API Gateway)
curl https://pms.yourdomain.com/api/portfolio/positions

# RTTM (via API Gateway)
curl https://pms.yourdomain.com/api/rttm/metrics

# All should route correctly (even if 401 auth required)
```

✅ **Pass Criteria**: API requests route to API Gateway, return expected responses

---

### 12. WebSocket Validation

**Install wscat (if not installed):**

```bash
npm install -g wscat
```

**Test Analytics WebSocket:**

```bash
wscat -c wss://pms.yourdomain.com/ws

# Expected:
# Connected (press CTRL+C to quit)
# > CONNECT
# < CONNECTED
```

**Test RTTM WebSocket:**

```bash
wscat -c wss://pms.yourdomain.com/ws/rttm/metrics

# Expected:
# Connected
# Should receive metric messages
```

**Test WebSocket with authentication:**

```bash
# Get JWT token first
TOKEN=$(curl -X POST https://pms.yourdomain.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"user","password":"pass"}' | jq -r '.token')

# Connect with token
wscat -c "wss://pms.yourdomain.com/ws/rttm/metrics" \
  -H "Authorization: Bearer $TOKEN"
```

**Browser WebSocket test:**

1. Open browser console
2. Run:
   ```javascript
   const ws = new WebSocket('wss://pms.yourdomain.com/ws/rttm/metrics');
   ws.onopen = () => console.log('✅ WebSocket connected');
   ws.onerror = (e) => console.error('❌ WebSocket error', e);
   ws.onmessage = (m) => console.log('📨 Message:', m.data);
   ```
3. Should see: `✅ WebSocket connected`

✅ **Pass Criteria**: All WebSocket endpoints connect successfully

---

### 13. Real-Time Data Flow

**Test end-to-end data flow:**

1. **Login to frontend**: `https://pms.yourdomain.com`
2. **Navigate to RTTM dashboard**
3. **Check browser console**: Should see WebSocket connected messages
4. **Verify data updates**: Real-time metrics should flow
5. **Check Network tab**: 
   - WebSocket requests: `wss://pms.yourdomain.com/ws/rttm/*`
   - Status: `101 Switching Protocols`
   - Messages flowing

**Test Analytics STOMP:**

1. Navigate to Analytics page
2. Browser console should show:
   ```
   Connected to STOMP broker
   Subscribed to /topic/position-update
   Subscribed to /topic/unrealized-pnl
   ```
3. Data should update in real-time

**Test Leaderboard:**

1. Navigate to Leaderboard page
2. WebSocket should connect
3. Rankings should update automatically

✅ **Pass Criteria**: All real-time features work, data flows correctly

---

## 🔍 Debugging Validation

### 14. Troubleshooting Tools

**Check ingress events:**

```bash
kubectl describe ingress -n pms pms-ingress

# Look for events like:
# - Successfully created ALB
# - Successfully created target groups
# - No error events
```

**Check pod logs:**

```bash
# Frontend logs
kubectl logs -n pms deployment/frontend --tail=50

# API Gateway logs
kubectl logs -n pms deployment/apigateway --tail=50

# Look for connection errors, startup issues
```

**Check ALB access logs (if enabled):**

```bash
# Download logs from S3
aws s3 sync s3://pms-alb-logs/ingress/ ./alb-logs/

# Search for errors
cat alb-logs/*.log | grep "ELB 5" | head -10
```

**Test from within cluster:**

```bash
# Create debug pod
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n pms -- sh

# Inside pod, test internal services
curl http://frontend.pms.svc.cluster.local
curl http://apigateway.pms.svc.cluster.local:8088/actuator/health

# Exit: type 'exit'
```

---

## 📊 Performance Validation

### 15. Load Testing

**Simple load test:**

```bash
# Install Apache Bench
sudo apt-get install apache2-utils

# Test frontend
ab -n 1000 -c 10 https://pms.yourdomain.com/

# Expected:
# Requests per second: >100
# Failed requests: 0
# Time per request: <100ms
```

**WebSocket load test:**

```bash
# Install artillery
npm install -g artillery

# Create test config
cat > ws-test.yaml <<EOF
config:
  target: "wss://pms.yourdomain.com"
  phases:
    - duration: 60
      arrivalRate: 10
scenarios:
  - engine: ws
    flow:
      - connect:
          url: "/ws/rttm/metrics"
      - think: 30
EOF

# Run test
artillery run ws-test.yaml
```

✅ **Pass Criteria**: >99% success rate, <200ms latency

---

### 16. Monitoring Validation

**Check CloudWatch metrics:**

```bash
# ALB request count
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name RequestCount \
  --dimensions Name=LoadBalancer,Value=app/$ALB_NAME \
  --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Sum \
  --region us-east-1
```

**Check target response time:**

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=app/$ALB_NAME \
  --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average \
  --region us-east-1
```

**Set up CloudWatch alarms:**

```bash
# Alarm on unhealthy targets
aws cloudwatch put-metric-alarm \
  --alarm-name pms-alb-unhealthy-targets \
  --alarm-description "Alert when targets are unhealthy" \
  --metric-name UnHealthyHostCount \
  --namespace AWS/ApplicationELB \
  --statistic Average \
  --period 60 \
  --threshold 1 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --dimensions Name=LoadBalancer,Value=app/$ALB_NAME \
  --region us-east-1
```

✅ **Pass Criteria**: Metrics flowing to CloudWatch, alarms configured

---

## ✅ Final Acceptance Checklist

- [ ] **Single endpoint**: `https://pms.yourdomain.com` works
- [ ] **HTTPS enforced**: HTTP redirects to HTTPS
- [ ] **Valid certificate**: Browser shows secure connection
- [ ] **Frontend loads**: No console errors
- [ ] **Angular routing works**: `/portfolio`, `/dashboard` routes work
- [ ] **API calls work**: All REST endpoints respond correctly
- [ ] **No CORS errors**: Same-origin requests work
- [ ] **WebSocket connects**: All WS endpoints establish connections
- [ ] **Real-time data flows**: RTTM, Analytics, Leaderboard update
- [ ] **No localhost references**: All requests to domain
- [ ] **ALB healthy**: All targets healthy
- [ ] **DNS resolves**: Domain points to ALB
- [ ] **Performance acceptable**: <200ms response time
- [ ] **Monitoring active**: CloudWatch metrics flowing
- [ ] **Documentation updated**: Team aware of changes

---

## 🎯 Success Criteria Summary

| Category | Metric | Target | Actual |
|----------|--------|--------|--------|
| Availability | ALB Uptime | 100% | ___% |
| Performance | Avg Response Time | <200ms | ___ms |
| Security | HTTPS Coverage | 100% | ___% |
| Functionality | API Success Rate | >99% | ___% |
| Functionality | WebSocket Success | 100% | ___% |
| Cost | Monthly Cost | <$30 | $___  |

---

## 📝 Validation Report Template

```markdown
# PMS Ingress Validation Report

**Date**: YYYY-MM-DD
**Environment**: Production
**Validator**: [Name]

## Pre-Deployment
- [ ] AWS LB Controller installed
- [ ] ACM certificate validated
- [ ] Services changed to ClusterIP

## Deployment
- [ ] Ingress created successfully
- [ ] ALB provisioned
- [ ] Target groups healthy
- [ ] DNS configured

## Security
- [ ] HTTPS works
- [ ] HTTP redirects
- [ ] Certificate valid
- [ ] No CORS errors

## Functionality
- [ ] Frontend loads
- [ ] API calls work
- [ ] WebSockets connect
- [ ] Real-time data flows

## Performance
- [ ] Response time < 200ms
- [ ] Load test passed
- [ ] No errors under load

## Monitoring
- [ ] CloudWatch metrics flowing
- [ ] Alarms configured
- [ ] Access logs working

## Issues Found
[List any issues discovered during validation]

## Sign-off
- [ ] Platform Engineer: _______
- [ ] DevOps Lead: _______
- [ ] Product Owner: _______

**Status**: ✅ PASSED / ❌ FAILED
```

---

## 🆘 Rollback Triggers

Immediately rollback if:

1. ❌ ALB targets unhealthy for >5 minutes
2. ❌ >10% error rate on API calls
3. ❌ WebSocket connections failing >50%
4. ❌ Frontend not loading
5. ❌ Certificate errors
6. ❌ DNS not resolving after 30 minutes

See [INGRESS_ADR.md](./INGRESS_ADR.md#rollback-plan) for rollback procedure.
