output "ebs_csi_role_arn" {
  description = "EBS CSI driver IAM role ARN"
  value       = module.ebs_csi_irsa.iam_role_arn
}

output "ebs_csi_role_name" {
  description = "EBS CSI driver IAM role name"
  value       = module.ebs_csi_irsa.iam_role_name
}

output "lb_controller_role_arn" {
  description = "AWS Load Balancer Controller IAM role ARN"
  value       = module.lb_controller_irsa.iam_role_arn
}

output "lb_controller_role_name" {
  description = "AWS Load Balancer Controller IAM role name"
  value       = module.lb_controller_irsa.iam_role_name
}

output "external_secrets_role_arn" {
  description = "External Secrets Operator IAM role ARN"
  value       = module.external_secrets_irsa.iam_role_arn
}

output "external_secrets_role_name" {
  description = "External Secrets Operator IAM role name"
  value       = module.external_secrets_irsa.iam_role_name
}

output "external_secrets_policy_arn" {
  description = "External Secrets policy ARN"
  value       = aws_iam_policy.external_secrets.arn
}