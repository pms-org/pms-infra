module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.8"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_irsa                    = true
  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    general = {
      ami_type       = "AL2_x86_64"
      instance_types = var.node_instance_types
      desired_size   = var.node_desired_size
      min_size       = var.node_min_size
      max_size       = var.node_max_size
    }
  }

  # Grant cluster admin access to the devx-administrator SSO role
  enable_cluster_creator_admin_permissions = true

  access_entries = {
    devx_admin = {
      principal_arn = "arn:aws:iam::209332675115:role/AWSReservedSSO_devx-administrator-access_8d57ac90ee6190f9"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  tags = {
    Environment = var.environment
    Project     = "pms"
  }
}
