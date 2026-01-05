#!/usr/bin/env bash
set -euo pipefail

# Change to repository root (parent of scripts directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

echo "🗑️  Destroying PMS from Local Kubernetes..."

# Delete all resources
kubectl delete -k k8s/overlays-pms/local --ignore-not-found=true

echo "✅ All resources deleted"
