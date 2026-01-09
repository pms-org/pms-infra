# AWS Secrets Manager Secrets for PMS Infrastructure and Applications

# Infrastructure Secrets
data "aws_secretsmanager_secret" "database" {
  name = "pms/${var.environment}/database"
}

resource "aws_secretsmanager_secret_version" "database" {
  secret_id = data.aws_secretsmanager_secret.database.id
  secret_string = jsonencode({
    POSTGRES_PASSWORD = "pms"
  })
}

data "aws_secretsmanager_secret" "kafka" {
  name = "pms/${var.environment}/kafka"
}

resource "aws_secretsmanager_secret_version" "kafka" {
  secret_id = data.aws_secretsmanager_secret.kafka.id
  secret_string = jsonencode({
    KAFKA_ADMIN_PASSWORD = "kafka"
    KAFKA_USER_PASSWORD  = "kafka"
  })
}

data "aws_secretsmanager_secret" "rabbitmq" {
  name = "pms/${var.environment}/rabbitmq"
}

resource "aws_secretsmanager_secret_version" "rabbitmq" {
  secret_id = data.aws_secretsmanager_secret.rabbitmq.id
  secret_string = jsonencode({
    RABBITMQ_DEFAULT_USER = "rabbit-user"
    RABBITMQ_DEFAULT_PASS = "rabbitmq"
    # Additional stream-enabled user for applications
    RABBITMQ_STREAM_USER  = "rabbit-user"
    RABBITMQ_STREAM_PASS  = "rabbitmq"
  })
}

data "aws_secretsmanager_secret" "redis" {
  name = "pms/${var.environment}/redis"
}

resource "aws_secretsmanager_secret_version" "redis" {
  secret_id = data.aws_secretsmanager_secret.redis.id
  secret_string = jsonencode({
    REDIS_PASSWORD = "redis"
  })
}

data "aws_secretsmanager_secret" "schema_registry" {
  name = "pms/${var.environment}/schema-registry"
}

resource "aws_secretsmanager_secret_version" "schema_registry" {
  secret_id = data.aws_secretsmanager_secret.schema_registry.id
  secret_string = jsonencode({
    SCHEMA_REGISTRY_API_KEY    = "registry-key-here"
    SCHEMA_REGISTRY_API_SECRET = "registry-secret-here"
  })
}

# Application Secrets
data "aws_secretsmanager_secret" "simulation" {
  name = "pms/${var.environment}/simulation"
}

resource "aws_secretsmanager_secret_version" "simulation" {
  secret_id = data.aws_secretsmanager_secret.simulation.id
  secret_string = jsonencode({
    SIMULATION_DB_PASSWORD     = "pms"
    SIMULATION_API_KEY         = "sim-api-key-123"
    SIMULATION_JWT_SECRET      = "sim-jwt-secret-456"
    SPRING_RABBITMQ_USERNAME   = "rabbit-user"
    SPRING_RABBITMQ_PASSWORD   = "rabbitmq"
  })
}

data "aws_secretsmanager_secret" "trade_capture" {
  name = "pms/${var.environment}/trade-capture"
}

resource "aws_secretsmanager_secret_version" "trade_capture" {
  secret_id = data.aws_secretsmanager_secret.trade_capture.id
  secret_string = jsonencode({
    TRADE_CAPTURE_DB_PASSWORD  = "pms"
    TRADE_CAPTURE_API_KEY      = "tc-api-key-123"
    TRADE_CAPTURE_JWT_SECRET   = "tc-jwt-secret-456"
    SPRING_RABBITMQ_USERNAME   = "rabbit-user"
    SPRING_RABBITMQ_PASSWORD   = "rabbitmq"
  })
}

data "aws_secretsmanager_secret" "validation" {
  name = "pms/${var.environment}/validation"
}

resource "aws_secretsmanager_secret_version" "validation" {
  secret_id = data.aws_secretsmanager_secret.validation.id
  secret_string = jsonencode({
    VALIDATION_API_KEY         = "val-api-key-123"
    VALIDATION_DB_PASSWORD     = "pms"
    VALIDATION_JWT_SECRET      = "val-jwt-secret-456"
    SPRING_RABBITMQ_USERNAME   = "rabbit-user"
    SPRING_RABBITMQ_PASSWORD   = "rabbitmq"
  })
}

# Auth Service Secrets
data "aws_secretsmanager_secret" "auth" {
  name = "pms/${var.environment}/auth"
}

resource "aws_secretsmanager_secret_version" "auth" {
  secret_id = data.aws_secretsmanager_secret.auth.id
  secret_string = jsonencode({
    DATASOURCE_USER = "pms"
    DATASOURCE_PASS = "pms"
    JWT_SECRET      = "auth-jwt-secret-789"
  })
}