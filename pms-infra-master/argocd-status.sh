#!/bin/bash

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🎯 PMS Infrastructure - ArgoCD Status Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check ArgoCD namespace
echo "📦 ArgoCD Namespace:"
kubectl get namespace argocd 2>/dev/null || echo "❌ ArgoCD namespace not found"
echo ""

# Check ArgoCD pods
echo "🚀 ArgoCD Pods:"
kubectl get pods -n argocd -o wide
echo ""

# Check ArgoCD project
echo "📋 ArgoCD Project:"
kubectl get appproject -n argocd
echo ""

# Check ArgoCD applications
echo "📱 ArgoCD Applications:"
kubectl get applications -n argocd 2>/dev/null || echo "ℹ️ No applications deployed yet"
echo ""

# Check PMS namespace
echo "🏢 PMS Namespace Pods:"
kubectl get pods -n pms -o wide
echo ""

# Check PMS services
echo "🌐 PMS Services:"
kubectl get svc -n pms
echo ""

# Get ArgoCD admin password
echo "🔐 ArgoCD Admin Credentials:"
echo "   Username: admin"
echo "   Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)"
echo ""

# Port forward instructions
echo "🌍 Access ArgoCD UI:"
echo "   1. Run: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "   2. Open: https://localhost:8080"
echo "   3. Login with credentials above"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Status check complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
