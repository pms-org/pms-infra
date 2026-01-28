# PMS Kubernetes Deployment Guide

## Prerequisites

### Required Tools
- `kubectl` (v1.24+)
- `helm` (v3.12+)
- Access to Kubernetes cluster
- Container registry access (Docker Hub, ACR, ECR, etc.)

### Cluster Requirements
- Kubernetes 1.24+
- Minimum 8 nodes (or equivalent resources)
- Storage class for persistent volumes
- LoadBalancer or Ingress controller
- Optional: Metrics Server, Prometheus, Grafana

## Deployment Steps

### Step 1: Push Docker Images to Registry

```bash
# Login to your registry
docker login

# Tag and push all images
docker push niishantdev/pms-apigateway:latest
docker push niishantdev/pms-auth:latest
docker push niishantdev/pms-portfolio:latest
docker push niishantdev/pms-transactional:latest
docker push niishantdev/pms-trade-capture:latest
docker push niishantdev/pms-simulation:latest
docker push niishantdev/pms-analytics:latest

# Optional: Tag with specific version
VERSION=1.0.0
docker tag niishantdev/pms-apigateway:latest niishantdev/pms-apigateway:$VERSION
docker push niishantdev/pms-apigateway:$VERSION
# Repeat for all services
```

### Step 2: Create Kubernetes Namespace

```bash
kubectl create namespace pms
kubectl label namespace pms env=production
```

### Step 3: Create Secrets

```bash
# Database secrets
kubectl create secret generic pms-db-secret \
  --from-literal=username=pms \
  --from-literal=password=pms \
  --from-literal=database=pmsdb \
  -n pms

# Kafka secrets
kubectl create secret generic pms-kafka-secret \
  --from-literal=bootstrap-servers=kafka:29092 \
  --from-literal=schema-registry-url=http://schema-registry:8081 \
  -n pms

# RabbitMQ secrets
kubectl create secret generic pms-rabbitmq-secret \
  --from-literal=username=rabbit-user \
  --from-literal=password=rabbitmq \
  --from-literal=host=rabbitmq \
  --from-literal=port=5672 \
  -n pms

# Redis secrets
kubectl create secret generic pms-redis-secret \
  --from-literal=host=redis \
  --from-literal=port=6379 \
  --from-literal=password=redis \
  -n pms

# API Keys and JWT Secrets
kubectl create secret generic pms-api-keys \
  --from-literal=auth-jwt-secret=auth-jwt-secret-789 \
  --from-literal=trade-capture-api-key=tc-api-key-123 \
  --from-literal=validation-api-key=val-api-key-123 \
  --from-literal=simulation-api-key=sim-api-key-123 \
  --from-literal=analytics-api-key=d4jsud1r01qgcb0vck8gd4jsud1r01qgcb0vck90 \
  -n pms
```

### Step 4: Deploy Infrastructure Services

```bash
cd /mnt/c/Developer/pms-org/pms-infra/k8s

# Deploy PostgreSQL
helm upgrade --install pms-postgres charts/infra/postgresql \
  --namespace pms \
  --set auth.username=pms \
  --set auth.password=pms \
  --set auth.database=pmsdb \
  --set primary.persistence.size=20Gi \
  --wait

# Deploy Redis
helm upgrade --install pms-redis charts/infra/redis \
  --namespace pms \
  --set auth.password=redis \
  --set master.persistence.size=5Gi \
  --wait

# Deploy RabbitMQ
helm upgrade --install pms-rabbitmq charts/infra/rabbitmq \
  --namespace pms \
  --set auth.username=rabbit-user \
  --set auth.password=rabbitmq \
  --set persistence.size=10Gi \
  --set plugins="rabbitmq_stream rabbitmq_stream_management" \
  --wait

# Deploy Kafka (KRaft mode)
helm upgrade --install pms-kafka charts/infra/kafka \
  --namespace pms \
  --set kraft.enabled=true \
  --set persistence.size=20Gi \
  --set replicaCount=3 \
  --wait

# Deploy Schema Registry
helm upgrade --install pms-schema-registry charts/infra/schema-registry \
  --namespace pms \
  --set kafka.bootstrapServers=pms-kafka:9092 \
  --wait
```

### Step 5: Verify Infrastructure

```bash
# Check all pods are running
kubectl get pods -n pms

# Check services
kubectl get svc -n pms

# Check persistent volumes
kubectl get pvc -n pms

# Test database connection
kubectl run -it --rm --image=postgres:16 --restart=Never psql-test -n pms -- \
  psql -h pms-postgres -U pms -d pmsdb -c "SELECT 1"

# Test Redis connection
kubectl run -it --rm --image=redis:7 --restart=Never redis-test -n pms -- \
  redis-cli -h pms-redis -a redis PING

# Test Kafka connection
kubectl run -it --rm --image=confluentinc/cp-kafka:7.6.0 --restart=Never kafka-test -n pms -- \
  kafka-broker-api-versions --bootstrap-server pms-kafka:9092
```

### Step 6: Create ConfigMaps for Application Services

```bash
# Transactional Service ConfigMap
kubectl create configmap pms-transactional-config \
  --from-literal=TRANSACTIONAL_BUFFER_SIZE=50000 \
  --from-literal=TRANSACTIONAL_OUTBOX_TARGET_LATENCY_MS=200 \
  --from-literal=TRANSACTIONAL_OUTBOX_BATCH_MIN=200 \
  --from-literal=TRANSACTIONAL_OUTBOX_BATCH_MAX=500 \
  --from-literal=TRANSACTIONAL_BATCH_SIZE=5000 \
  --from-literal=TRANSACTIONAL_FLUSH_INTERVAL_MS=10000 \
  --from-literal=TRANSACTIONAL_TRANSACTIONS_PUBLISHING_TOPIC=transactions.created \
  --from-literal=TRANSACTIONAL_TRANSACTIONS_CONSUMER_GROUP_ID=transactional-transactions-group \
  --from-literal=TRANSACTIONAL_TRADES_CONSUMER_DLT_TOPIC=trade.validated.dlt \
  --from-literal=TRANSACTIONAL_TRADES_CONSUMER_CONSUMER_ID=transactional-trades-consumer \
  --from-literal=TRANSACTIONAL_TRADES_CONSUMER_LISTENING_TOPIC=trade.validated \
  --from-literal=TRANSACTIONAL_TRADES_CONSUMER_GROUP_ID=transactional-trades-group \
  -n pms

# Validation Service ConfigMap
kubectl create configmap pms-validation-config \
  --from-literal=KAFKA_CONSUMER_GROUP_ID=validation-consumer-group \
  --from-literal=INCOMING_TRADES_TOPIC=trade.captured \
  --from-literal=OUTGOING_VALID_TRADES_TOPIC=trade.validated \
  --from-literal=OUTGOING_INVALID_TRADES_TOPIC=trade.rejected \
  --from-literal=RTTM_MODE=kafka \
  --from-literal=KAFKA_TOPIC_TRADE_EVENTS=rttm.trade.events \
  --from-literal=KAFKA_TOPIC_DLQ_EVENTS=rttm.dlq.events \
  --from-literal=KAFKA_TOPIC_QUEUE_METRICS=rttm.queue.metrics \
  --from-literal=KAFKA_TOPIC_ERROR_EVENTS=rttm.error.events \
  -n pms

# Analytics Service ConfigMap
kubectl create configmap pms-analytics-config \
  --from-literal=ANALYTICS_CORS_ALLOWED_ORIGINS=http://localhost:4200,http://localhost:8080 \
  -n pms
```

### Step 7: Deploy Core Services

```bash
# Deploy Auth Service
helm upgrade --install pms-auth charts/services/auth \
  --namespace pms \
  --set image.repository=niishantdev/pms-auth \
  --set image.tag=latest \
  --set replicaCount=2 \
  --wait

# Deploy Portfolio Service
helm upgrade --install pms-portfolio charts/services/portfolio \
  --namespace pms \
  --set image.repository=niishantdev/pms-portfolio \
  --set image.tag=latest \
  --set replicaCount=2 \
  --wait

# Deploy Transactional Service
helm upgrade --install pms-transactional charts/services/transactional \
  --namespace pms \
  --set image.repository=niishantdev/pms-transactional \
  --set image.tag=latest \
  --set replicaCount=2 \
  --wait

# Deploy API Gateway
helm upgrade --install pms-apigateway charts/services/apigateway \
  --namespace pms \
  --set image.repository=niishantdev/pms-apigateway \
  --set image.tag=latest \
  --set replicaCount=3 \
  --wait
```

### Step 8: Deploy Business Services

```bash
# Deploy Trade Capture
helm upgrade --install pms-trade-capture charts/services/trade-capture \
  --namespace pms \
  --set image.repository=niishantdev/pms-trade-capture \
  --set image.tag=latest \
  --set replicaCount=2 \
  --wait

# Deploy Simulation
helm upgrade --install pms-simulation charts/services/simulation \
  --namespace pms \
  --set image.repository=niishantdev/pms-simulation \
  --set image.tag=latest \
  --set replicaCount=2 \
  --wait

# Deploy Analytics
helm upgrade --install pms-analytics charts/services/analytics \
  --namespace pms \
  --set image.repository=niishantdev/pms-analytics \
  --set image.tag=latest \
  --set replicaCount=2 \
  --wait

# Skip validation for now due to Spring Boot compatibility issue
# Deploy when code is fixed:
# helm upgrade --install pms-validation charts/services/validation \
#   --namespace pms \
#   --set image.repository=niishantdev/pms-validation \
#   --set image.tag=latest \
#   --set replicaCount=2 \
#   --wait
```

### Step 9: Create Kafka Topics

```bash
# Create a job to initialize Kafka topics
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: kafka-topics-init
  namespace: pms
spec:
  template:
    spec:
      containers:
      - name: kafka-topics
        image: confluentinc/cp-kafka:7.6.0
        command:
        - /bin/bash
        - -c
        - |
          # Trade Capture Topics
          kafka-topics --bootstrap-server pms-kafka:9092 --create --if-not-exists --topic trade.captured --partitions 6 --replication-factor 1
          kafka-topics --bootstrap-server pms-kafka:9092 --create --if-not-exists --topic trade.validated --partitions 6 --replication-factor 1
          kafka-topics --bootstrap-server pms-kafka:9092 --create --if-not-exists --topic trade.rejected --partitions 6 --replication-factor 1
          
          # Validation Topics
          kafka-topics --bootstrap-server pms-kafka:9092 --create --if-not-exists --topic validation.events --partitions 6 --replication-factor 1
          kafka-topics --bootstrap-server pms-kafka:9092 --create --if-not-exists --topic validation.errors --partitions 6 --replication-factor 1
          
          # Transaction Topics
          kafka-topics --bootstrap-server pms-kafka:9092 --create --if-not-exists --topic transactions.created --partitions 6 --replication-factor 1
          
          # RTTM Topics
          kafka-topics --bootstrap-server pms-kafka:9092 --create --if-not-exists --topic rttm.trade.events --partitions 6 --replication-factor 1
          kafka-topics --bootstrap-server pms-kafka:9092 --create --if-not-exists --topic rttm.queue.metrics --partitions 6 --replication-factor 1
          kafka-topics --bootstrap-server pms-kafka:9092 --create --if-not-exists --topic rttm.error.events --partitions 6 --replication-factor 1
          kafka-topics --bootstrap-server pms-kafka:9092 --create --if-not-exists --topic rttm.dlq.events --partitions 6 --replication-factor 1
          
          # Simulation Topics
          kafka-topics --bootstrap-server pms-kafka:9092 --create --if-not-exists --topic simulation.events --partitions 6 --replication-factor 1
          kafka-topics --bootstrap-server pms-kafka:9092 --create --if-not-exists --topic simulation.trades --partitions 6 --replication-factor 1
          
          echo "All Kafka topics created successfully"
      restartPolicy: Never
  backoffLimit: 4
EOF

# Wait for job to complete
kubectl wait --for=condition=complete job/kafka-topics-init -n pms --timeout=300s
```

### Step 10: Configure Ingress (Optional)

```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: pms-ingress
  namespace: pms
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: pms.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: pms-apigateway
            port:
              number: 8080
EOF
```

### Step 11: Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n pms -o wide

# Check services
kubectl get svc -n pms

# Check deployment status
kubectl rollout status deployment/pms-apigateway -n pms
kubectl rollout status deployment/pms-auth -n pms
kubectl rollout status deployment/pms-portfolio -n pms
kubectl rollout status deployment/pms-transactional -n pms
kubectl rollout status deployment/pms-trade-capture -n pms
kubectl rollout status deployment/pms-simulation -n pms
kubectl rollout status deployment/pms-analytics -n pms

# Check logs
kubectl logs -f deployment/pms-apigateway -n pms --tail=50
kubectl logs -f deployment/pms-transactional -n pms --tail=50
kubectl logs -f deployment/pms-analytics -n pms --tail=50

# Check health endpoints
kubectl run curl --image=curlimages/curl:latest --rm -it --restart=Never -n pms -- \
  curl -s http://pms-apigateway:8080/actuator/health
```

## Production Considerations

### High Availability

```yaml
# Example: Update transactional service for HA
helm upgrade pms-transactional charts/services/transactional \
  --namespace pms \
  --set replicaCount=3 \
  --set podDisruptionBudget.enabled=true \
  --set podDisruptionBudget.minAvailable=2 \
  --set affinity.podAntiAffinity.enabled=true
```

### Resource Limits

Update Helm values with appropriate resource requests and limits:

```yaml
# values.yaml
resources:
  limits:
    cpu: 2000m
    memory: 2Gi
  requests:
    cpu: 1000m
    memory: 1Gi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
```

### Monitoring

```bash
# Install Prometheus and Grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --wait

# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Default credentials: admin/prom-operator
```

### Backup Strategy

```bash
# PostgreSQL backup
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
  namespace: pms
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:16
            env:
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: pms-db-secret
                  key: password
            command:
            - /bin/bash
            - -c
            - |
              pg_dump -h pms-postgres -U pms pmsdb > /backup/pmsdb-\$(date +%Y%m%d-%H%M%S).sql
              # Upload to cloud storage (S3, Azure Blob, GCS)
            volumeMounts:
            - name: backup
              mountPath: /backup
          volumes:
          - name: backup
            persistentVolumeClaim:
              claimName: postgres-backup-pvc
          restartPolicy: OnFailure
EOF
```

## Troubleshooting

### Pod Not Starting

```bash
# Check pod events
kubectl describe pod <pod-name> -n pms

# Check logs
kubectl logs <pod-name> -n pms

# Check previous logs (if pod is restarting)
kubectl logs <pod-name> -n pms --previous
```

### Service Not Accessible

```bash
# Check service endpoints
kubectl get endpoints <service-name> -n pms

# Port forward for testing
kubectl port-forward svc/<service-name> 8080:8080 -n pms

# Check network policies
kubectl get networkpolicies -n pms
```

### Database Connection Issues

```bash
# Test database connectivity
kubectl run -it --rm debug --image=postgres:16 --restart=Never -n pms -- \
  psql -h pms-postgres -U pms -d pmsdb -c "SELECT 1"

# Check database pod logs
kubectl logs deployment/pms-postgres -n pms
```

## Rollback Procedure

```bash
# Rollback a specific service
helm rollback pms-transactional -n pms

# Rollback to a specific revision
helm rollback pms-transactional 2 -n pms

# View release history
helm history pms-transactional -n pms
```

## Cleanup

```bash
# Delete all PMS services
helm uninstall pms-apigateway -n pms
helm uninstall pms-auth -n pms
helm uninstall pms-portfolio -n pms
helm uninstall pms-transactional -n pms
helm uninstall pms-trade-capture -n pms
helm uninstall pms-simulation -n pms
helm uninstall pms-analytics -n pms

# Delete infrastructure
helm uninstall pms-postgres -n pms
helm uninstall pms-redis -n pms
helm uninstall pms-rabbitmq -n pms
helm uninstall pms-kafka -n pms
helm uninstall pms-schema-registry -n pms

# Delete namespace (WARNING: This deletes everything)
kubectl delete namespace pms
```

## Next Steps

1. ✅ Review and update Helm chart values for each service
2. ✅ Set up proper secrets management (e.g., External Secrets Operator)
3. ✅ Configure persistent volume classes and backup strategies
4. ✅ Set up monitoring and alerting
5. ✅ Implement GitOps workflow (ArgoCD or Flux)
6. ✅ Set up CI/CD pipeline for automated deployments
7. ✅ Configure network policies for security
8. ✅ Set up service mesh (optional: Istio, Linkerd)
9. ✅ Perform load testing and capacity planning
10. ✅ Document disaster recovery procedures
