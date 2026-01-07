kubectl create secret generic postgres-secrets -n pms --context kind-pms \
  --from-literal=POSTGRES_PASSWORD=pms \
  --dry-run=client -o yaml | kubectl apply -f - --context kind-pms

kubectl create secret generic kafka-secrets -n pms --context kind-pms \
  --from-literal=KAFKA_PASSWORD=kafka \
  --dry-run=client -o yaml | kubectl apply -f - --context kind-pms

kubectl create secret generic simulation-secrets -n pms --context kind-pms \
  --from-literal=SIMULATION_DB_PASSWORD=pms \
  --from-literal=SIMULATION_API_KEY=sim-api-key-123 \
  --from-literal=SIMULATION_JWT_SECRET=sim-jwt-secret-456 \
  --dry-run=client -o yaml | kubectl apply -f - --context kind-pms
kubectl create secret generic trade-capture-secrets -n pms --context kind-pms \
  --from-literal=TRADE_CAPTURE_DB_PASSWORD=pms \
  --from-literal=TRADE_CAPTURE_API_KEY=tc-api-key-123 \
  --from-literal=TRADE_CAPTURE_JWT_SECRET=tc-jwt-secret-456 \
  --dry-run=client -o yaml | kubectl apply -f - --context kind-pms

kubectl create secret generic validation-service-secrets -n pms --context kind-pms \
  --from-literal=VALIDATION_API_KEY=val-api-key-123 \
  --from-literal=VALIDATION_DB_PASSWORD=pms \
  --from-literal=VALIDATION_JWT_SECRET=val-jwt-secret-456 \
  --dry-run=client -o yaml | kubectl apply -f - --context kind-pms
kubectl create secret generic rabbitmq-secrets -n pms --kube-context kind-pms \
  --from-literal=RABBITMQ_PASSWORD=rabbitmq \
  --dry-run=client -o yaml | kubectl apply -f - --kube-context kind-pms
kubectl create secret generic rabbitmq-secrets -n pms --context kind-pms \
  --from-literal=RABBITMQ_PASSWORD=rabbitmq \
  --dry-run=client -o yaml | kubectl apply -f - --context kind-pms

kubectl create secret generic redis-secrets -n pms --context kind-pms \
  --from-literal=REDIS_PASSWORD=redis \
  --dry-run=client -o yaml | kubectl apply -f - --context kind-pms

kubectl create secret generic schema-registry-secrets -n pms --context kind-pms \
  --from-literal=SCHEMA_REGISTRY_PASSWORD=schema \
  --dry-run=client -o yaml | kubectl apply -f - --context kind-pms