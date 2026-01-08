# Terraform Infrastructure

This directory contains the modular Terraform configuration for the PMS infrastructure, organized following infrastructure-as-code best practices.

## Structure

```
terraform/
├── modules/                    # Reusable Terraform modules
│   ├── vpc/                   # VPC and networking module
│   ├── eks/                   # EKS cluster module
│   ├── rds/                   # RDS database module
│   └── irsa/                  # IAM roles for service accounts module
└── environments/              # Environment-specific configurations
    ├── dev/                   # Development environment
    └── prod/                  # Production environment
```

## Usage

### Development Environment

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

### Production Environment

```bash
cd terraform/environments/prod
terraform init
terraform plan
terraform apply
```

## Modules

### VPC Module
- Creates VPC with public, private, and database subnets
- Configures NAT gateways and internet gateways
- Sets up subnet tags for Kubernetes

### EKS Module
- Provisions EKS cluster with managed node groups
- Configures cluster access and IAM roles
- Sets up OIDC provider for IRSA

### RDS Module
- Creates PostgreSQL RDS instance
- Manages database credentials in Secrets Manager
- Configures security groups and subnet groups

### IRSA Module
- Creates IAM roles for service accounts
- Configures policies for EBS CSI, Load Balancer Controller, and External Secrets

## Environment Configuration

Each environment can be customized through:

- `terraform.tfvars`: Environment-specific variable values
- `main.tf`: Module instantiations with environment-specific overrides
- `variables.tf`: Variable definitions (shared across environments)

## Outputs

The configuration provides the following outputs:

- `cluster_name`: EKS cluster name
- `cluster_endpoint`: EKS cluster endpoint
- `vpc_id`: VPC ID
- `update_kubeconfig`: Command to update kubectl config
- `rds_endpoint`: RDS instance endpoint
- `rds_secret_arn`: Secrets Manager secret ARN

## Security

- Secrets are managed through AWS Secrets Manager
- IAM roles follow least-privilege principle
- Network segmentation with security groups
- Encryption enabled for data at rest and in transit