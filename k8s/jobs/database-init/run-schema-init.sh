#!/bin/bash

# ============================================
# PMS Database Schema Initialization Helper
# ============================================
# This script helps initialize database schemas for PMS
# Usage: ./run-schema-init.sh [dev|main|prod]
# ============================================

set -e

ENVIRONMENT="${1:-dev}"
NAMESPACE="pms"
JOB_NAME="init-all-schemas"
JOB_FILE="init-all-schemas-job.yaml"

echo "=========================================="
echo "PMS Database Schema Initialization"
echo "=========================================="
echo "Environment: $ENVIRONMENT"
echo "Namespace: $NAMESPACE"
echo "Job: $JOB_NAME"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

# Check if job file exists
if [ ! -f "$JOB_FILE" ]; then
    echo "❌ Job file not found: $JOB_FILE"
    echo "Please run this script from the k8s/jobs directory"
    exit 1
fi

# Check current context
CURRENT_CONTEXT=$(kubectl config current-context)
echo "Current kubectl context: $CURRENT_CONTEXT"
echo ""
read -p "Is this the correct context for $ENVIRONMENT? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Aborted. Please switch to the correct context first."
    echo "   Use: kubectl config use-context <context-name>"
    exit 1
fi

# Clean up any existing job
echo ">>> Cleaning up existing job..."
kubectl delete job $JOB_NAME -n $NAMESPACE 2>/dev/null && echo "   Old job deleted" || echo "   No existing job found"
echo ""

# Apply the job
echo ">>> Creating database initialization job..."
kubectl apply -f $JOB_FILE
echo ""

# Wait for job to complete
echo ">>> Waiting for job to complete (timeout: 120s)..."
if kubectl wait --for=condition=complete job/$JOB_NAME -n $NAMESPACE --timeout=120s 2>/dev/null; then
    echo ""
    echo "=========================================="
    echo "✅ Job completed successfully!"
    echo "=========================================="
    echo ""
    
    # Show logs
    echo ">>> Job Logs:"
    echo "=========================================="
    kubectl logs -n $NAMESPACE job/$JOB_NAME | tail -70
    echo ""
    
    # Ask if user wants to clean up the job
    read -p "Delete the job now? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl delete job $JOB_NAME -n $NAMESPACE
        echo "✓ Job deleted"
    else
        echo "ℹ Job will auto-delete in 5 minutes (ttlSecondsAfterFinished: 300)"
    fi
    
    echo ""
    echo "=========================================="
    echo "✅ Database initialization complete!"
    echo "=========================================="
    exit 0
else
    echo ""
    echo "=========================================="
    echo "❌ Job failed or timed out"
    echo "=========================================="
    echo ""
    echo ">>> Checking job status..."
    kubectl get job $JOB_NAME -n $NAMESPACE
    echo ""
    echo ">>> Job Logs:"
    kubectl logs -n $NAMESPACE job/$JOB_NAME 2>/dev/null || echo "No logs available yet"
    echo ""
    echo ">>> Job Events:"
    kubectl describe job $JOB_NAME -n $NAMESPACE | grep -A 10 Events:
    echo ""
    echo "Troubleshooting tips:"
    echo "1. Check RDS connectivity: kubectl run psql-test -n $NAMESPACE --image=postgres:16 --rm -it -- psql postgresql://postgres:5432/pmsdb"
    echo "2. Verify secrets: kubectl get secret pms-global-secrets -n $NAMESPACE -o yaml"
    echo "3. Check pod logs: kubectl logs -n $NAMESPACE -l app=database-init"
    echo "4. Delete and retry: kubectl delete job $JOB_NAME -n $NAMESPACE && ./run-schema-init.sh"
    exit 1
fi
