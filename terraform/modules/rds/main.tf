# Random password for RDS
resource "random_password" "rds_password" {
  length           = var.password_length
  special          = var.password_special
  override_special = var.password_override_special
}

# Store RDS credentials in Secrets Manager
resource "aws_secretsmanager_secret" "rds" {
  name                    = var.secret_name
  recovery_window_in_days = var.secret_recovery_window
}

resource "aws_secretsmanager_secret_version" "rds" {
  secret_id = aws_secretsmanager_secret.rds.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.rds_password.result
    engine   = var.engine
    port     = var.port
    dbname   = var.db_name
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# Security group for RDS
resource "aws_security_group" "rds" {
  name_prefix = "${var.cluster_name}-rds-"
  vpc_id      = var.vpc_id
  description = var.security_group_description

  ingress {
    from_port       = var.port
    to_port         = var.port
    protocol        = "tcp"
    security_groups = var.allowed_security_groups
    description     = var.ingress_description
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = var.security_group_tags
}

# RDS PostgreSQL instance
module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = var.identifier

  engine               = var.engine
  engine_version       = var.engine_version
  family               = var.family
  major_engine_version = var.major_engine_version
  instance_class       = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage

  db_name  = var.db_name
  username = var.db_username
  port     = var.port

  manage_master_user_password = var.manage_master_user_password
  password                    = random_password.rds_password.result

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = var.db_subnet_group_name

  multi_az                = var.multi_az
  publicly_accessible     = var.publicly_accessible
  backup_retention_period = var.backup_retention_period
  skip_final_snapshot     = var.skip_final_snapshot
  deletion_protection     = var.deletion_protection

  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports

  tags = var.rds_tags
}

# Update secret with RDS endpoint after creation (breaks circular dependency)
resource "null_resource" "update_rds_secret" {
  depends_on = [module.rds, aws_secretsmanager_secret_version.rds]

  triggers = {
    rds_endpoint = module.rds.db_instance_address
  }

  provisioner "local-exec" {
    command = <<-EOT
      eval $(aws configure export-credentials --format env --profile default)
      aws secretsmanager put-secret-value \
        --secret-id ${aws_secretsmanager_secret.rds.id} \
        --secret-string '{"username":"${var.db_username}","password":"${random_password.rds_password.result}","engine":"${var.engine}","host":"${module.rds.db_instance_address}","port":${var.port},"dbname":"${var.db_name}"}' \
        --region ${var.aws_region}
    EOT
  }
}