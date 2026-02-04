variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "cluster_name" {
  description = "Cluster name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "db_subnet_group_name" {
  description = "Database subnet group name"
  type        = string
}

variable "allowed_security_groups" {
  description = "Security groups allowed to access RDS"
  type        = list(string)
}

# Password configuration
variable "password_length" {
  description = "Length of the RDS password"
  type        = number
  default     = 32
}

variable "password_special" {
  description = "Whether to include special characters in password"
  type        = bool
  default     = true
}

variable "password_override_special" {
  description = "Override special characters for password"
  type        = string
  default     = "!#$%&*()-_=+[]{}<>:?"
}

# Secrets Manager configuration
variable "secret_name" {
  description = "Name of the Secrets Manager secret"
  type        = string
}

variable "secret_recovery_window" {
  description = "Recovery window for Secrets Manager secret"
  type        = number
  default     = 0
}

# Database configuration
variable "identifier" {
  description = "RDS instance identifier"
  type        = string
}

variable "engine" {
  description = "Database engine"
  type        = string
  default     = "postgres"
}

variable "engine_version" {
  description = "Database engine version"
  type        = string
  default     = "16"
}

variable "family" {
  description = "Database parameter group family"
  type        = string
  default     = "postgres16"
}

variable "major_engine_version" {
  description = "Major engine version"
  type        = string
  default     = "16"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.r7g.large"
}

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Maximum allocated storage in GB"
  type        = number
  default     = 100
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "pmsdb"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "pmsadmin"
}

variable "port" {
  description = "Database port"
  type        = number
  default     = 5432
}

variable "manage_master_user_password" {
  description = "Whether to manage master user password"
  type        = bool
  default     = false
}

variable "multi_az" {
  description = "Whether to enable Multi-AZ"
  type        = bool
  default     = false
}

variable "publicly_accessible" {
  description = "Whether the DB instance is publicly accessible"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "skip_final_snapshot" {
  description = "Whether to skip final snapshot"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection"
  type        = bool
  default     = false
}

variable "enabled_cloudwatch_logs_exports" {
  description = "List of log types to enable for exporting to CloudWatch"
  type        = list(string)
  default     = ["postgresql", "upgrade"]
}

# Security group configuration
variable "security_group_description" {
  description = "Description for the RDS security group"
  type        = string
  default     = "Security group for RDS PostgreSQL"
}

variable "ingress_description" {
  description = "Description for ingress rule"
  type        = string
  default     = "Allow PostgreSQL from EKS nodes"
}

variable "security_group_tags" {
  description = "Tags for the RDS security group"
  type        = map(string)
  default     = {}
}

variable "rds_tags" {
  description = "Tags for the RDS instance"
  type        = map(string)
  default     = {}
}