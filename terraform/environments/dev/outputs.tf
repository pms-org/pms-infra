output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_version" {
  description = "Kubernetes version"
  value       = module.eks.cluster_version
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "update_kubeconfig" {
  description = "Command to update kubeconfig"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.rds.db_instance_endpoint
}

output "rds_secret_arn" {
  description = "RDS Secrets Manager secret ARN"
  value       = module.rds.secret_arn
}

output "external_secrets_role_arn" {
  description = "External Secrets Operator IAM role ARN"
  value       = module.irsa.external_secrets_role_arn
}

output "ebs_csi_role_arn" {
  description = "EBS CSI Driver IAM role ARN"
  value       = module.irsa.ebs_csi_role_arn
}