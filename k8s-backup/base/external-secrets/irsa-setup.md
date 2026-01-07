# External Secrets Operator IRSA Setup

## IAM Policy for ESO (Least Privilege)

Create this IAM policy in AWS and attach it to the ESO service account via IRSA:

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

## Service Account with IRSA Annotation

The service account is annotated with the IAM role ARN that ESO will assume:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-secrets-sa
  namespace: external-secrets-system
  annotations:
    # Replace with your actual IAM role ARN
    eks.amazonaws.com/role-arn: arn:aws:iam::YOUR_ACCOUNT_ID:role/pms-external-secrets-role
```

## How IRSA Works

1. **EKS Pod Identity Webhook** injects the IAM role ARN into the service account
2. **ESO Controller** uses JWT tokens from the pod's service account
3. **AWS STS** exchanges the JWT for temporary AWS credentials
4. **ESO** uses these credentials to access Secrets Manager

## Trust Policy for IAM Role

The IAM role must trust the EKS service account:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/oidc.eks.REGION.amazonaws.com/id/OIDC_PROVIDER_ID"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.REGION.amazonaws.com/id/OIDC_PROVIDER_ID:sub": "system:serviceaccount:external-secrets-system:external-secrets-sa"
        }
      }
    }
  ]
}
```

## ClusterSecretStore

Once ESO is installed and IRSA is configured, create the ClusterSecretStore:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
            namespace: external-secrets-system
```

This store can be referenced by ExternalSecret resources in any namespace.