# Terraform Backend Configuration
# S3 backend for remote state storage with DynamoDB locking

terraform {
  backend "s3" {
    # NOTE: Use a single S3 backend + DynamoDB table for state locking across the team.
    # Replace the values below with your organization's bucket / region when onboarding.
    bucket         = "pms-terraform-state"
    key            = "eks/dev/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

# Local backend (for testing only - DISABLED)
# terraform {
#   backend "local" {
#     path = "terraform.tfstate"
#   }
# }
