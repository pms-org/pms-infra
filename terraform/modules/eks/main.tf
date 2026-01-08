module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.8"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  enable_irsa                    = var.enable_irsa
  cluster_endpoint_public_access = var.cluster_endpoint_public_access

  eks_managed_node_groups = var.eks_managed_node_groups

  # Grant cluster admin access to the devx-administrator SSO role
  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions

  access_entries = var.access_entries

  # EBS CSI Driver Add-on
  cluster_addons = {
    aws-ebs-csi-driver = {
      most_recent = true
      service_account_role_arn = var.ebs_csi_service_account_role_arn
    }
  }

  tags = var.tags
}