# Secrets Management

## Overview
This directory contains secret management configuration for the PMS system.

**IMPORTANT:** Never commit actual secrets to version control.

## Structure

```
secrets/
├── README.md           # This file
└── examples/
    └── secrets.env.example  # Example secrets file (safe to commit)
```

## Local Development Setup

1. **Copy the example file:**
   ```bash
   cp secrets/examples/secrets.env.example k8s/overlays/local/secrets.env
   ```

2. **Edit with your values:**
   ```bash
   vi k8s/overlays/local/secrets.env
   ```

3. **Ensure it's gitignored:**
   The `.gitignore` file already excludes `**/secrets.env` from version control.

## Secret Categories

### PostgreSQL
- `POSTGRES_USER` - Database username
- `POSTGRES_PASSWORD` - Database password  
- `POSTGRES_DB` - Database name

### RabbitMQ
- `RABBITMQ_DEFAULT_USER` - RabbitMQ username
- `RABBITMQ_DEFAULT_PASS` - RabbitMQ password

### Kafka
- `KAFKA_CLUSTER_ID` - Unique cluster identifier for KRaft mode

## Production Secrets

For production environments, use one of:

1. **External Secrets Operator** (recommended)
   - Integrate with AWS Secrets Manager / Azure Key Vault
   - Auto-sync secrets to Kubernetes

2. **Sealed Secrets**
   - Encrypt secrets for safe git storage
   - Decrypt automatically in cluster

3. **Manual kubectl**
   - Create secrets directly in cluster
   - Never store in git

## Troubleshooting

**Error: "secret not found"**
- Ensure you've created `k8s/overlays/<env>/secrets.env`
- Run `kubectl kustomize k8s/overlays/<env>` to verify secret generation

**Secret not updating**
- Delete and recreate: `kubectl delete secret <name> -n pms`
- Re-apply overlay: `kubectl apply -k k8s/overlays/<env>`
