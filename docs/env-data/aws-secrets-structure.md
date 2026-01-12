# AWS Secrets Manager Structure

## Overview

This document defines the hierarchical structure for AWS Secrets Manager secrets used by the PMS (Portfolio Management System) application. Secrets are organized by service and environment to provide clear separation and access control.

## Structure

```
pms/
├── validation/
│   ├── dev/
│   └── prod/
├── simulation/
│   ├── dev/
│   └── prod/
├── trade-capture/
│   ├── dev/
│   └── prod/
└── kafka/
    ├── dev/
    └── prod/
```

## Secret Format

Each secret is stored as a JSON object in AWS Secrets Manager. The JSON keys correspond to environment variable names used by the applications.

### Example Secret JSON

For `pms/validation/dev`:

```json
{
  "VALIDATION_API_KEY": "your-api-key-here",
  "VALIDATION_DB_PASSWORD": "your-db-password-here",
  "VALIDATION_JWT_SECRET": "your-jwt-secret-here"
}
```

For `pms/kafka/dev`:

```json
{
  "KAFKA_ADMIN_PASSWORD": "admin-password",
  "KAFKA_USER_PASSWORD": "user-password"
}
```

## Service-Specific Secrets

### Validation Service
- **Secret Path**: `pms/validation/{env}`
- **Keys**:
  - `VALIDATION_API_KEY`: API key for external integrations
  - `VALIDATION_DB_PASSWORD`: Database password
  - `VALIDATION_JWT_SECRET`: JWT signing secret

### Simulation Service
- **Secret Path**: `pms/simulation/{env}`
- **Keys**:
  - `SIMULATION_DB_PASSWORD`: Database password
  - `SIMULATION_API_KEY`: API key for external integrations
  - `SIMULATION_JWT_SECRET`: JWT signing secret

### Trade Capture Service
- **Secret Path**: `pms/trade-capture/{env}`
- **Keys**:
  - `TRADE_CAPTURE_DB_PASSWORD`: Database password
  - `TRADE_CAPTURE_API_KEY`: API key for external integrations
  - `TRADE_CAPTURE_JWT_SECRET`: JWT signing secret

### Kafka Infrastructure
- **Secret Path**: `pms/kafka/{env}`
- **Keys**:
  - `KAFKA_ADMIN_PASSWORD`: Admin user password
  - `KAFKA_USER_PASSWORD`: Application user password

## Environment Variables

- `{env}` = `dev` | `prod`

## IAM Permissions

The External Secrets Operator service account requires the following IAM permissions:

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
      "Resource": "arn:aws:secretsmanager:*:*:secret:pms/*"
    }
  ]
}
```

## Security Notes

- Secrets are encrypted at rest using AWS KMS
- Access is controlled via IAM roles (IRSA)
- Secrets are automatically rotated by ESO every 1 hour
- No plaintext secrets are stored in Git repositories</content>
<parameter name="filePath">/mnt/c/Developer/pms-new/pms-infra/docs/aws-secrets-structure.md