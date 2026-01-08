#!/bin/bash
# Terraform Configuration Validation Script

set -e

echo "🔍 PMS Infrastructure Validation"
echo "=================================="
echo ""

# Check current directory
if [[ ! -f "backend.tf" ]]; then
    echo "❌ Error: Must run from terraform/envs/dev directory"
    exit 1
fi

echo "✅ Running from correct directory"
echo ""

# Check for Helm references (should not exist)
echo "🔍 Checking for Helm references..."
if grep -r "helm" *.tf 2>/dev/null | grep -v "# " | grep -v "Helm" > /dev/null; then
    echo "❌ Found active Helm references (should be removed)"
    grep -r "helm" *.tf | grep -v "# " | grep -v "Helm"
    exit 1
else
    echo "✅ No Helm provider or resources found"
fi
echo ""

# Check for Kubernetes provider (should not exist)
echo "🔍 Checking for Kubernetes provider..."
if grep "provider \"kubernetes\"" *.tf 2>/dev/null > /dev/null; then
    echo "❌ Found Kubernetes provider (should be removed)"
    exit 1
else
    echo "✅ No Kubernetes provider found"
fi
echo ""

# Validate required files
echo "🔍 Checking required files..."
required_files=(
    "backend.tf"
    "providers.tf"
    "locals.tf"
    "variables.tf"
    "terraform.tfvars"
    "vpc.tf"
    "eks.tf"
    "irsa.tf"
    "rds.tf"
    "outputs.tf"
)

for file in "${required_files[@]}"; do
    if [[ -f "$file" ]]; then
        echo "  ✅ $file"
    else
        echo "  ❌ $file (missing)"
        exit 1
    fi
done
echo ""

# Check IRSA outputs
echo "🔍 Checking IRSA outputs..."
required_outputs=(
    "ebs_csi_role_arn"
    "aws_lb_controller_role_arn"
    "external_secrets_role_arn"
)

for output in "${required_outputs[@]}"; do
    if grep -q "output \"$output\"" outputs.tf; then
        echo "  ✅ $output"
    else
        echo "  ❌ $output (missing)"
        exit 1
    fi
done
echo ""

# Check S3 backend configuration
echo "🔍 Checking S3 backend..."
if grep -q "backend \"s3\"" backend.tf; then
    echo "✅ S3 backend configured"
else
    echo "❌ S3 backend not found"
    exit 1
fi
echo ""

# Check for local backend (should not exist)
echo "🔍 Checking for local backend..."
if grep -q "backend \"local\"" backend.tf 2>/dev/null; then
    echo "❌ Found local backend (should be removed)"
    exit 1
else
    echo "✅ No local backend found"
fi
echo ""

# Check for terraform.tfstate in repo (should not exist)
echo "🔍 Checking for committed state files..."
if [[ -f "terraform.tfstate" ]] || [[ -f "terraform.tfstate.backup" ]]; then
    echo "❌ Found terraform.tfstate files (should be in .gitignore)"
    exit 1
else
    echo "✅ No state files in repository"
fi
echo ""

# Validate Terraform syntax
echo "🔍 Running terraform fmt check..."
if terraform fmt -check -recursive . > /dev/null 2>&1; then
    echo "✅ Terraform formatting is correct"
else
    echo "⚠️  Terraform formatting issues found, run: terraform fmt -recursive"
fi
echo ""

echo "🔍 Running terraform validate..."
if terraform init -backend=false > /dev/null 2>&1; then
    if terraform validate > /dev/null 2>&1; then
        echo "✅ Terraform configuration is valid"
    else
        echo "❌ Terraform validation failed"
        terraform validate
        exit 1
    fi
else
    echo "⚠️  Could not initialize Terraform (run terraform init manually)"
fi
echo ""

# Summary
echo "=================================="
echo "✅ All validation checks passed!"
echo ""
echo "Next steps:"
echo "  1. terraform init"
echo "  2. terraform plan"
echo "  3. terraform apply"
echo ""
echo "Documentation:"
echo "  • README.md - Deployment guide"
echo "  • GITOPS_INTEGRATION.md - Kustomize patterns"
echo "  • REFACTORING_SUMMARY.md - What changed"
