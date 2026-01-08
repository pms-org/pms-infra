variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the cluster"
  type        = list(string)
}

variable "enable_irsa" {
  description = "Whether to enable IAM roles for service accounts"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Whether cluster endpoint is publicly accessible"
  type        = bool
  default     = true
}

variable "eks_managed_node_groups" {
  description = "EKS managed node groups configuration"
  type        = any
  default     = {}
}

variable "enable_cluster_creator_admin_permissions" {
  description = "Whether to enable cluster creator admin permissions"
  type        = bool
  default     = true
}

variable "access_entries" {
  description = "Access entries for the cluster"
  type        = any
  default     = {}
}

variable "ebs_csi_service_account_role_arn" {
  description = "ARN of the IAM role for EBS CSI driver service account"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags for the cluster"
  type        = map(string)
  default     = {}
}