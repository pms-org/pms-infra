# Troubleshooting Guide

## Quick Diagnostics

### Check Overall Status

```bash
# View all pods
kubectl get pods -n pms

# Check pod details
kubectl describe pod -n pms <pod-name>

# View pod logs
kubectl logs -n pms <pod-name> --tail=100

# Follow logs in real-time
kubectl logs -n pms <pod-name> -f
```

### Common Issues

## Kafka Issues

### Issue: Kafka Pod Crashes with "port is deprecated"

**Symptoms:**
- Kafka pod CrashLoopBackOff
- Logs show: `port is deprecated. Please use listeners instead`
- Stream closed with EOF error

**Root Cause:**
Kubernetes service discovery injects environment variables like `KAFKA_PORT=tcp://10.x.x.x:9092` when a service is named "kafka". Confluent Kafka images detect `*_PORT` variables and interpret them as deprecated configuration, causing a clean exit.

**Solution:**
Already fixed in deployments with two mechanisms:

1. Disable automatic service link injection:
```yaml
spec:
  template:
    spec:
      enableServiceLinks: false
```

2. Explicitly unset PORT variables before starting Kafka:
```yaml
containers:
  - name: kafka
    command: 
      - /bin/bash
      - -c
      - |
        unset KAFKA_PORT
        unset KAFKA_SERVICE_PORT
        unset PORT
        /etc/confluent/docker/run
```

**Verification:**
```bash
# Check Kafka logs for successful startup
kubectl logs -n pms kafka-<pod-id> | grep "Kafka Server started"
kubectl logs -n pms kafka-<pod-id> | grep "Registered broker"
kubectl logs -n pms kafka-<pod-id> | grep "RUNNING"

# Expected output:
# [KafkaServer id=1] started
# [BrokerMetadataPublisher id=1] Registered broker 1 at path /brokers/ids/1
# [BrokerServer id=1] Transition from STARTING to RUNNING
```

### Issue: Kafka Not Accepting Connections

**Symptoms:**
- Applications can't connect to Kafka
- Connection timeout errors

**Diagnosis:**
```bash
# Check Kafka service
kubectl get svc kafka -n pms

# Test connectivity from another pod
kubectl run -it --rm debug --image=busybox --restart=Never -n pms -- nc -zv kafka 9092

# Check Kafka listeners
kubectl logs -n pms kafka-<pod-id> | grep ADVERTISED_LISTENERS
```

**Common Causes:**
1. Wrong port (use 19092 for internal communication)
2. Service not created properly
3. Network policies blocking traffic

**Solution:**
```yaml
# Applications should use internal listener
env:
  - name: KAFKA_BOOTSTRAP_SERVERS
    value: "kafka:19092"  # Not 9092
```

## Schema Registry Issues

### Issue: Schema Registry Can't Connect to Kafka

**Symptoms:**
- Schema Registry pod CrashLoopBackOff
- Logs show connection refused to Kafka

**Diagnosis:**
```bash
# Check Schema Registry logs
kubectl logs -n pms schema-registry-<pod-id>

# Check if Kafka is ready
kubectl get pods -n pms -l app=kafka
```

**Solution:**
Ensure Schema Registry uses internal Kafka listener:
```yaml
env:
  - name: SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS
    value: "kafka:19092"
```

### Issue: Schema Registry PORT Collision

**Symptoms:**
- Schema Registry exits immediately
- Similar "port is deprecated" errors

**Solution:**
Same fix as Kafka:
```yaml
spec:
  template:
    spec:
      enableServiceLinks: false
containers:
  - command:
      - /bin/bash
      - -c
      - |
        unset SCHEMA_REGISTRY_PORT
        unset SCHEMA_REGISTRY_SERVICE_PORT
        unset PORT
        /etc/confluent/docker/run
```

## Database Issues

### Issue: PostgreSQL Connection Refused

**Diagnosis:**
```bash
# Check PostgreSQL pod
kubectl get pod -n pms postgres-<pod-id>

# Check logs
kubectl logs -n pms postgres-<pod-id>

# Test connection
kubectl exec -it -n pms postgres-<pod-id> -- psql -U pms -c '\l'
```

**Common Causes:**
1. Wrong credentials in secrets
2. Database not fully initialized
3. PVC issues

**Solution:**
```bash
# Verify secret values (base64 encoded)
kubectl get secret postgres-credentials -n pms -o yaml

# Decode to verify
echo "<base64-value>" | base64 -d

# Recreate secret if needed
kubectl delete secret postgres-credentials -n pms
kubectl apply -k k8s/overlays/local
```

### Issue: PVC Bound but Pod Not Starting

**Diagnosis:**
```bash
# Check PVC status
kubectl get pvc -n pms

# Check events
kubectl get events -n pms --sort-by='.lastTimestamp'
```

**Solution:**
If PVC stuck in Pending:
```bash
# Check storage class
kubectl get storageclass

# Delete and recreate PVC
kubectl delete pvc postgres-pvc -n pms
kubectl apply -k k8s/overlays/local
```

## RabbitMQ Issues

### Issue: RabbitMQ Stream Plugin Not Enabled

**Symptoms:**
- Applications can't create streams
- "Stream plugin not enabled" errors

**Diagnosis:**
```bash
# Check RabbitMQ plugins
kubectl exec -it -n pms rabbitmq-<pod-id> -- rabbitmq-plugins list
```

**Solution:**
Already enabled in deployment:
```yaml
command: [/bin/bash, -c]
args:
  - |
    rabbitmq-plugins enable --offline rabbitmq_stream
    docker-entrypoint.sh rabbitmq-server
```

### Issue: RabbitMQ Management UI Not Accessible

**Diagnosis:**
```bash
# Check service
kubectl get svc rabbitmq -n pms

# Port forward if needed
kubectl port-forward -n pms svc/rabbitmq 15672:15672
```

## Redis Issues

### Issue: Redis Config File Error

**Symptoms:**
- Redis crashes with "can't open config file"

**Solution:**
Already fixed with separated command and args:
```yaml
command: [redis-server]
args:
  - --loadmodule
  - /usr/lib/redis/modules/redisearch.so
  - --loadmodule
  - /usr/lib/redis/modules/redisgraph.so
```

## Application Issues

### Issue: Trade-Capture Not Processing Trades

**Diagnosis:**
```bash
# Check trade-capture logs
kubectl logs -n pms trade-capture-<pod-id> --tail=100

# Look for OutboxDispatcher activity
kubectl logs -n pms trade-capture-<pod-id> | grep OutboxDispatcher

# Check database connection
kubectl logs -n pms trade-capture-<pod-id> | grep -i "database\|postgres"
```

**Common Causes:**
1. PostgreSQL not ready
2. Kafka not accessible
3. Wrong configuration

**Solution:**
Verify init containers wait for dependencies:
```yaml
initContainers:
  - name: wait-for-postgres
    image: busybox:1.35
    command: ['sh', '-c', 'until nc -z postgres 5432; do echo waiting for postgres; sleep 2; done;']
  - name: wait-for-kafka
    image: busybox:1.35
    command: ['sh', '-c', 'until nc -z kafka 19092; do echo waiting for kafka; sleep 2; done;']
```

### Issue: Simulation Not Generating Trades

**Diagnosis:**
```bash
# Check simulation logs
kubectl logs -n pms simulation-<pod-id>

# Check RabbitMQ connection
kubectl logs -n pms simulation-<pod-id> | grep -i rabbit
```

## Kustomize Build Issues

### Issue: Resource Not Found

**Error:**
```
unable to find one of 'kustomization.yaml', 'kustomization.yml' or 'Kustomization'
```

**Solution:**
```bash
# Verify kustomization.yaml exists
ls k8s/overlays/local/kustomization.yaml

# Check file syntax
kubectl kustomize k8s/overlays/local --enable-alpha-plugins
```

### Issue: Secret Generation Fails

**Error:**
```
couldn't make secret: file "secrets.env" not found
```

**Solution:**
```bash
# Create secrets.env from example
cp secrets/examples/secrets.env.example k8s/overlays/local/secrets.env

# Edit with actual values
vim k8s/overlays/local/secrets.env

# Verify path in kustomization.yaml
cat k8s/overlays/local/kustomization.yaml | grep envs
```

## Networking Issues

### Issue: Service-to-Service Communication Failing

**Diagnosis:**
```bash
# Check service discovery
kubectl get svc -n pms

# Test DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -n pms -- nslookup kafka

# Test connectivity
kubectl run -it --rm debug --image=busybox --restart=Never -n pms -- nc -zv kafka 19092
```

**Common Causes:**
1. Wrong service name in configuration
2. Wrong port number
3. Network policies

**Solution:**
Verify service configuration:
```bash
# Check service selectors match pod labels
kubectl get svc kafka -n pms -o yaml | grep selector
kubectl get pod -n pms -l app=kafka --show-labels
```

## Resource Issues

### Issue: Pods Evicted Due to Resource Pressure

**Diagnosis:**
```bash
# Check node resources
kubectl top nodes

# Check pod resources
kubectl top pods -n pms

# Check events
kubectl get events -n pms | grep Evicted
```

**Solution:**
Add resource limits:
```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "1Gi"
    cpu: "500m"
```

## Debugging Techniques

### Get Shell Access to Pod

```bash
# Exec into running pod
kubectl exec -it -n pms <pod-name> -- /bin/bash

# Or sh if bash not available
kubectl exec -it -n pms <pod-name> -- /bin/sh
```

### Copy Files From/To Pod

```bash
# Copy from pod
kubectl cp pms/<pod-name>:/path/to/file ./local-file

# Copy to pod
kubectl cp ./local-file pms/<pod-name>:/path/to/file
```

### View All Events

```bash
# Recent events
kubectl get events -n pms --sort-by='.lastTimestamp' | tail -20

# Watch events in real-time
kubectl get events -n pms -w
```

### Generate Diagnostic Bundle

```bash
#!/bin/bash
# Save as diagnose.sh

mkdir -p diagnostics
kubectl get all -n pms > diagnostics/all-resources.yaml
kubectl describe pods -n pms > diagnostics/pod-descriptions.txt
kubectl get events -n pms --sort-by='.lastTimestamp' > diagnostics/events.txt

for pod in $(kubectl get pods -n pms -o name); do
  pod_name=$(basename $pod)
  kubectl logs -n pms $pod_name > diagnostics/${pod_name}.log 2>&1
done

tar -czf diagnostics-$(date +%Y%m%d-%H%M%S).tar.gz diagnostics/
```

## Performance Tuning

### Kafka Performance

```yaml
env:
  - name: KAFKA_NUM_NETWORK_THREADS
    value: "3"
  - name: KAFKA_NUM_IO_THREADS
    value: "8"
  - name: KAFKA_SOCKET_SEND_BUFFER_BYTES
    value: "102400"
  - name: KAFKA_SOCKET_RECEIVE_BUFFER_BYTES
    value: "102400"
```

### PostgreSQL Performance

```yaml
env:
  - name: POSTGRES_INITDB_ARGS
    value: "-E UTF8 --locale=C"
  - name: PGDATA
    value: /var/lib/postgresql/data/pgdata
  # Add postgresql.conf customizations via ConfigMap
```

## Getting Help

If issues persist:

1. **Gather diagnostics**: Run diagnostic bundle script
2. **Check documentation**: Review architecture.md and local-setup.md
3. **Review logs**: Examine all relevant pod logs
4. **Check configuration**: Verify secrets and config maps
5. **Test connectivity**: Use debug pod to test service-to-service communication

## Common Commands Reference

```bash
# Quick status check
kubectl get pods -n pms

# Detailed pod info
kubectl describe pod -n pms <pod-name>

# Follow logs
kubectl logs -n pms <pod-name> -f

# Restart deployment
kubectl rollout restart deployment -n pms <deployment-name>

# Scale deployment
kubectl scale deployment -n pms <deployment-name> --replicas=2

# Delete and recreate pod
kubectl delete pod -n pms <pod-name>

# Check secrets
kubectl get secrets -n pms

# Check config maps
kubectl get configmaps -n pms

# Port forward for local access
kubectl port-forward -n pms svc/<service-name> <local-port>:<service-port>
```
