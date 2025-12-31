# RDS PostgreSQL for PMS (Dev Environment)
# This will be added to main.tf after EKS is provisioned

module "rds" {
  source = "../../modules/rds"

  cluster_name    = local.cluster_name
  environment     = local.environment
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets

  # RDS Configuration
  engine_version        = "16.1"
  instance_class        = "db.t3.medium" # Dev environment
  allocated_storage     = 50
  max_allocated_storage = 100

  # Database settings
  db_name  = "pmsdb"
  username = "pmsadmin" # Will be stored in Secrets Manager

  # High Availability (disabled for dev, enabled for prod)
  multi_az                = false
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  # Security
  deletion_protection = false # Enable in production!
  skip_final_snapshot = true  # Disable in production!

  # Allow EKS nodes to connect
  allowed_security_group_ids = [module.eks.node_security_group_id]

  tags = local.tags
}

# Store RDS credentials in AWS Secrets Manager
resource "aws_secretsmanager_secret" "rds_credentials" {
  name        = "pms/dev/postgres"
  description = "RDS PostgreSQL credentials for PMS dev environment"

  tags = local.tags
}

resource "aws_secretsmanager_secret_version" "rds_credentials" {
  secret_id = aws_secretsmanager_secret.rds_credentials.id

  secret_string = jsonencode({
    host     = module.rds.db_instance_endpoint
    port     = module.rds.db_instance_port
    dbname   = module.rds.db_instance_name
    username = module.rds.db_instance_username
    password = module.rds.db_instance_password
  })
}

# RDS Outputs
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.rds.db_instance_endpoint
  sensitive   = true
}

output "rds_secrets_manager_arn" {
  description = "ARN of the Secrets Manager secret containing RDS credentials"
  value       = aws_secretsmanager_secret.rds_credentials.arn
}
