# Local Development Setup

## Prerequisites

### Required Tools
- **Docker Desktop** (with Kubernetes enabled) OR **Minikube**
- **kubectl** v1.14+ 
- **Git**

### Optional Tools
- **k9s** - Terminal UI for Kubernetes
- **kubectx/kubens** - Context and namespace switching
- **stern** - Multi-pod log tailing

## Initial Setup

### 1. Clone Repository

```bash
git clone <repo-url> pms-infra
cd pms-infra
```

### 2. Start Local Kubernetes

**Docker Desktop:**
- Enable Kubernetes in Docker Desktop settings
- Wait for cluster to be ready

**Minikube:**
```bash
minikube start --memory=8192 --cpus=4
```

### 3. Verify Cluster

```bash
kubectl cluster-info
kubectl get nodes
```

### 4. Configure Secrets

```bash
# Copy example secrets
cp secrets/examples/secrets.env.example k8s/overlays/local/secrets.env

# Edit if needed (default values work for local)
vi k8s/overlays/local/secrets.env
```

### 5. Deploy

```bash
./scripts/deploy-local.sh
```

This will:
- Apply all Kubernetes manifests
- Wait for infrastructure pods (postgres, kafka, rabbitmq, redis)
- Wait for application pods (simulation, trade-capture, validation)
- Display deployment status

## Verification

### Check Pod Status

```bash
kubectl get pods -n pms
```

Expected output:
```
NAME                                  READY   STATUS    RESTARTS   AGE
kafka-xxx                             1/1     Running   0          2m
postgres-xxx                          1/1     Running   0          2m
rabbitmq-xxx                          1/1     Running   0          2m
redis-xxx                             1/1     Running   0          2m
schema-registry-xxx                   1/1     Running   0          2m
simulation-xxx                        1/1     Running   0          2m
trade-capture-xxx                     1/1     Running   0          2m
validation-service-xxx                1/1     Running   0          2m
```

### Check Logs

```bash
# All pods
kubectl logs -f deployment/trade-capture -n pms

# Specific pod
kubectl logs -f <pod-name> -n pms

# Multiple pods (requires stern)
stern trade-capture -n pms
```

### Access Services

The services are accessible via kubectl port-forward or NodePort (if configured).

**Port Forward Examples:**
```bash
# Trade Capture API
kubectl port-forward svc/trade-capture 8082:8082 -n pms

# RabbitMQ Management UI
kubectl port-forward svc/rabbitmq 15672:15672 -n pms

# Schema Registry
kubectl port-forward svc/schema-registry 8081:8081 -n pms
```

Then access:
- Trade Capture: http://localhost:8082
- RabbitMQ UI: http://localhost:15672 (guest/guest)
- Schema Registry: http://localhost:8081

## Common Tasks

### Restart a Service

```bash
kubectl rollout restart deployment/<service-name> -n pms
```

### View Service Logs

```bash
kubectl logs -f deployment/<service-name> -n pms
```

### Execute into Pod

```bash
kubectl exec -it deployment/<service-name> -n pms -- /bin/bash
```

### Check Network Connectivity

```bash
# From simulation pod, test kafka connectivity
kubectl exec -it deployment/simulation -n pms -- nc -zv kafka 19092

# From trade-capture, test postgres
kubectl exec -it deployment/trade-capture -n pms -- nc -zv postgres 5432
```

### Update Configuration

1. Edit manifests in `k8s/base/`
2. Re-apply:
   ```bash
   kubectl apply -k k8s/overlays/local
   ```
3. Restart affected pods if needed

### Clean Up

```bash
# Delete all resources
./scripts/destroy-local.sh

# Or manually
kubectl delete -k k8s/overlays/local
```

## Kustomize Usage

### Build manifests without applying

```bash
kubectl kustomize k8s/overlays/local
```

### Diff before applying

```bash
kubectl diff -k k8s/overlays/local
```

### Apply specific resource

```bash
kubectl apply -f k8s/base/infra/kafka/deployment.yaml
```

## Debugging

### Pod Won't Start

```bash
# Check events
kubectl describe pod <pod-name> -n pms

# Check logs
kubectl logs <pod-name> -n pms

# Check previous logs (if pod crashed)
kubectl logs <pod-name> -n pms --previous
```

### Init Container Stuck

```bash
# Check init container logs
kubectl logs <pod-name> -n pms -c <init-container-name>

# Common init containers:
# - wait-for-postgres
# - wait-for-rabbitmq
# - wait-for-kafka
# - wait-for-schema-registry
```

### Service DNS Not Resolving

```bash
# Check service exists
kubectl get svc -n pms

# Test DNS from within pod
kubectl exec -it deployment/trade-capture -n pms -- nslookup kafka
```

### Kafka/Schema Registry PORT Errors

See `KAFKA_FIX_SUMMARY.md` in the backup directory for detailed fix.

**Quick fix:** Ensure deployments have:
```yaml
spec:
  template:
    spec:
      enableServiceLinks: false
      containers:
      - name: kafka
        command:
          - /bin/bash
          - -c
          - |
            unset KAFKA_PORT
            unset KAFKA_SERVICE_PORT
            /etc/confluent/docker/run
```

### Persistent Volume Issues

```bash
# List PVCs
kubectl get pvc -n pms

# Check PV binding
kubectl get pv

# Delete PVC (will lose data)
kubectl delete pvc <pvc-name> -n pms
```

## Performance Tuning

### Resource Limits (future enhancement)

Edit deployments to add:
```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "1Gi"
    cpu: "500m"
```

### JVM Tuning

For Java apps, add to deployment:
```yaml
env:
  - name: JAVA_OPTS
    value: "-Xms512m -Xmx1024m -XX:+UseG1GC"
```

## Next Steps

- [ ] Set up persistent storage for production
- [ ] Configure resource limits/requests
- [ ] Set up horizontal pod autoscaling
- [ ] Configure network policies
- [ ] Set up monitoring (Prometheus/Grafana)
- [ ] Configure log aggregation (ELK/Loki)

## Useful Aliases

Add to `.bashrc` or `.zshrc`:

```bash
alias k='kubectl'
alias kgp='kubectl get pods -n pms'
alias kgd='kubectl get deployments -n pms'
alias kgs='kubectl get svc -n pms'
alias kdp='kubectl describe pod -n pms'
alias klf='kubectl logs -f -n pms'
```

## References

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kustomize Documentation](https://kustomize.io/)
- [Confluent Kafka on Kubernetes](https://docs.confluent.io/platform/current/installation/docker/operations/index.html)
