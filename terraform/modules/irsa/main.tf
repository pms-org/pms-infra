# EBS CSI Driver IRSA
module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = var.ebs_csi_role_name

  attach_ebs_csi_policy = var.attach_ebs_csi_policy

  oidc_providers = var.ebs_csi_oidc_providers
}

# AWS Load Balancer Controller IRSA
module "lb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = var.lb_controller_role_name

  attach_load_balancer_controller_policy = var.attach_load_balancer_controller_policy

  oidc_providers = var.lb_controller_oidc_providers
}

# External Secrets Operator IRSA
module "external_secrets_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = var.external_secrets_role_name

  role_policy_arns = {
    policy = aws_iam_policy.external_secrets.arn
  }

  oidc_providers = var.external_secrets_oidc_providers
}

resource "aws_iam_policy" "external_secrets" {
  name        = var.external_secrets_policy_name
  description = var.external_secrets_policy_description

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = var.external_secrets_policy_actions
        Resource = var.external_secrets_policy_resources
      }
    ]
  })
}