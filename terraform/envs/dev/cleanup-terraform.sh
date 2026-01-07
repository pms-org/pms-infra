#!/bin/bash

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🧹 Terraform State Cleanup Script"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if we're in the right directory
if [ ! -f "terraform.tfstate" ]; then
    echo "❌ Error: terraform.tfstate not found in current directory"
    echo "   Please run this script from the terraform directory"
    exit 1
fi

echo "⚠️  WARNING: This will delete Terraform state files!"
echo ""
echo "Files to be removed:"
echo "  - terraform.tfstate (current state)"
echo "  - terraform.tfstate.backup (backup state)"
echo "  - .terraform/ directory (cache)"
echo "  - .terraform.lock.hcl (lock file)"
echo ""
echo "❌ DANGER: This will lose track of any deployed infrastructure!"
echo "   Only proceed if you have destroyed all resources or are starting fresh."
echo ""

read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Cleanup cancelled by user"
    exit 0
fi

echo ""
echo "🧹 Cleaning up Terraform state files..."

# Remove state files
if [ -f "terraform.tfstate" ]; then
    rm -f terraform.tfstate
    echo "✅ Removed terraform.tfstate"
fi

if [ -f "terraform.tfstate.backup" ]; then
    rm -f terraform.tfstate.backup
    echo "✅ Removed terraform.tfstate.backup"
fi

# Remove cache directory
if [ -d ".terraform" ]; then
    rm -rf .terraform
    echo "✅ Removed .terraform/ directory"
fi

# Remove lock file
if [ -f ".terraform.lock.hcl" ]; then
    rm -f .terraform.lock.hcl
    echo "✅ Removed .terraform.lock.hcl"
fi

# Remove tfplan if it exists
if [ -f "tfplan" ]; then
    rm -f tfplan
    echo "✅ Removed tfplan file"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Cleanup Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "1. Run 'terraform init' to reinitialize"
echo "2. Run 'terraform plan' to see what will be created"
echo "3. Run 'terraform apply' to deploy infrastructure"
echo ""
echo "⚠️  Remember: This is a fresh start - no existing infrastructure tracked"
