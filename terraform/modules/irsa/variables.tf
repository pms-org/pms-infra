variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "oidc_provider_arn" {
  description = "OIDC provider ARN"
  type        = string
}

# EBS CSI Driver variables
variable "ebs_csi_role_name" {
  description = "Role name for EBS CSI driver"
  type        = string
}

variable "attach_ebs_csi_policy" {
  description = "Whether to attach EBS CSI policy"
  type        = bool
  default     = true
}

variable "ebs_csi_oidc_providers" {
  description = "OIDC providers for EBS CSI driver"
  type        = any
}

# Load Balancer Controller variables
variable "lb_controller_role_name" {
  description = "Role name for AWS Load Balancer Controller"
  type        = string
}

variable "attach_load_balancer_controller_policy" {
  description = "Whether to attach Load Balancer Controller policy"
  type        = bool
  default     = true
}

variable "lb_controller_oidc_providers" {
  description = "OIDC providers for Load Balancer Controller"
  type        = any
}

# External Secrets variables
variable "external_secrets_role_name" {
  description = "Role name for External Secrets Operator"
  type        = string
}

variable "external_secrets_oidc_providers" {
  description = "OIDC providers for External Secrets Operator"
  type        = any
}

variable "external_secrets_policy_name" {
  description = "Policy name for External Secrets"
  type        = string
}

variable "external_secrets_policy_description" {
  description = "Policy description for External Secrets"
  type        = string
  default     = "Policy for External Secrets Operator to access Secrets Manager"
}

variable "external_secrets_policy_actions" {
  description = "Policy actions for External Secrets"
  type        = list(string)
  default     = [
    "secretsmanager:GetSecretValue",
    "secretsmanager:DescribeSecret",
    "secretsmanager:ListSecrets"
  ]
}

variable "external_secrets_policy_resources" {
  description = "Policy resources for External Secrets"
  type        = list(string)
  default     = ["*"]
}