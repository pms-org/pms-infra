# Terraform Backend Configuration
# COMMENTED OUT FOR TESTING - Uncomment after creating S3 bucket

# terraform {
#   backend "s3" {
#     bucket         = "pms-terraform-state-dev"
#     key            = "eks/dev/terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     dynamodb_table = "pms-terraform-locks"
#   }
# }

# For testing, using local backend (state file stored locally)
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
