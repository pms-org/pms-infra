#!/bin/bash
# Quick verification and testing commands for PMS cluster

echo "====================================="
echo "PMS Cluster Quick Status"
echo "====================================="
echo ""

echo "📊 Pod Status:"
kubectl get pods -n pms
echo ""

echo "📝 ConfigMaps (with hash suffixes):"
kubectl get configmaps -n pms | grep -v kube-root
echo ""

echo "🔐 Secrets (with hash suffixes):"
kubectl get secrets -n pms
echo ""

echo "🌐 Services:"
kubectl get svc -n pms
echo ""

echo "📊 Resource Usage:"
kubectl top pods -n pms 2>/dev/null || echo "  (Metrics server not installed - this is normal for Kind)"
echo ""

echo "====================================="
echo "✅ Cluster Status Check Complete"
echo "====================================="
