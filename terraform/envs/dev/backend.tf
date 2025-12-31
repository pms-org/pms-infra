# Terraform Backend Configuration
# S3 backend for remote state storage with DynamoDB locking

terraform {
  backend "s3" {
    bucket         = "pms-terraform-state-dev-209332675115"
    key            = "eks/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "pms-terraform-locks"
  }
}

# Local backend (for testing only - DISABLED)
# terraform {
#   backend "local" {
#     path = "terraform.tfstate"
#   }
# }
