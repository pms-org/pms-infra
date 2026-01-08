locals {
  environment  = var.environment
  cluster_name = "pms-${var.environment}"
  vpc_cidr     = "10.0.0.0/16"
}
