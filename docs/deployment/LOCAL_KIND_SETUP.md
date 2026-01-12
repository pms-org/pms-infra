# Local Kind Cluster Setup Guide

Complete guide for running the PMS infrastructure on a local Kind (Kubernetes in Docker) cluster.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Setup](#detailed-setup)
- [Secret Creation](#secret-creation)
- [Known Issues and Fixes](#known-issues-and-fixes)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools
```bash
# Docker Desktop or Docker Engine
docker --version  # Should be 20.10+

# Kind (Kubernetes in Docker)
kind --version    # Should be v0.20.0+

# kubectl
kubectl version --client  # Should be v1.28+

# Helm
helm version      # Should be v3.12+
```

### Installation (if needed)
```bash
# Install Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

---

## Quick Start

### 1. Create Kind Cluster
```bash
# Create cluster with custom config (enables port forwarding)
kind create cluster --name pms --config kind-config.yaml

# Verify cluster is running
kubectl cluster-info --context kind-pms
kubectl get nodes --context kind-pms
```

### 2. Create Namespace
```bash
kubectl create namespace pms --context kind-pms
```

### 3. Run Secret Setup Script
```bash
# Make the script executable
chmod +x scripts/create-local-secrets.sh

# Create all required secrets
./scripts/create-local-secrets.sh
```

### 4. Deploy Infrastructure
```bash
# Deploy in order (dependencies matter!)
helm install postgres k8s/charts/infra/postgres -n pms --kube-context kind-pms
helm install kafka k8s/charts/infra/kafka -n pms --kube-context kind-pms
helm install rabbitmq k8s/charts/infra/rabbitmq -n pms --kube-context kind-pms
helm install redis k8s/charts/infra/redis -n pms --kube-context kind-pms
helm install schema-registry k8s/charts/infra/schema-registry -n pms --kube-context kind-pms
```

### 5. Deploy Services
```bash
# Wait for infrastructure to be ready (check with kubectl get pods -n pms)
helm install simulation k8s/charts/services/simulation -n pms --kube-context kind-pms
helm install trade-capture k8s/charts/services/trade-capture -n pms --kube-context kind-pms
helm install validation-service k8s/charts/services/validation -n pms --kube-context kind-pms
```

---

## Detailed Setup

### Step 1: Kind Cluster Configuration

The `kind-config.yaml` enables port mapping for local access:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080
    hostPort: 8080
    protocol: TCP
```

Create cluster:
```bash
kind create cluster --name pms --config kind-config.yaml
```

### Step 2: Namespace Creation

```bash
kubectl create namespace pms --context kind-pms
```

---

## Secret Creation

### Why Manual Secrets are Needed

In local Kind clusters:
- **No AWS credentials** → External Secrets Operator (ESO) cannot fetch from AWS Secrets Manager
- **Bypass ESO** → Create Kubernetes secrets manually with mock/local values
- **Match production structure** → Use same secret keys as production for compatibility

### Automated Secret Setup Script

Create `scripts/create-local-secrets.sh`:

```bash
#!/bin/bash

# Local Kind Cluster - Secret Creation Script
# This script creates all required Kubernetes secrets for local development
# Bypasses AWS Secrets Manager dependency for local testing

set -e

NAMESPACE="pms"
CONTEXT="kind-pms"

echo "🔐 Creating secrets in namespace: $NAMESPACE"
echo "📦 Using context: $CONTEXT"
echo ""

# Function to create or replace secret
create_secret() {
    local name=$1
    shift
    
    # Delete if exists
    kubectl delete secret "$name" -n "$NAMESPACE" --context "$CONTEXT" 2>/dev/null || true
    
    # Create new secret
    kubectl create secret generic "$name" -n "$NAMESPACE" --context "$CONTEXT" "$@"
    
    echo "✅ Created secret: $name"
}

# ============================================
# Infrastructure Secrets
# ============================================

echo "📊 Creating infrastructure secrets..."

# PostgreSQL Secrets
create_secret "postgres-secrets" \
    --from-literal=POSTGRES_USER=pms_user \
    --from-literal=POSTGRES_PASSWORD=pms_local_password \
    --from-literal=POSTGRES_DB=pms_db \
    --from-literal=POSTGRES_HOST=postgres \
    --from-literal=POSTGRES_PORT=5432

# Kafka Secrets
create_secret "kafka-secrets" \
    --from-literal=KAFKA_PASSWORD=kafka_local_password

# RabbitMQ Secrets
create_secret "rabbitmq-secrets" \
    --from-literal=RABBITMQ_DEFAULT_USER=pms_user \
    --from-literal=RABBITMQ_DEFAULT_PASS=rabbitmq_local_password

# Redis Secrets
create_secret "redis-secrets" \
    --from-literal=REDIS_PASSWORD=redis_local_password

# Schema Registry Secrets
create_secret "schema-registry-secrets" \
    --from-literal=SCHEMA_REGISTRY_PASSWORD=schema_registry_local_password

echo ""

# ============================================
# Service Secrets
# ============================================

echo "🚀 Creating service secrets..."

# Simulation Service Secrets
create_secret "simulation-secrets" \
    --from-literal=SPRING_DATASOURCE_URL=jdbc:postgresql://postgres:5432/pms_db \
    --from-literal=SPRING_DATASOURCE_USERNAME=pms_user \
    --from-literal=SPRING_DATASOURCE_PASSWORD=pms_local_password \
    --from-literal=SPRING_RABBITMQ_HOST=rabbitmq \
    --from-literal=SPRING_RABBITMQ_PORT=5672 \
    --from-literal=SPRING_RABBITMQ_USERNAME=pms_user \
    --from-literal=SPRING_RABBITMQ_PASSWORD=rabbitmq_local_password

# Trade-Capture Service Secrets
create_secret "trade-capture-secrets" \
    --from-literal=SPRING_DATASOURCE_URL=jdbc:postgresql://postgres:5432/pms_db \
    --from-literal=SPRING_DATASOURCE_USERNAME=pms_user \
    --from-literal=SPRING_DATASOURCE_PASSWORD=pms_local_password \
    --from-literal=SPRING_RABBITMQ_HOST=rabbitmq \
    --from-literal=SPRING_RABBITMQ_PORT=5672 \
    --from-literal=SPRING_RABBITMQ_USERNAME=pms_user \
    --from-literal=SPRING_RABBITMQ_PASSWORD=rabbitmq_local_password \
    --from-literal=SPRING_KAFKA_BOOTSTRAP_SERVERS=kafka:19092 \
    --from-literal=SCHEMA_REGISTRY_URL=http://schema-registry:8081

# Validation Service Secrets
create_secret "validation-service-secrets" \
    --from-literal=SPRING_DATASOURCE_URL=jdbc:postgresql://postgres:5432/pms_db \
    --from-literal=SPRING_DATASOURCE_USERNAME=pms_user \
    --from-literal=SPRING_DATASOURCE_PASSWORD=pms_local_password \
    --from-literal=SPRING_DATA_REDIS_HOST=redis \
    --from-literal=SPRING_DATA_REDIS_PORT=6379 \
    --from-literal=SPRING_DATA_REDIS_PASSWORD=redis_local_password \
    --from-literal=SPRING_KAFKA_BOOTSTRAP_SERVERS=kafka:19092 \
    --from-literal=SCHEMA_REGISTRY_URL=http://schema-registry:8081

echo ""
echo "✅ All secrets created successfully!"
echo ""
echo "📋 Verify secrets:"
echo "   kubectl get secrets -n $NAMESPACE --context $CONTEXT"
echo ""
echo "🔍 View secret contents (base64 encoded):"
echo "   kubectl get secret <secret-name> -n $NAMESPACE --context $CONTEXT -o yaml"
echo ""
