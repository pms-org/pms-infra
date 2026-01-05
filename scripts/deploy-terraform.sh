#!/usr/bin/env bash
# Quick Terraform Deployment Script for PMS Infrastructure

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🚀 PMS Infrastructure Terraform Deployment${NC}"
echo "=============================================="

# Check AWS credentials
echo -e "\n${BLUE}1. Checking AWS credentials...${NC}"
aws sts get-caller-identity || {
    echo -e "${YELLOW}❌ AWS credentials not valid${NC}"
    exit 1
}

# Navigate to terraform directory
cd "$(dirname "$0")/../terraform/envs/dev"
echo -e "${GREEN}✅ AWS credentials valid${NC}"

# Terraform init
echo -e "\n${BLUE}2. Initializing Terraform...${NC}"
terraform init

# Terraform validate
echo -e "\n${BLUE}3. Validating Terraform configuration...${NC}"
terraform validate
echo -e "${GREEN}✅ Configuration is valid${NC}"

# Terraform plan
echo -e "\n${BLUE}4. Creating deployment plan...${NC}"
terraform plan -out=tfplan

# Ask for confirmation
echo -e "\n${YELLOW}📋 Review the plan above.${NC}"
read -p "Do you want to apply this plan? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Terraform apply
echo -e "\n${BLUE}5. Applying Terraform plan...${NC}"
terraform apply tfplan

echo -e "\n${GREEN}✅ Terraform deployment complete!${NC}"

# Show outputs
echo -e "\n${BLUE}📊 Deployment Outputs:${NC}"
terraform output

echo -e "\n${GREEN}🎉 Infrastructure successfully deployed!${NC}"
echo -e "\n${BLUE}Next steps:${NC}"
echo "1. Configure kubectl: aws eks update-kubeconfig --name pms-dev --region us-east-1"
echo "2. Install ArgoCD: See AWS_DEPLOYMENT_GUIDE.md"
echo "3. Deploy applications via ArgoCD"
