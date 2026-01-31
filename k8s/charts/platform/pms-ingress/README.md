# PMS Platform Ingress Chart

Production-grade Kubernetes Ingress for PMS Platform using AWS Load Balancer Controller.

## Overview

This chart deploys a single AWS Application Load Balancer (ALB) that routes traffic to the PMS platform services:

- **Frontend** (Angular SPA): `/`
- **API Gateway** (REST): `/api/*`
- **API Gateway** (WebSocket): `/ws/*`

## Architecture

```
Internet (HTTPS)
   ↓
Route 53: pms.yourdomain.com
   ↓
AWS ALB (managed by Ingress Controller)
   ├── Port 80  → Redirect to 443
   └── Port 443 → HTTPS/WSS
       ├── /       → frontend:80
       ├── /api/*  → apigateway:8088
       └── /ws/*   → apigateway:8088
```

## Prerequisites

1. **AWS Load Balancer Controller** installed in your EKS cluster
2. **ACM Certificate** for TLS termination
3. **Frontend service** type changed to `ClusterIP`
4. **API Gateway service** type changed to `ClusterIP`

## Installation

### Step 1: Install AWS Load Balancer Controller

See [../../../docs/INGRESS_SETUP.md](../../../docs/INGRESS_SETUP.md) for detailed instructions.

Quick install:

```bash
# Add Helm repo
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=<your-cluster-name> \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

### Step 2: Request ACM Certificate

```bash
aws acm request-certificate \
  --domain-name pms.yourdomain.com \
  --validation-method DNS \
  --region us-east-1
```

Note the Certificate ARN from the output.

### Step 3: Update values.yaml

Edit `values.yaml` and replace:

```yaml
alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:us-east-1:YOUR_ACCOUNT_ID:certificate/YOUR_CERT_ID"
```

Optionally set your domain:

```yaml
host: "pms.yourdomain.com"
```

### Step 4: Install Ingress Chart

```bash
helm install pms-ingress . \
  --namespace pms \
  --create-namespace
```

### Step 5: Get ALB DNS Name

```bash
kubectl get ingress -n pms pms-ingress
```

Output:
```
NAME          CLASS   HOSTS   ADDRESS                                    PORTS     AGE
pms-ingress   alb     *       k8s-pms-pmsingre-abc123-1234567890.us-east-1.elb.amazonaws.com   80, 443   2m
```

### Step 6: Configure DNS

Create a Route 53 ALIAS record pointing to the ALB DNS name.

## Configuration

### values.yaml

Key configuration options:

```yaml
# ACM Certificate (REQUIRED)
ingress:
  annotations:
    alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:..."

# Domain name (optional)
host: "pms.yourdomain.com"

# Route configuration
routes:
  frontend:
    enabled: true
    path: /
    service:
      name: frontend
      port: 80
  
  api:
    enabled: true
    path: /api
    service:
      name: apigateway
      port: 8088
  
  websocket:
    enabled: true
    path: /ws
    service:
      name: apigateway
      port: 8088
```

### Environment-specific values

Create `values-dev.yaml`, `values-prod.yaml`:

```yaml
# values-prod.yaml
host: "pms.production.com"
ingress:
  annotations:
    alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:us-east-1:123456789:certificate/prod-cert"

features:
  waf:
    enabled: true
    aclArn: "arn:aws:wafv2:us-east-1:123456789:regional/webacl/pms-prod/..."
```

Install with environment-specific values:

```bash
helm install pms-ingress . \
  -f values.yaml \
  -f values-prod.yaml \
  --namespace pms
```

## Routing Rules

### Path Priority

Ingress rules are evaluated in order. More specific paths MUST come before generic paths:

1. `/api/*` → API Gateway (REST endpoints)
2. `/ws/*` → API Gateway (WebSocket endpoints)
3. `/` → Frontend (catch-all for Angular routing)

### WebSocket Support

WebSocket connections work via the `/ws/*` path:

- **Analytics**: `wss://pms.yourdomain.com/ws` (SockJS/STOMP)
- **RTTM**: `wss://pms.yourdomain.com/ws/rttm/*`
- **Leaderboard**: `wss://pms.yourdomain.com/ws/leaderboard/*`

The ALB is configured with:
- Idle timeout: 300 seconds
- Sticky sessions enabled
- Connection upgrade support

## Security

### TLS Configuration

- **HTTP → HTTPS redirect**: Automatic via `ssl-redirect` annotation
- **TLS termination**: At ALB using ACM certificate
- **Minimum TLS version**: 1.2 (ALB default)

### Security Headers

Add security headers via custom annotations:

```yaml
ingress:
  annotations:
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

### AWS WAF (Optional)

Enable WAF protection:

```yaml
features:
  waf:
    enabled: true
    aclArn: "arn:aws:wafv2:us-east-1:ACCOUNT_ID:regional/webacl/NAME/ID"
```

### AWS Shield (Optional)

Shield Standard is automatically enabled on ALB. For Shield Advanced:

```yaml
features:
  shield:
    enabled: true
```

## Monitoring

### Access Logs

Enable ALB access logs to S3:

```yaml
features:
  accessLogs:
    enabled: true
    bucket: "pms-alb-logs"
    prefix: "ingress"
```

### Health Checks

Health check configuration:

```yaml
ingress:
  annotations:
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: '15'
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: '5'
    alb.ingress.kubernetes.io/healthy-threshold-count: '2'
    alb.ingress.kubernetes.io/unhealthy-threshold-count: '2'
```

### Metrics

View ALB metrics in CloudWatch:

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=<alb-arn-suffix> \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 3600 \
  --statistics Average
```

## Troubleshooting

### ALB Not Creating

Check controller logs:

```bash
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

Check ingress events:

```bash
kubectl describe ingress -n pms pms-ingress
```

### Certificate Issues

Verify certificate ARN:

```bash
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:us-east-1:ACCOUNT:certificate/ID \
  --region us-east-1
```

Certificate must be:
- In `ISSUED` status
- In same region as ALB
- Valid for your domain

### WebSocket Connection Failures

Test WebSocket connectivity:

```bash
# Install wscat
npm install -g wscat

# Test connection
wscat -c wss://pms.yourdomain.com/ws/rttm/metrics
```

Check ALB target group health:

```bash
kubectl get targetgroupbinding -n pms
kubectl describe targetgroupbinding -n pms <binding-name>
```

### CORS Errors

With ingress, CORS should NOT be needed (same origin). If you see CORS errors:

1. Verify frontend and API are both accessed via `pms.yourdomain.com`
2. Check browser console for actual origin
3. Remove or simplify API Gateway CORS config

## Cost Optimization

### ALB Pricing

- **Hourly charge**: ~$0.0225/hour (~$16/month)
- **LCU charges**: Variable based on traffic
- **Data transfer**: Standard AWS rates

**Estimated monthly cost**: $25-50 (vs $45-90 with dual LoadBalancers)

### Cost Reduction Tips

1. Use a single ingress for multiple environments (dev/stage in one cluster)
2. Enable access logs only in production
3. Disable WAF in development
4. Use target group deregistration delay to reduce costs during deployments

## Upgrade

```bash
helm upgrade pms-ingress . \
  --namespace pms \
  -f values.yaml
```

## Rollback

### Rollback to Previous Version

```bash
helm rollback pms-ingress -n pms
```

### Rollback to LoadBalancer Services

If you need to revert to direct LoadBalancer exposure:

```bash
# Update frontend service
helm upgrade frontend ../../../charts/services/frontend \
  --set service.type=LoadBalancer \
  -n pms

# Update apigateway service
helm upgrade apigateway ../../../charts/services/apigateway \
  --set service.type=LoadBalancer \
  -n pms

# Delete ingress
helm uninstall pms-ingress -n pms
```

## References

- [AWS Load Balancer Controller Documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Ingress Annotations Reference](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.7/guide/ingress/annotations/)
- [AWS ALB Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)

## Support

For issues or questions:
1. Check [../../../docs/INGRESS_SETUP.md](../../../docs/INGRESS_SETUP.md)
2. Review controller logs
3. Check AWS console for ALB/target group status
4. Review ingress events with `kubectl describe`
