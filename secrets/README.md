# PMS Infrastructure - Secrets Management

## 🚨 CRITICAL: Database Configuration Safeguards

### Localhost Prevention
**NEVER use `localhost` as DB_HOST in Kubernetes deployments.**

This project includes multiple safeguards to prevent localhost misconfiguration:

#### ✅ Correct Configurations by Environment:

**Local Development (.env files):**
```bash
DB_HOST=localhost  # ✅ Valid for local Docker/PostgreSQL
```

**Kubernetes Dev Environment:**
```bash
DB_HOST=postgres   # ✅ Resolves to postgres.pms-dev.svc.cluster.local
SPRING_DATASOURCE_URL=jdbc:postgresql://postgres:5432/pmsdb
```

**Kubernetes Prod Environment:**
```bash
# Provided by External Secrets Operator from AWS Secrets Manager
DB_HOST=<rds-endpoint>  # ✅ AWS RDS endpoint
SPRING_DATASOURCE_URL=jdbc:postgresql://<rds-endpoint>:5432/pmsdb
```

#### ❌ FORBIDDEN in Kubernetes:
```bash
DB_HOST=localhost  # ❌ WILL CAUSE CONNECTION FAILURES
```

#### Validation Tools:
Run the validation script after deployments:
```bash
./scripts/validate-db-config.sh [namespace]
```

This script will:
- Check for `localhost` usage in Kubernetes
- Validate `SPRING_DATASOURCE_URL` format
- Ensure proper environment markers are set

---



This project uses a **dual approach** for secrets management:## Overview## Overview

- **Local Development**: `.env` files (NEVER committed to Git)

- **Kubernetes (Dev/Prod)**: External Secrets Operator with AWS Secrets ManagerThis directory contains secret management configuration for the PMS system.



**NO SECRETS ARE STORED IN GIT.**This directory contains secret management configuration for the PMS (Portfolio Management System) infrastructure. The system supports multiple secret management strategies depending on the deployment environment.



## Quick Start - Local Development**IMPORTANT:** Never commit actual secrets to version control.



1. Copy the example files:## 🔐 Secret Management Strategies

```bash

cp secrets/.env.example secrets/.env## Structure

cp secrets/simulation.env.example secrets/simulation.env

cp secrets/trade-capture.env.example secrets/trade-capture.env### 1. Local Development

cp secrets/validation.env.example secrets/validation.env

```**Method**: Environment files (gitignored)```



2. The example files contain working defaults for local development**Location**: `k8s/overlays-pms/local/secrets.env`secrets/

3. Modify only if you need custom values

4. These files are automatically ignored by Git**Security**: Suitable for local development only├── README.md           # This file



## File Structure└── examples/



```### 2. Development Environment    └── secrets.env.example  # Example secrets file (safe to commit)

secrets/

├── .env.example                    # Complete environment variables template**Method**: AWS Secrets Manager + External Secrets Operator```

├── simulation.env.example          # Simulation service specific

├── trade-capture.env.example       # Trade Capture service specific**Location**: AWS Secrets Manager secrets with `pms/dev/` prefix

├── validation.env.example          # Validation service specific

└── README.md                       # This file**Security**: Production-grade encryption and access controls## Local Development Setup



DO NOT COMMIT:1. **Copy the example file:**

├── .env                            # Your actual values   ```bash

├── simulation.env                  # Your actual values   cp secrets/examples/secrets.env.example k8s/overlays-pms/local/secrets.env

├── trade-capture.env               # Your actual values   ```

└── validation.env                  # Your actual values

```2. **Edit with working values:**

   ```bash

## Secrets Architecture   vi k8s/overlays-pms/local/secrets.env

   ```

### Local Development (Docker Compose)

- **Source**: `.env` files in `secrets/` directory   **IMPORTANT:** The example file shows both working defaults (as comments) and placeholders. For local development, replace the placeholders with the working defaults shown in the comments, or use your own values that match your local setup.

- **Usage**: Loaded via `env_file` in docker-compose.yml

- **Security**: Files are gitignored, use example files as templates   **Working defaults for local development:**

   - PostgreSQL: `POSTGRES_USER=pms`, `POSTGRES_PASSWORD=pms`, `POSTGRES_DB=pmsdb`

### Development Kubernetes (pms-dev namespace)   - RabbitMQ: `RABBITMQ_DEFAULT_USER=guest`, `RABBITMQ_DEFAULT_PASS=guest`

- **Source**: secretGenerator in `k8s/overlays/dev/kustomization.yaml`   - Kafka: `KAFKA_CLUSTER_ID=local_kafka_cluster_001` (any unique string)

- **Purpose**: Temporary inline secrets for development

- **Migration Path**: Will be replaced by External Secrets pointing to dev AWS account3. **Ensure it's gitignored:**

   The `.gitignore` file already excludes `**/secrets.env` from version control.

### Production Kubernetes (pms-prod namespace)

- **Source**: AWS Secrets Manager via External Secrets Operator

- **Secret Store**: `aws-secrets-manager` (ClusterSecretStore)

- **Namespace**: `pms-prod`## ⚙️ Configuration### PostgreSQL

- **Security**: IRSA (IAM Roles for Service Accounts) grants access

- `POSTGRES_USER` - Database username

## Kubernetes Secrets Structure

### Required Secrets- `POSTGRES_PASSWORD` - Database password  

Each service has its own Kubernetes Secret for clear ownership:

- `POSTGRES_DB` - Database name

### 1. postgres-credentials

Used by: PostgreSQL deployment (dev only, prod uses RDS)| Secret | Local Default | AWS Secrets Manager Key | Description |



**Environment Variables:**|--------|---------------|--------------------------|-------------|### RabbitMQ

```bash

POSTGRES_USER| `POSTGRES_USER` | `pms` | `pms/{env}/database:username` | PostgreSQL username |- `RABBITMQ_DEFAULT_USER` - RabbitMQ username

POSTGRES_PASSWORD

POSTGRES_DB| `POSTGRES_PASSWORD` | `pms` | `pms/{env}/database:password` | PostgreSQL password |- `RABBITMQ_DEFAULT_PASS` - RabbitMQ password

DB_HOST

SPRING_DATASOURCE_URL| `POSTGRES_DB` | `pmsdb` | `pms/{env}/database:dbname` | PostgreSQL database name |

SPRING_DATASOURCE_USERNAME

SPRING_DATASOURCE_PASSWORD| `RABBITMQ_DEFAULT_USER` | `guest` | `pms/{env}/rabbitmq:username` | RabbitMQ username |### Kafka

DATASOURCE_USER

DATASOURCE_PASS| `RABBITMQ_DEFAULT_PASS` | `guest` | `pms/{env}/rabbitmq:password` | RabbitMQ password |- `KAFKA_CLUSTER_ID` - Unique cluster identifier for KRaft mode

```

| `KAFKA_CLUSTER_ID` | `unique_id` | `pms/{env}/kafka:cluster_id` | Kafka cluster identifier |

### 2. rabbitmq-credentials

Used by: RabbitMQ deployment## Production Secrets



**Environment Variables:**### Local Development Setup

```bash

RABBITMQ_DEFAULT_USERFor production environments, use one of:

RABBITMQ_DEFAULT_PASS

SPRING_RABBITMQ_USERNAME1. **Copy the example file:**

SPRING_RABBITMQ_PASSWORD

```   ```bash1. **External Secrets Operator** (recommended)



### 3. simulation-secrets   cp secrets/examples/secrets.env.example k8s/overlays-pms/local/secrets.env   - Integrate with AWS Secrets Manager / Azure Key Vault

Used by: Simulation service

   ```   - Auto-sync secrets to Kubernetes

**Environment Variables:**

```bash

SPRING_DATASOURCE_USERNAME

SPRING_DATASOURCE_PASSWORD2. **Edit with your local values:**2. **Sealed Secrets**

```

   ```bash   - Encrypt secrets for safe git storage

### 4. trade-capture-secrets

Used by: Trade Capture service   # k8s/overlays-pms/local/secrets.env   - Decrypt automatically in cluster



**Environment Variables:**   POSTGRES_USER=pms

```bash

SPRING_DATASOURCE_USERNAME   POSTGRES_PASSWORD=your_secure_local_password3. **Manual kubectl**

SPRING_DATASOURCE_PASSWORD

SPRING_RABBITMQ_USERNAME   POSTGRES_DB=pmsdb   - Create secrets directly in cluster

SPRING_RABBITMQ_PASSWORD

```   RABBITMQ_DEFAULT_USER=guest   - Never store in git



### 5. validation-secrets   RABBITMQ_DEFAULT_PASS=guest

Used by: Validation service

   KAFKA_CLUSTER_ID=local_kafka_cluster_001## Troubleshooting

**Environment Variables:**

```bash   ```

DATASOURCE_USER

DATASOURCE_PASS**Error: "secret not found"**

```

3. **Ensure file is gitignored:**- Ensure you've created `k8s/overlays-pms/<env>/secrets.env`

## AWS Secrets Manager Setup (Production)

   ```bash- Run `kubectl kustomize k8s/overlays-pms/<env>` to verify secret generation

### Required Secrets Paths

   echo "k8s/overlays-pms/*/secrets.env" >> .gitignore

Create these secrets in AWS Secrets Manager for production:

   ```**Secret not updating**

```

pms/prod/postgres          # RDS credentials- Delete and recreate: `kubectl delete secret <name> -n pms`

pms/prod/rabbitmq          # RabbitMQ credentials

pms/prod/simulation        # Simulation service credentials### AWS Secrets Manager Setup- Re-apply overlay: `kubectl apply -k k8s/overlays-pms/<env>`

pms/prod/trade-capture     # Trade Capture service credentials

pms/prod/validation        # Validation service credentials

```#### 1. Create Secrets in AWS



### Example: Creating Production RDS Secret

```bash
aws secretsmanager create-secret \
  --name pms/database/prod \
  --description "RDS PostgreSQL credentials for PMS production" \
  --secret-string '{
    "username": "<YOUR_DB_USERNAME>",
    "password": "<YOUR_DB_PASSWORD>",
    "host": "<YOUR_RDS_ENDPOINT>",
    "port": "5432",
    "dbname": "<YOUR_DB_NAME>",
    "engine": "postgres"
  }'
```

### Production Secrets Setup Script

Create a setup script for production secrets:

```bash
#!/bin/bash
# setup-production-secrets.sh

# Set AWS region
export AWS_REGION=<YOUR_AWS_REGION>

# Create production database secret
aws secretsmanager create-secret \
  --name pms/database/prod \
  --description "RDS PostgreSQL credentials for PMS production" \
  --secret-string '{
    "username": "<YOUR_DB_USERNAME>",
    "password": "<YOUR_DB_PASSWORD>",
    "host": "<YOUR_RDS_ENDPOINT>",
    "port": "5432",
    "dbname": "<YOUR_DB_NAME>",
    "engine": "postgres"
  }'

echo "Production database secret created successfully!"
echo "Note: RabbitMQ credentials need to be configured separately."
```

```

### Example: Creating RabbitMQ Secret*Secret Name:* `pms/dev/rabbitmq`



```bash**Development Kafka Secret:**

aws secretsmanager create-secret \```json

  --name pms/prod/rabbitmq \{

  --description "RabbitMQ credentials for PMS production" \  "cluster_id": "dev_kafka_cluster_001"

  --secret-string '{}

    "RABBITMQ_DEFAULT_USER": "admin",```

    "RABBITMQ_DEFAULT_PASS": "<generated-strong-password>",*Secret Name:* `pms/dev/kafka`

    "SPRING_RABBITMQ_USERNAME": "admin",

    "SPRING_RABBITMQ_PASSWORD": "<generated-strong-password>"#### 2. Configure External Secrets Operator

  }'

```The ESO configuration is defined in:

- `k8s/base/aws-addons/secret-store.yaml` - SecretStore configuration

## How Applications Consume Secrets- `k8s/overlays-pms/dev/external-secret-rds.yaml` - RDS secret mapping

- `k8s/overlays-pms/prod/external-secret-trade-capture.yaml` - Application secrets

All applications use the same pattern - secrets are injected via `envFrom`:

#### 3. IAM Permissions

```yaml

containers:Ensure the Kubernetes service account has permissions to access AWS Secrets Manager:

  - name: trade-capture

    image: niishantdev/pms-trade-capture```json

    envFrom:{

    - configMapRef:  "Version": "2012-10-17",

        name: app-config              # Non-sensitive config  "Statement": [

    - secretRef:    {

        name: trade-capture-secrets   # Sensitive credentials      "Effect": "Allow",

```      "Action": [

        "secretsmanager:GetSecretValue",

Applications **DO NOT KNOW** where secrets come from:        "secretsmanager:DescribeSecret"

- Local: `.env` files      ],

- Dev K8s: secretGenerator      "Resource": [

- Prod K8s: External Secrets → AWS Secrets Manager        "arn:aws:secretsmanager:region:account:secret:pms/dev/*",

        "arn:aws:secretsmanager:region:account:secret:pms/prod/*"

## External Secrets Operator Flow      ]

    }

```  ]

AWS Secrets Manager (Source of Truth)}

         ↓```

    [IRSA Authentication]

         ↓## 🔍 Verification

External Secrets Operator (ESO)

         ↓### Check Local Secrets

  Kubernetes Secret (synced every 1h)

         ↓```bash

   Pod Environment Variables# Verify secrets file exists

         ↓ls -la k8s/overlays-pms/local/secrets.env

    Application Code

```# Test kustomize build

kubectl kustomize k8s/overlays-pms/local | grep -A 5 secretGenerator

## Security Best Practices```



1. ✅ **Never commit secrets to Git** - `.env` files are gitignored### Check AWS Secrets

2. ✅ **Use strong passwords** - Generate with `openssl rand -base64 32`

3. ✅ **Rotate regularly** - AWS Secrets Manager supports automatic rotation```bash

4. ✅ **Principle of least privilege** - Each service gets only what it needs# List secrets

5. ✅ **Audit access** - Monitor CloudTrail for secret accessaws secretsmanager list-secrets --filters Key=name,Values=pms/dev/

6. ✅ **Encrypt at rest** - AWS Secrets Manager uses KMS encryption

7. ✅ **Use IRSA** - No static credentials in pods# Get specific secret

aws secretsmanager get-secret-value --secret-id pms/dev/database

## Troubleshooting```



### Local Development### Check External Secrets Operator



**Problem**: Service can't connect to database```bash

```bash# Check ESO status

# Check if .env file existskubectl get externalsecret -n pms

ls -la secrets/.env

# Check generated Kubernetes secrets

# Verify environment variables are loadedkubectl get secrets -n pms

docker-compose config

```# View ESO logs

kubectl logs -f deployment/external-secrets-webhook -n external-secrets-system

### Kubernetes Development```



**Problem**: Pod fails with missing environment variables## 🚨 Security Best Practices

```bash

# Check if secret exists### ✅ Do's

kubectl get secret trade-capture-secrets -n pms-dev- Use strong, unique passwords for each environment

- Rotate secrets regularly

# View secret keys (not values)- Use AWS Secrets Manager for cloud deployments

kubectl describe secret trade-capture-secrets -n pms-dev- Audit secret access logs

- Limit secret scope to minimum required access

# Check pod environment

kubectl exec -n pms-dev deploy/trade-capture -- env | grep DATASOURCE### ❌ Don'ts

```- Never commit actual secrets to Git

- Don't use default passwords in production

### Kubernetes Production- Don't share secrets between environments

- Don't hardcode secrets in application code

**Problem**: ExternalSecret not syncing- Don't log sensitive information

```bash

# Check ExternalSecret status## 🔧 Troubleshooting

kubectl get externalsecret -n pms-prod

kubectl describe externalsecret trade-capture-secrets -n pms-prod### Common Issues



# Check if Kubernetes Secret was created**"Secret not found" error:**

kubectl get secret trade-capture-secrets -n pms-prod```bash

# Check if secret exists in AWS

# Check ESO logsaws secretsmanager describe-secret --secret-id pms/dev/database

kubectl logs -n external-secrets-system deployment/external-secrets

# Check ESO external secret status

# Verify IRSA permissionskubectl describe externalsecret rds-postgres-credentials -n pms

kubectl get sa -n external-secrets-system```

kubectl describe sa external-secrets -n external-secrets-system

```**"Access denied" error:**

```bash

**Problem**: Pod has secret but wrong values# Verify IAM permissions

```bashaws sts get-caller-identity

# Force ESO to refresh (delete and let it recreate)

kubectl delete externalsecret trade-capture-secrets -n pms-prod# Check IRSA configuration

kubectl get serviceaccount -n pms

# Verify secret content matches AWSkubectl describe serviceaccount <service-account> -n pms

aws secretsmanager get-secret-value --secret-id pms/prod/trade-capture```

```

**Local secrets not loading:**

## Migration Checklist```bash

# Verify file exists and has correct permissions

### Local Development Setupls -la k8s/overlays-pms/local/secrets.env

- [ ] Copy all `.env.example` files to `.env`

- [ ] Verify `.env` files are gitignored# Test kustomize build

- [ ] Test docker-compose with `.env` fileskubectl kustomize k8s/overlays-pms/local

```

### Kubernetes Development Setup

- [ ] Deploy with secretGenerator (temporary)## 📚 Additional Resources

- [ ] Verify all pods start successfully

- [ ] Plan migration to External Secrets- [AWS Secrets Manager Documentation](https://docs.aws.amazon.com/secretsmanager/)

- [External Secrets Operator](https://external-secrets.io/)

### Kubernetes Production Setup- [Kubernetes Secrets Best Practices](https://kubernetes.io/docs/concepts/configuration/secret/)

- [ ] Create all secrets in AWS Secrets Manager- [IRSA Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)

- [ ] Deploy External Secrets Operator

- [ ] Configure ClusterSecretStore with IRSA---

- [ ] Deploy ExternalSecret resources

- [ ] Verify Kubernetes Secrets are created**Last Updated**: January 5, 2026
- [ ] Deploy applications
- [ ] Verify applications can connect to services
- [ ] Remove any temporary secretGenerator configurations
- [ ] Document secret rotation procedures

## Adding a New Service

When adding a new service that needs secrets:

1. **Create `.env.example` file** in `secrets/`
2. **Update dev overlay** `k8s/overlays/dev/kustomization.yaml`:
   - Add secretGenerator entry
3. **Create ExternalSecret** in `k8s/overlays/prod/external-secrets.yaml`
4. **Create AWS Secret** in Secrets Manager path `pms/prod/<service-name>`
5. **Update deployment** to use `envFrom` with the new secret name

Example:
```yaml
# In service deployment
envFrom:
- configMapRef:
    name: app-config
- secretRef:
    name: new-service-secrets  # Your new secret
```
