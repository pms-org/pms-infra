# AWS Secrets Manager Structure for PMS

## Overview

Secrets are organized hierarchically in AWS Secrets Manager with environment-specific paths.

## Structure

```
pms/
├── simulation/
│   ├── dev/
│   └── prod/
├── validation/
│   ├── dev/
│   └── prod/
├── trade-capture/
│   ├── dev/
│   └── prod/
├── kafka/
│   ├── dev/
│   └── prod/
├── postgres/
│   ├── dev/
│   └── prod/
└── rabbitmq/
    ├── dev/
    └── prod/
```

## Secret Format

Each secret is a JSON object containing service-specific secrets:

### Example: `pms/validation/dev`

```json
{
  "VALIDATION_API_KEY": "your-validation-api-key-here",
  "VALIDATION_DB_PASSWORD": "secure-db-password",
  "VALIDATION_JWT_SECRET": "your-jwt-secret"
}
```

### Example: `pms/trade-capture/dev`

```json
{
  "TRADE_CAPTURE_API_KEY": "trade-capture-api-key",
  "TRADE_CAPTURE_DB_PASSWORD": "secure-db-password",
  "TRADE_CAPTURE_RABBITMQ_PASSWORD": "rabbitmq-password",
  "TRADE_CAPTURE_KAFKA_PASSWORD": "kafka-password",
  "TRADE_CAPTURE_JWT_SECRET": "jwt-secret"
}
```

## Why This Structure?

1. **Environment Isolation**: `dev/` and `prod/` separate environments
2. **Service Ownership**: Each service has its own secret
3. **Least Privilege**: ESO can be restricted to specific paths
4. **Scalability**: Easy to add new services and environments
5. **Auditability**: Clear ownership and access patterns

## Creating Secrets via AWS CLI

```bash
# Create validation service secrets for dev
aws secretsmanager create-secret \
  --name pms/validation/dev \
  --description "Validation service secrets for dev environment" \
  --secret-string '{
    "VALIDATION_API_KEY": "dev-api-key-123",
    "VALIDATION_DB_PASSWORD": "dev-db-pass-456",
    "VALIDATION_JWT_SECRET": "dev-jwt-secret-789"
  }' \
  --region us-east-1

# Create trade-capture service secrets for dev
aws secretsmanager create-secret \
  --name pms/trade-capture/dev \
  --description "Trade capture service secrets for dev environment" \
  --secret-string '{
    "TRADE_CAPTURE_API_KEY": "dev-trade-api-key",
    "TRADE_CAPTURE_DB_PASSWORD": "dev-trade-db-pass",
    "TRADE_CAPTURE_RABBITMQ_PASSWORD": "dev-rabbitmq-pass",
    "TRADE_CAPTURE_KAFKA_PASSWORD": "dev-kafka-pass",
    "TRADE_CAPTURE_JWT_SECRET": "dev-trade-jwt-secret"
  }' \
  --region us-east-1
```

## IAM Policy for ESO

The ESO service account needs this IAM policy:

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
        "arn:aws:secretsmanager:us-east-1:YOUR_ACCOUNT_ID:secret:pms/*"
      ]
    }
  ]
}
```

This allows ESO to read all secrets under the `pms/` path.

## Migration from Local Secrets

When migrating from local `.env` files:

1. **Extract secrets** from `.env` files
2. **Create AWS Secrets Manager** entries with the structure above
3. **Update ExternalSecret** resources to reference AWS paths
4. **Remove local secretGenerator** from kustomizations
5. **Test** that applications can access secrets from AWS

## Security Considerations

1. **Encryption**: Secrets are encrypted at rest in AWS Secrets Manager
2. **Access Control**: IAM policies control who can access secrets
3. **Audit Logging**: CloudTrail logs all secret access
4. **Rotation**: AWS supports automatic secret rotation
5. **No Plaintext**: Secrets never appear in Kubernetes manifests