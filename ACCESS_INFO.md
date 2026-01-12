# PMS Infrastructure - Access Information

**Generated:** January 12, 2026

## 🔐 ArgoCD Access

### Web UI
- **URL:** `http://$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')`
- **Username:** `admin`
- **Password:** Get with command below

```bash
# Get ArgoCD password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

### CLI Access
```bash
# Install ArgoCD CLI
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x /usr/local/bin/argocd

# Login
argocd login $(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}') \
  --username admin \
  --password $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d) \
  --insecure

# List applications
argocd app list
```

---

## 🗄️ AWS Resources

### EKS Cluster
```bash
# Get cluster info
aws eks describe-cluster --name pms-dev --region us-east-1

# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name pms-dev
```

### Secrets Manager
All application secrets are stored in AWS Secrets Manager:

```bash
# List all PMS secrets
aws secretsmanager list-secrets --region us-east-1 --filters Key=name,Values=pms/dev

# Get a specific secret
aws secretsmanager get-secret-value --secret-id pms/dev/auth --region us-east-1
```

**Secret Paths:**
- `pms/dev/auth` - Auth service credentials
- `pms/dev/simulation` - Simulation service credentials
- `pms/dev/trade-capture` - Trade capture credentials
- `pms/dev/validation` - Validation service credentials
- `pms/dev/database` - PostgreSQL credentials
- `pms/dev/kafka` - Kafka credentials
- `pms/dev/rabbitmq` - RabbitMQ credentials
- `pms/dev/redis` - Redis credentials
- `pms/dev/schema-registry` - Schema Registry credentials

---

## 🌐 Service Endpoints

### Internal (Within Kubernetes)

| Service | Endpoint | Port |
|---------|----------|------|
| Auth | `http://auth.pms.svc.cluster.local` | 8081 |
| API Gateway | `http://apigateway.pms.svc.cluster.local` | 8080 |
| Simulation | `http://simulation.pms.svc.cluster.local` | 8090 |
| Trade Capture | `http://trade-capture.pms.svc.cluster.local` | 8091 |
| Validation | `http://validation-service.pms.svc.cluster.local` | 8092 |
| PostgreSQL | `postgres.pms.svc.cluster.local` | 5432 |
| RabbitMQ Stream | `rabbitmq.pms.svc.cluster.local` | 5552 |
| RabbitMQ AMQP | `rabbitmq.pms.svc.cluster.local` | 5672 |
| Redis | `redis.pms.svc.cluster.local` | 6379 |
| Kafka | `kafka.pms.svc.cluster.local` | 9092 |
| Schema Registry | `schema-registry.pms.svc.cluster.local` | 8081 |

### External Access (Port Forward)

```bash
# Auth Service
kubectl port-forward -n pms svc/auth 8081:8081

# API Gateway
kubectl port-forward -n pms svc/apigateway 8080:8080

# Simulation
kubectl port-forward -n pms svc/simulation 8090:8090

# PostgreSQL
kubectl port-forward -n pms svc/postgres 5432:5432

# RabbitMQ Management
kubectl port-forward -n pms svc/rabbitmq 15672:15672
```

---

## 📊 Monitoring & Logs

### View Logs
```bash
# All services
kubectl get pods -n pms

# Specific service logs
kubectl logs -n pms -l app=auth --tail=100 -f
kubectl logs -n pms -l app=simulation --tail=100 -f
kubectl logs -n pms -l app=trade-capture --tail=100 -f
```

### Pod Status
```bash
# Watch all pods
kubectl get pods -n pms -w

# Describe a pod
kubectl describe pod <pod-name> -n pms

# Get events
kubectl get events -n pms --sort-by='.lastTimestamp'
```

---

## 🔑 Database Access

### PostgreSQL
```bash
# Get password from secret
kubectl get secret -n pms postgres-secrets -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d

# Connect via port-forward
kubectl port-forward -n pms svc/postgres 5432:5432

# Then connect with:
psql -h localhost -U pms -d pmsdb
```

### RabbitMQ Management
```bash
# Get credentials
kubectl get secret -n pms rabbitmq-secrets -o jsonpath='{.data.RABBITMQ_DEFAULT_USER}' | base64 -d
kubectl get secret -n pms rabbitmq-secrets -o jsonpath='{.data.RABBITMQ_DEFAULT_PASS}' | base64 -d

# Access management UI
kubectl port-forward -n pms svc/rabbitmq 15672:15672

# Open: http://localhost:15672
```

---

## 🎯 Quick Commands

### Check Everything
```bash
# All resources in pms namespace
kubectl get all -n pms

# All services are running
kubectl get pods -n pms | grep Running

# ArgoCD applications
kubectl get applications -n argocd
```

### Restart Services
```bash
# Restart a specific service
kubectl rollout restart deployment <service-name> -n pms

# Restart all services
for deployment in auth apigateway simulation trade-capture validation-service; do
  kubectl rollout restart deployment $deployment -n pms
done
```

### Scale Services
```bash
# Scale a service
kubectl scale deployment simulation -n pms --replicas=2

# Check replicas
kubectl get deployment -n pms
```

---

## 🆘 Troubleshooting

### Service Not Starting
```bash
# Check pod status
kubectl get pods -n pms

# Describe the pod
kubectl describe pod <pod-name> -n pms

# Check logs
kubectl logs <pod-name> -n pms

# Check init container logs
kubectl logs <pod-name> -n pms -c wait-for-postgres
```

### Secret Issues
```bash
# Check ExternalSecrets
kubectl get externalsecret -n pms

# Force secret sync
kubectl annotate externalsecret -n pms <secret-name> force-sync=$(date +%s) --overwrite

# Check secret content
kubectl get secret <secret-name> -n pms -o yaml
```

### ArgoCD Sync Issues
```bash
# Check application status
kubectl get application pms-platform -n argocd

# Sync application
kubectl patch application pms-platform -n argocd --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'

# Check sync status
argocd app get pms-platform
```

---

## 📝 Important Notes

1. **Health Checks:** Currently disabled - enable after configuring Spring Boot Actuator
2. **Secrets:** All stored in AWS Secrets Manager, synced via External Secrets Operator
3. **Auto-Sync:** ArgoCD is configured for automatic synchronization
4. **Namespace:** All PMS services run in the `pms` namespace

---

## 📞 Support

- **Documentation:** [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)
- **Quick Start:** [QUICK_START.md](./QUICK_START.md)
- **Repository:** https://github.com/pms-org/pms-infra

---

*Last Updated: January 12, 2026*
