#!/bin/bash
# AWS Deployment Preparation Script
# This script helps prepare the environment for AWS deployment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check AWS CLI
    if ! aws --version >/dev/null 2>&1; then
        log_error "AWS CLI not installed. Please install from https://aws.amazon.com/cli/"
        exit 1
    fi

    # Check kubectl
    if ! kubectl version --client >/dev/null 2>&1; then
        log_error "kubectl not installed. Please install from https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi

    # Check terraform
    if ! terraform --version >/dev/null 2>&1; then
        log_error "Terraform not installed. Please install from https://www.terraform.io/downloads"
        exit 1
    fi

    # Check helm
    if ! helm version >/dev/null 2>&1; then
        log_error "Helm not installed. Please install from https://helm.sh/docs/intro/install/"
        exit 1
    fi

    log_success "All prerequisites met!"
}

configure_aws() {
    log_info "Configuring AWS CLI..."

    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_warning "AWS CLI not configured. Running 'aws configure'..."
        aws configure

        if ! aws sts get-caller-identity >/dev/null 2>&1; then
            log_error "AWS configuration failed. Please check your credentials."
            exit 1
        fi
    fi

    # Get account info
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    REGION=$(aws configure get region)

    log_success "AWS configured for account: $ACCOUNT_ID in region: $REGION"
}

setup_terraform_backend() {
    log_info "Setting up Terraform backend..."

    BUCKET_NAME="pms-terraform-state"
    REGION="ap-south-1"
    TABLE_NAME="terraform-locks"

    # Create S3 bucket
    if ! aws s3 ls "s3://$BUCKET_NAME" >/dev/null 2>&1; then
        log_info "Creating S3 bucket for Terraform state..."
        aws s3 mb "s3://$BUCKET_NAME" --region "$REGION"
        aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --versioning-configuration Status=Enabled
    fi

    # Create DynamoDB table
    if ! aws dynamodb describe-table --table-name "$TABLE_NAME" >/dev/null 2>&1; then
        log_info "Creating DynamoDB table for state locking..."
        aws dynamodb create-table \
            --table-name "$TABLE_NAME" \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --billing-mode PAY_PER_REQUEST \
            --region "$REGION"
    fi

    log_success "Terraform backend ready!"
}

initialize_terraform() {
    log_info "Initializing Terraform..."

    cd terraform/envs/dev

    if [ ! -d ".terraform" ]; then
        terraform init
    else
        log_info "Terraform already initialized"
    fi

    # Validate configuration
    terraform validate

    log_success "Terraform initialized and validated!"
}

show_next_steps() {
    cat << 'EOF'

🎉 AWS Deployment Preparation Complete!

Next Steps:

1. 📋 Review and customize terraform.tfvars:
   cd terraform/envs/dev
   vim terraform.tfvars

2. 🚀 Deploy infrastructure:
   terraform plan -out=tfplan
   terraform apply tfplan

3. ⚙️ Configure Kubernetes access:
   aws eks update-kubeconfig --region us-east-1 --name pms-dev

4. 🐙 Install ArgoCD:
   See AWS_DEPLOYMENT_GUIDE.md for detailed instructions

5. 🔐 Setup secrets:
   Follow the secrets management section in AWS_DEPLOYMENT_GUIDE.md

6. 📊 Deploy applications:
   Use ArgoCD to deploy PMS applications

For detailed instructions, see: AWS_DEPLOYMENT_GUIDE.md

EOF
}

# Main execution
main() {
    echo "🚀 PMS AWS Deployment Preparation"
    echo "================================="

    check_prerequisites
    configure_aws
    setup_terraform_backend
    initialize_terraform
    show_next_steps

    log_success "Preparation complete! Ready for AWS deployment."
}

# Run main function
main "$@"