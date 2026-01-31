# PMS Ingress - Quick Reference Card

## 🎯 What Changed

**Before:**
- 2 LoadBalancers → 2 origins → CORS required
- HTTP only → No encryption
- Ugly URLs → `a391e234...elb.amazonaws.com`

**After:**
- 1 ALB → 1 origin → No CORS needed
- HTTPS everywhere → TLS via ACM
- Clean URL → `pms.yourdomain.com`

---

## 🚀 Installation (5 Steps)

```bash
# 1. Install AWS LB Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=YOUR_CLUSTER \
  --set serviceAccount.name=aws-load-balancer-controller

# 2. Request ACM Certificate
aws acm request-certificate \
  --domain-name pms.yourdomain.com \
  --validation-method DNS \
  --region us-east-1

# 3. Update Certificate ARN in values.yaml
# Edit: pms-infra/k8s/charts/platform/pms-ingress/values.yaml
# Replace: alb.ingress.kubernetes.io/certificate-arn

# 4. Deploy Ingress
helm install pms-ingress ./charts/platform/pms-ingress -n pms

# 5. Configure DNS
# Get ALB DNS: kubectl get ingress -n pms pms-ingress
# Create Route 53 ALIAS: pms.yourdomain.com → ALB DNS
```

---

## 🔍 Validation Commands

```bash
# Check ingress created
kubectl get ingress -n pms

# Check ALB healthy
kubectl get targetgroupbinding -n pms
kubectl describe ingress -n pms pms-ingress

# Test HTTPS
curl -I https://pms.yourdomain.com

# Test redirect
curl -I http://pms.yourdomain.com  # Should 301 → https

# Test API
curl https://pms.yourdomain.com/api/actuator/health

# Test WebSocket
wscat -c wss://pms.yourdomain.com/ws/rttm/metrics
```

---

## 🆘 Quick Troubleshooting

| Problem | Check | Fix |
|---------|-------|-----|
| ALB not creating | `kubectl logs -n kube-system deployment/aws-load-balancer-controller` | Check IAM permissions |
| Targets unhealthy | `kubectl describe targetgroupbinding -n pms` | Check pod health |
| Certificate error | `aws acm describe-certificate --certificate-arn ...` | Verify ARN, region |
| DNS not resolving | `dig pms.yourdomain.com` | Check Route 53 record |
| CORS errors | Browser console | Verify same origin |
| WebSocket fails | Browser Network tab | Check path `/ws/*` |

---

## 🔄 Rollback (1 Minute)

```bash
# Restore LoadBalancers
helm upgrade frontend ./charts/services/frontend --set service.type=LoadBalancer -n pms
helm upgrade apigateway ./charts/services/apigateway --set service.type=LoadBalancer -n pms

# Delete ingress
helm uninstall pms-ingress -n pms

# Restart frontend (restore ConfigMap first if needed)
kubectl rollout restart deployment frontend -n pms
```

---

## 📊 Key Metrics

```bash
# ALB request count
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name RequestCount \
  --dimensions Name=LoadBalancer,Value=app/YOUR_ALB \
  --start-time $(date -u -d '5 min ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 --statistics Sum

# Target response time
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=app/YOUR_ALB \
  --start-time $(date -u -d '5 min ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 --statistics Average
```

---

## 📚 Documentation

- **Setup Guide**: `docs/INGRESS_SETUP.md`
- **Architecture**: `docs/INGRESS_ADR.md`
- **Validation**: `docs/INGRESS_VALIDATION.md`
- **Summary**: `docs/INGRESS_IMPLEMENTATION_SUMMARY.md`
- **Helm Chart**: `k8s/charts/platform/pms-ingress/README.md`

---

## 💰 Cost Impact

- **Before**: $45/month (2 LoadBalancers)
- **After**: $25/month (1 ALB + ACM free)
- **Savings**: $20/month (~40%)

---

## ✅ Success Criteria

- [ ] `https://pms.yourdomain.com` loads
- [ ] No CORS errors in browser
- [ ] All API calls work
- [ ] WebSockets connect
- [ ] No localhost references
- [ ] HTTP → HTTPS redirect works

---

**Need Help?** See full docs in `pms-infra/docs/INGRESS_*.md`
