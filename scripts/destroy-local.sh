#!/usr/bin/env bash
set -euo pipefail

echo "🗑️  Destroying PMS from Local Kubernetes..."

# Delete all resources
kubectl delete -k k8s/overlays/local --ignore-not-found=true

echo "✅ All resources deleted"
