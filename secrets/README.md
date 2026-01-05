# Secrets Management Guide# Secrets Management



## Overview## Overview

This directory contains secret management configuration for the PMS system.

This directory contains secret management configuration for the PMS (Portfolio Management System) infrastructure. The system supports multiple secret management strategies depending on the deployment environment.

**IMPORTANT:** Never commit actual secrets to version control.

## 🔐 Secret Management Strategies

## Structure

### 1. Local Development

**Method**: Environment files (gitignored)```

**Location**: `k8s/overlays-pms/local/secrets.env`secrets/

**Security**: Suitable for local development only├── README.md           # This file

└── examples/

### 2. Development Environment    └── secrets.env.example  # Example secrets file (safe to commit)

**Method**: AWS Secrets Manager + External Secrets Operator```

**Location**: AWS Secrets Manager secrets with `pms/dev/` prefix

**Security**: Production-grade encryption and access controls## Local Development Setup

1. **Copy the example file:**
   ```bash
   cp secrets/examples/secrets.env.example k8s/overlays-pms/local/secrets.env
   ```

2. **Edit with working values:**
   ```bash
   vi k8s/overlays-pms/local/secrets.env
   ```

   **IMPORTANT:** The example file shows both working defaults (as comments) and placeholders. For local development, replace the placeholders with the working defaults shown in the comments, or use your own values that match your local setup.

   **Working defaults for local development:**
   - PostgreSQL: `POSTGRES_USER=pms`, `POSTGRES_PASSWORD=pms`, `POSTGRES_DB=pmsdb`
   - RabbitMQ: `RABBITMQ_DEFAULT_USER=guest`, `RABBITMQ_DEFAULT_PASS=guest`
   - Kafka: `KAFKA_CLUSTER_ID=local_kafka_cluster_001` (any unique string)

3. **Ensure it's gitignored:**
   The `.gitignore` file already excludes `**/secrets.env` from version control.



## ⚙️ Configuration### PostgreSQL

- `POSTGRES_USER` - Database username

### Required Secrets- `POSTGRES_PASSWORD` - Database password  

- `POSTGRES_DB` - Database name

| Secret | Local Default | AWS Secrets Manager Key | Description |

|--------|---------------|--------------------------|-------------|### RabbitMQ

| `POSTGRES_USER` | `pms` | `pms/{env}/database:username` | PostgreSQL username |- `RABBITMQ_DEFAULT_USER` - RabbitMQ username

| `POSTGRES_PASSWORD` | `pms` | `pms/{env}/database:password` | PostgreSQL password |- `RABBITMQ_DEFAULT_PASS` - RabbitMQ password

| `POSTGRES_DB` | `pmsdb` | `pms/{env}/database:dbname` | PostgreSQL database name |

| `RABBITMQ_DEFAULT_USER` | `guest` | `pms/{env}/rabbitmq:username` | RabbitMQ username |### Kafka

| `RABBITMQ_DEFAULT_PASS` | `guest` | `pms/{env}/rabbitmq:password` | RabbitMQ password |- `KAFKA_CLUSTER_ID` - Unique cluster identifier for KRaft mode

| `KAFKA_CLUSTER_ID` | `unique_id` | `pms/{env}/kafka:cluster_id` | Kafka cluster identifier |

## Production Secrets

### Local Development Setup

For production environments, use one of:

1. **Copy the example file:**

   ```bash1. **External Secrets Operator** (recommended)

   cp secrets/examples/secrets.env.example k8s/overlays-pms/local/secrets.env   - Integrate with AWS Secrets Manager / Azure Key Vault

   ```   - Auto-sync secrets to Kubernetes



2. **Edit with your local values:**2. **Sealed Secrets**

   ```bash   - Encrypt secrets for safe git storage

   # k8s/overlays-pms/local/secrets.env   - Decrypt automatically in cluster

   POSTGRES_USER=pms

   POSTGRES_PASSWORD=your_secure_local_password3. **Manual kubectl**

   POSTGRES_DB=pmsdb   - Create secrets directly in cluster

   RABBITMQ_DEFAULT_USER=guest   - Never store in git

   RABBITMQ_DEFAULT_PASS=guest

   KAFKA_CLUSTER_ID=local_kafka_cluster_001## Troubleshooting

   ```

**Error: "secret not found"**

3. **Ensure file is gitignored:**- Ensure you've created `k8s/overlays-pms/<env>/secrets.env`

   ```bash- Run `kubectl kustomize k8s/overlays-pms/<env>` to verify secret generation

   echo "k8s/overlays-pms/*/secrets.env" >> .gitignore

   ```**Secret not updating**

- Delete and recreate: `kubectl delete secret <name> -n pms`

### AWS Secrets Manager Setup- Re-apply overlay: `kubectl apply -k k8s/overlays-pms/<env>`


#### 1. Create Secrets in AWS

**Development Database Secret:**
```json
{
  "username": "pms_user",
  "password": "your_secure_dev_password",
  "host": "rds-instance.dev.region.rds.amazonaws.com",
  "port": "5432",
  "dbname": "pmsdb"
}
```
*Secret Name:* `pms/dev/database`

**Development RabbitMQ Secret:**
```json
{
  "username": "pms_user",
  "password": "your_secure_dev_rabbitmq_password"
}
```
*Secret Name:* `pms/dev/rabbitmq`

**Development Kafka Secret:**
```json
{
  "cluster_id": "dev_kafka_cluster_001"
}
```
*Secret Name:* `pms/dev/kafka`

#### 2. Configure External Secrets Operator

The ESO configuration is defined in:
- `k8s/base/aws-addons/secret-store.yaml` - SecretStore configuration
- `k8s/overlays-pms/dev/external-secret-rds.yaml` - RDS secret mapping
- `k8s/overlays-pms/prod/external-secret-trade-capture.yaml` - Application secrets

#### 3. IAM Permissions

Ensure the Kubernetes service account has permissions to access AWS Secrets Manager:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": [
        "arn:aws:secretsmanager:region:account:secret:pms/dev/*",
        "arn:aws:secretsmanager:region:account:secret:pms/prod/*"
      ]
    }
  ]
}
```

## 🔍 Verification

### Check Local Secrets

```bash
# Verify secrets file exists
ls -la k8s/overlays-pms/local/secrets.env

# Test kustomize build
kubectl kustomize k8s/overlays-pms/local | grep -A 5 secretGenerator
```

### Check AWS Secrets

```bash
# List secrets
aws secretsmanager list-secrets --filters Key=name,Values=pms/dev/

# Get specific secret
aws secretsmanager get-secret-value --secret-id pms/dev/database
```

### Check External Secrets Operator

```bash
# Check ESO status
kubectl get externalsecret -n pms

# Check generated Kubernetes secrets
kubectl get secrets -n pms

# View ESO logs
kubectl logs -f deployment/external-secrets-webhook -n external-secrets-system
```

## 🚨 Security Best Practices

### ✅ Do's
- Use strong, unique passwords for each environment
- Rotate secrets regularly
- Use AWS Secrets Manager for cloud deployments
- Audit secret access logs
- Limit secret scope to minimum required access

### ❌ Don'ts
- Never commit actual secrets to Git
- Don't use default passwords in production
- Don't share secrets between environments
- Don't hardcode secrets in application code
- Don't log sensitive information

## 🔧 Troubleshooting

### Common Issues

**"Secret not found" error:**
```bash
# Check if secret exists in AWS
aws secretsmanager describe-secret --secret-id pms/dev/database

# Check ESO external secret status
kubectl describe externalsecret rds-postgres-credentials -n pms
```

**"Access denied" error:**
```bash
# Verify IAM permissions
aws sts get-caller-identity

# Check IRSA configuration
kubectl get serviceaccount -n pms
kubectl describe serviceaccount <service-account> -n pms
```

**Local secrets not loading:**
```bash
# Verify file exists and has correct permissions
ls -la k8s/overlays-pms/local/secrets.env

# Test kustomize build
kubectl kustomize k8s/overlays-pms/local
```

## 📚 Additional Resources

- [AWS Secrets Manager Documentation](https://docs.aws.amazon.com/secretsmanager/)
- [External Secrets Operator](https://external-secrets.io/)
- [Kubernetes Secrets Best Practices](https://kubernetes.io/docs/concepts/configuration/secret/)
- [IRSA Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)

---

**Last Updated**: January 5, 2026