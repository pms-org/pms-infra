#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Deploying PMS to Local Kubernetes..."

# Check prerequisites
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl not found"; exit 1; }
command -v kustomize >/dev/null 2>&1 || echo "⚠️  kustomize not found, using kubectl kustomize"

# Check if secrets file exists
if [ ! -f "k8s/overlays/local/secrets.env" ]; then
    echo "❌ secrets.env not found"
    echo "📝 Copy from example: cp secrets/examples/secrets.env.example k8s/overlays/local/secrets.env"
    exit 1
fi

# Apply manifests
echo "📦 Applying Kubernetes manifests..."
kubectl apply -k k8s/overlays/local

# Wait for infrastructure
echo "⏳ Waiting for infrastructure pods..."
kubectl wait --for=condition=ready pod -l app=postgres -n pms --timeout=120s
kubectl wait --for=condition=ready pod -l app=rabbitmq -n pms --timeout=120s
kubectl wait --for=condition=ready pod -l app=redis -n pms --timeout=120s
kubectl wait --for=condition=ready pod -l app=kafka -n pms --timeout=180s
kubectl wait --for=condition=ready pod -l app=schema-registry -n pms --timeout=120s

# Wait for applications
echo "⏳ Waiting for application pods..."
kubectl wait --for=condition=ready pod -l app=simulation -n pms --timeout=120s
kubectl wait --for=condition=ready pod -l app=trade-capture -n pms --timeout=120s
kubectl wait --for=condition=ready pod -l app=validation-service -n pms --timeout=120s

# Show status
echo ""
echo "✅ Deployment complete!"
echo ""
kubectl get pods -n pms
echo ""
echo "📊 Access services:"
echo "  - Trade Capture:  http://localhost:8082"
echo "  - Simulation:     http://localhost:4000"
echo "  - Validation:     http://localhost:8080"
echo "  - RabbitMQ UI:    http://localhost:15672 (guest/guest)"
echo "  - Schema Registry: http://localhost:8081"
