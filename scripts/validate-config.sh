#!/bin/bash
# Configuration Validation Script
# Usage: ./validate-config.sh <service-name>

set -e

SERVICE=$1
NAMESPACE=${2:-pms}

if [ -z "$SERVICE" ]; then
    echo "Usage: $0 <service-name> [namespace]"
    echo "Example: $0 simulation pms"
    exit 1
fi

echo "🔍 Validating configuration for service: $SERVICE in namespace: $NAMESPACE"
echo "================================================================"

# Check if pod exists
echo ""
echo "1. Checking pod status..."
POD=$(kubectl get pod -n $NAMESPACE -l app=$SERVICE -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -z "$POD" ]; then
    echo "❌ No pod found for service: $SERVICE"
    exit 1
fi

POD_STATUS=$(kubectl get pod -n $NAMESPACE $POD -o jsonpath='{.status.phase}')
echo "✅ Pod: $POD"
echo "   Status: $POD_STATUS"

# Check required environment variables
echo ""
echo "2. Checking required environment variables..."
REQUIRED_VARS=(
    "SPRING_RABBITMQ_USERNAME"
    "SPRING_RABBITMQ_PASSWORD"
    "SPRING_DATASOURCE_URL"
    "DB_HOST"
    "RABBITMQ_HOST"
)

MISSING_VARS=()
for var in "${REQUIRED_VARS[@]}"; do
    VALUE=$(kubectl exec -n $NAMESPACE $POD -- env 2>/dev/null | grep "^$var=" || echo "")
    if [ -z "$VALUE" ]; then
        MISSING_VARS+=("$var")
        echo "❌ Missing: $var"
    else
        echo "✅ Found: $var"
    fi
done

# Check for deprecated variables
echo ""
echo "3. Checking for deprecated environment variables..."
DEPRECATED_VARS=(
    "APP_RABBIT_STREAM_USERNAME"
    "APP_RABBIT_STREAM_PASSWORD"
)

FOUND_DEPRECATED=()
for var in "${DEPRECATED_VARS[@]}"; do
    VALUE=$(kubectl exec -n $NAMESPACE $POD -- env 2>/dev/null | grep "^$var=" || echo "")
    if [ -n "$VALUE" ]; then
        FOUND_DEPRECATED+=("$var")
        echo "⚠️  Deprecated: $var (should be removed)"
    fi
done

# Check secrets
echo ""
echo "4. Checking secrets..."
SECRET_NAME="${SERVICE}-secrets"
SECRET_EXISTS=$(kubectl get secret -n $NAMESPACE $SECRET_NAME 2>/dev/null || echo "")
if [ -z "$SECRET_EXISTS" ]; then
    echo "❌ Secret not found: $SECRET_NAME"
else
    echo "✅ Secret exists: $SECRET_NAME"
    SECRET_KEYS=$(kubectl get secret -n $NAMESPACE $SECRET_NAME -o jsonpath='{.data}' | jq -r 'keys[]' 2>/dev/null)
    echo "   Keys: $(echo $SECRET_KEYS | tr '\n' ', ')"
fi

# Check configmap
echo ""
echo "5. Checking configmap..."
CONFIGMAP_NAME="${SERVICE}-config"
CONFIGMAP_EXISTS=$(kubectl get configmap -n $NAMESPACE $CONFIGMAP_NAME 2>/dev/null || echo "")
if [ -z "$CONFIGMAP_EXISTS" ]; then
    echo "❌ ConfigMap not found: $CONFIGMAP_NAME"
else
    echo "✅ ConfigMap exists: $CONFIGMAP_NAME"
    CONFIG_KEYS=$(kubectl get configmap -n $NAMESPACE $CONFIGMAP_NAME -o jsonpath='{.data}' | jq -r 'keys[]' 2>/dev/null)
    echo "   Keys: $(echo $CONFIG_KEYS | tr '\n' ', ')"
fi

# Check logs for errors
echo ""
echo "6. Checking recent logs for errors..."
ERROR_COUNT=$(kubectl logs -n $NAMESPACE $POD --tail=100 2>/dev/null | grep -i "error\|exception\|failed" | wc -l || echo "0")
if [ "$ERROR_COUNT" -gt 0 ]; then
    echo "⚠️  Found $ERROR_COUNT error lines in logs"
    echo "   Recent errors:"
    kubectl logs -n $NAMESPACE $POD --tail=100 2>/dev/null | grep -i "error\|exception\|failed" | head -5
else
    echo "✅ No errors found in recent logs"
fi

# Check if service started successfully
echo ""
echo "7. Checking startup status..."
STARTED=$(kubectl logs -n $NAMESPACE $POD 2>/dev/null | grep -i "started.*application\|tomcat started" || echo "")
if [ -n "$STARTED" ]; then
    echo "✅ Application started successfully"
    echo "   $STARTED"
else
    echo "❌ Application may not have started"
fi

# Summary
echo ""
echo "================================================================"
echo "SUMMARY"
echo "================================================================"

if [ ${#MISSING_VARS[@]} -eq 0 ] && [ ${#FOUND_DEPRECATED[@]} -eq 0 ] && [ "$POD_STATUS" == "Running" ] && [ "$ERROR_COUNT" -eq 0 ]; then
    echo "✅ Configuration is valid!"
else
    echo "⚠️  Issues found:"
    if [ ${#MISSING_VARS[@]} -gt 0 ]; then
        echo "   - Missing variables: ${MISSING_VARS[*]}"
    fi
    if [ ${#FOUND_DEPRECATED[@]} -gt 0 ]; then
        echo "   - Deprecated variables: ${FOUND_DEPRECATED[*]}"
    fi
    if [ "$POD_STATUS" != "Running" ]; then
        echo "   - Pod not running: $POD_STATUS"
    fi
    if [ "$ERROR_COUNT" -gt 0 ]; then
        echo "   - Errors in logs: $ERROR_COUNT"
    fi
    echo ""
    echo "Please review and fix the issues above."
    exit 1
fi
