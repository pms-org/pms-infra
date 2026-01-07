locals {
  cluster_name = "pms-${var.environment}"
  vpc_cidr     = "10.0.0.0/16"
}

module "vpc" {
  source = "../../modules/vpc"

  name = "${local.cluster_name}-vpc"
  cidr = local.vpc_cidr

  azs             = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  database_subnets = ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = {
    Name = "${local.cluster_name}-vpc"
  }
}

module "eks" {
  source = "../../modules/eks"

  aws_region     = var.aws_region
  cluster_name   = local.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    general = {
      ami_type       = "AL2_x86_64"
      instance_types = var.node_instance_types
      desired_size   = var.node_desired_size
      min_size       = var.node_min_size
      max_size       = var.node_max_size
    }
  }

  # Temporarily remove access entries due to SSO role ARN issues
  # access_entries = {
  #   devx_admin = {
  #     principal_arn = "arn:aws:iam::209332675115:role/AWSReservedSSO_devx-administrator-access_8d57ac90ee6190f9"
  #     policy_associations = {
  #       admin = {
  #         policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  #         access_scope = {
  #           type = "cluster"
  #       }
  #     }
  #   }
  # }

  tags = {
    Environment = var.environment
    Project     = "pms"
  }
}

module "rds" {
  source = "../../modules/rds"

  aws_region             = var.aws_region
  cluster_name           = local.cluster_name
  vpc_id                 = module.vpc.vpc_id
  db_subnet_group_name   = module.vpc.database_subnet_group_name
  allowed_security_groups = [module.eks.node_security_group_id]

  secret_name = "pms/${var.environment}/postgres"

  identifier = "${local.cluster_name}-postgres"

  rds_tags = {
    Name = "${local.cluster_name}-postgres"
  }
}

module "irsa" {
  source = "../../modules/irsa"

  cluster_name       = local.cluster_name
  oidc_provider_arn  = module.eks.oidc_provider_arn

  ebs_csi_role_name = "${local.cluster_name}-ebs-csi-driver"
  ebs_csi_oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  lb_controller_role_name = "${local.cluster_name}-aws-load-balancer-controller"
  lb_controller_oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  external_secrets_role_name = "${local.cluster_name}-external-secrets"
  external_secrets_oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["external-secrets:external-secrets"]
    }
  }

  external_secrets_policy_name = "${local.cluster_name}-external-secrets-policy"
}