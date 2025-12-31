# Terraform Infrastructure

## Overview
This directory will contain Terraform configurations for cloud infrastructure provisioning.

## Structure (Future)

```
terraform/
├── modules/              # Reusable Terraform modules
│   ├── eks/             # AWS EKS cluster module
│   ├── aks/             # Azure AKS cluster module
│   ├── rds/             # Managed database module
│   └── vpc/             # Network module
│
└── envs/                # Environment-specific configs
    ├── dev/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── terraform.tfvars
    └── prod/
        ├── main.tf
        ├── variables.tf
        └── terraform.tfvars
```

## Planned Resources

### Compute
- Kubernetes cluster (EKS/AKS/GKE)
- Node groups with autoscaling
- Load balancers

### Data
- Managed PostgreSQL (RDS/Cloud SQL)
- Managed Redis (ElastiCache/Azure Cache)
- S3/Blob Storage for backups

### Networking
- VPC/VNet configuration
- Private subnets for databases
- Public subnets for load balancers
- Security groups/NSGs

### Kafka (Options)
- Amazon MSK (Managed Kafka)
- Confluent Cloud
- Self-managed StatefulSet

## Usage (Future)

```bash
cd terraform/envs/dev

# Initialize
terraform init

# Plan
terraform plan

# Apply
terraform apply

# Output kubeconfig
terraform output kubeconfig > ~/.kube/config-pms-dev
```

## State Management

- Use remote state (S3 + DynamoDB / Azure Storage)
- Enable state locking
- Separate state per environment

## Next Steps

1. Design module architecture
2. Define variable structure
3. Create dev environment first
4. Document provisioning procedures
