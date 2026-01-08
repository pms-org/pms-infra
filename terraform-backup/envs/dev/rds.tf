# Random password for RDS
resource "random_password" "rds_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Store RDS credentials in Secrets Manager
resource "aws_secretsmanager_secret" "rds" {
  name                    = "pms/${var.environment}/postgres"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "rds" {
  secret_id = aws_secretsmanager_secret.rds.id
  secret_string = jsonencode({
    username = "pmsadmin"
    password = random_password.rds_password.result
    engine   = "postgres"
    port     = 5432
    dbname   = "pmsdb"
  })
  
  lifecycle {
    ignore_changes = [secret_string]
  }
}

# Security group for RDS
resource "aws_security_group" "rds" {
  name_prefix = "${local.cluster_name}-rds-"
  vpc_id      = module.vpc.vpc_id
  description = "Security group for RDS PostgreSQL"

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
    description     = "Allow PostgreSQL from EKS nodes"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "${local.cluster_name}-rds"
  }
}

# RDS PostgreSQL instance
module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "${local.cluster_name}-postgres"

  engine               = "postgres"
  engine_version       = "16"
  family               = "postgres16"
  major_engine_version = "16"
  instance_class       = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 100

  db_name  = "pmsdb"
  username = "pmsadmin"
  port     = 5432

  manage_master_user_password = false
  password                    = random_password.rds_password.result

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = module.vpc.database_subnet_group_name

  multi_az                = false
  publicly_accessible     = false
  backup_retention_period = 7
  skip_final_snapshot     = true
  deletion_protection     = false

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = {
    Name = "${local.cluster_name}-postgres"
  }
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
        --secret-string '{"username":"pmsadmin","password":"${random_password.rds_password.result}","engine":"postgres","host":"${module.rds.db_instance_address}","port":5432,"dbname":"pmsdb"}' \
        --region us-east-1
    EOT
  }
}
