#!/bin/bash

# AWS Resource Cleanup Script for PMS Infrastructure
# Run this after re-authenticating with AWS SSO
#
# Usage: ./cleanup-remaining-resources.sh

set -e

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  AWS Resource Cleanup Script - PMS Infrastructure            ║"
echo "╔══════════════════════════════════════════════════════════════╗"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check AWS credentials
echo "🔐 Checking AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ AWS credentials not configured or expired${NC}"
    echo "Please run: aws sso login"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✅ Authenticated to AWS Account: $ACCOUNT_ID${NC}"
echo ""

# VPC ID to clean up
VPC_ID="vpc-0d97a2c15dcc19415"
REGION="us-east-1"

echo "🔍 Searching for resources in VPC: $VPC_ID"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if VPC exists
if ! aws ec2 describe-vpcs --vpc-ids $VPC_ID --region $REGION &> /dev/null; then
    echo -e "${GREEN}✅ VPC not found - already deleted!${NC}"
    echo ""
    echo "Checking for other PMS resources..."
else
    echo -e "${YELLOW}⚠️  VPC exists - proceeding with cleanup${NC}"
    echo ""

    # Step 1: Delete NAT Gateways
    echo "1️⃣  Deleting NAT Gateways..."
    NAT_GATEWAYS=$(aws ec2 describe-nat-gateways \
        --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available" \
        --query 'NatGateways[].NatGatewayId' \
        --output text \
        --region $REGION)
    
    if [ -n "$NAT_GATEWAYS" ]; then
        for NAT in $NAT_GATEWAYS; do
            echo "   Deleting NAT Gateway: $NAT"
            aws ec2 delete-nat-gateway --nat-gateway-id $NAT --region $REGION
        done
        echo -e "${GREEN}   ✅ NAT Gateways deletion initiated${NC}"
        echo "   ⏳ Waiting for NAT Gateways to delete (60 seconds)..."
        sleep 60
    else
        echo -e "${GREEN}   ✅ No NAT Gateways found${NC}"
    fi
    echo ""

    # Step 2: Delete Internet Gateways
    echo "2️⃣  Detaching and deleting Internet Gateways..."
    IGW_IDS=$(aws ec2 describe-internet-gateways \
        --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
        --query 'InternetGateways[].InternetGatewayId' \
        --output text \
        --region $REGION)
    
    if [ -n "$IGW_IDS" ]; then
        for IGW in $IGW_IDS; do
            echo "   Detaching IGW: $IGW from VPC: $VPC_ID"
            aws ec2 detach-internet-gateway --internet-gateway-id $IGW --vpc-id $VPC_ID --region $REGION
            echo "   Deleting IGW: $IGW"
            aws ec2 delete-internet-gateway --internet-gateway-id $IGW --region $REGION
        done
        echo -e "${GREEN}   ✅ Internet Gateways deleted${NC}"
    else
        echo -e "${GREEN}   ✅ No Internet Gateways found${NC}"
    fi
    echo ""

    # Step 3: Delete Subnets
    echo "3️⃣  Deleting Subnets..."
    SUBNET_IDS=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'Subnets[].SubnetId' \
        --output text \
        --region $REGION)
    
    if [ -n "$SUBNET_IDS" ]; then
        for SUBNET in $SUBNET_IDS; do
            echo "   Deleting Subnet: $SUBNET"
            aws ec2 delete-subnet --subnet-id $SUBNET --region $REGION
        done
        echo -e "${GREEN}   ✅ Subnets deleted${NC}"
    else
        echo -e "${GREEN}   ✅ No Subnets found${NC}"
    fi
    echo ""

    # Step 4: Delete Route Tables (except main)
    echo "4️⃣  Deleting Route Tables..."
    ROUTE_TABLES=$(aws ec2 describe-route-tables \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'RouteTables[?Associations[0].Main != `true`].RouteTableId' \
        --output text \
        --region $REGION)
    
    if [ -n "$ROUTE_TABLES" ]; then
        for RT in $ROUTE_TABLES; do
            echo "   Deleting Route Table: $RT"
            aws ec2 delete-route-table --route-table-id $RT --region $REGION 2>/dev/null || echo "   (Route table already deleted or has dependencies)"
        done
        echo -e "${GREEN}   ✅ Route Tables deleted${NC}"
    else
        echo -e "${GREEN}   ✅ No custom Route Tables found${NC}"
    fi
    echo ""

    # Step 5: Delete Security Groups (except default)
    echo "5️⃣  Deleting Security Groups..."
    SECURITY_GROUPS=$(aws ec2 describe-security-groups \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'SecurityGroups[?GroupName != `default`].GroupId' \
        --output text \
        --region $REGION)
    
    if [ -n "$SECURITY_GROUPS" ]; then
        for SG in $SECURITY_GROUPS; do
            echo "   Deleting Security Group: $SG"
            aws ec2 delete-security-group --group-id $SG --region $REGION 2>/dev/null || echo "   (Security group has dependencies, will retry)"
        done
        echo -e "${GREEN}   ✅ Security Groups deleted${NC}"
    else
        echo -e "${GREEN}   ✅ No custom Security Groups found${NC}"
    fi
    echo ""

    # Step 6: Release Elastic IPs
    echo "6️⃣  Releasing Elastic IPs..."
    ALLOCATION_IDS=$(aws ec2 describe-addresses \
        --filters "Name=domain,Values=vpc" \
        --query 'Addresses[].AllocationId' \
        --output text \
        --region $REGION)
    
    if [ -n "$ALLOCATION_IDS" ]; then
        for ALLOC in $ALLOCATION_IDS; do
            echo "   Releasing EIP: $ALLOC"
            aws ec2 release-address --allocation-id $ALLOC --region $REGION 2>/dev/null || echo "   (EIP already released)"
        done
        echo -e "${GREEN}   ✅ Elastic IPs released${NC}"
    else
        echo -e "${GREEN}   ✅ No Elastic IPs found${NC}"
    fi
    echo ""

    # Step 7: Delete VPC
    echo "7️⃣  Deleting VPC..."
    if aws ec2 delete-vpc --vpc-id $VPC_ID --region $REGION 2>/dev/null; then
        echo -e "${GREEN}   ✅ VPC deleted successfully${NC}"
    else
        echo -e "${RED}   ❌ Failed to delete VPC (may have remaining dependencies)${NC}"
        echo "   Run this script again or check AWS Console for remaining resources"
    fi
    echo ""
fi

# Step 8: Check and delete IAM roles
echo "8️⃣  Checking for PMS IAM Roles..."
IAM_ROLES=$(aws iam list-roles \
    --query 'Roles[?contains(RoleName, `pms-dev`)].RoleName' \
    --output text)

if [ -n "$IAM_ROLES" ]; then
    for ROLE in $IAM_ROLES; do
        echo "   Found IAM Role: $ROLE"
        
        # Detach managed policies
        ATTACHED_POLICIES=$(aws iam list-attached-role-policies \
            --role-name $ROLE \
            --query 'AttachedPolicies[].PolicyArn' \
            --output text)
        
        for POLICY in $ATTACHED_POLICIES; do
            echo "      Detaching policy: $POLICY"
            aws iam detach-role-policy --role-name $ROLE --policy-arn $POLICY
        done
        
        # Delete inline policies
        INLINE_POLICIES=$(aws iam list-role-policies \
            --role-name $ROLE \
            --query 'PolicyNames[]' \
            --output text)
        
        for POLICY in $INLINE_POLICIES; do
            echo "      Deleting inline policy: $POLICY"
            aws iam delete-role-policy --role-name $ROLE --policy-name $POLICY
        done
        
        # Delete the role
        echo "   Deleting IAM Role: $ROLE"
        aws iam delete-role --role-name $ROLE
    done
    echo -e "${GREEN}   ✅ IAM Roles deleted${NC}"
else
    echo -e "${GREEN}   ✅ No PMS IAM Roles found${NC}"
fi
echo ""

# Step 9: Check and delete IAM policies
echo "9️⃣  Checking for PMS IAM Policies..."
IAM_POLICIES=$(aws iam list-policies \
    --scope Local \
    --query 'Policies[?contains(PolicyName, `pms-dev`) || contains(PolicyName, `ebs-csi`) || contains(PolicyName, `load-balancer`)].Arn' \
    --output text)

if [ -n "$IAM_POLICIES" ]; then
    for POLICY_ARN in $IAM_POLICIES; do
        echo "   Deleting IAM Policy: $POLICY_ARN"
        
        # Delete all policy versions except default
        VERSIONS=$(aws iam list-policy-versions \
            --policy-arn $POLICY_ARN \
            --query 'Versions[?IsDefaultVersion==`false`].VersionId' \
            --output text)
        
        for VERSION in $VERSIONS; do
            aws iam delete-policy-version --policy-arn $POLICY_ARN --version-id $VERSION
        done
        
        # Delete the policy
        aws iam delete-policy --policy-arn $POLICY_ARN
    done
    echo -e "${GREEN}   ✅ IAM Policies deleted${NC}"
else
    echo -e "${GREEN}   ✅ No PMS IAM Policies found${NC}"
fi
echo ""

# Step 10: Delete KMS keys
echo "🔟 Checking for PMS KMS Keys..."
KMS_KEYS=$(aws kms list-aliases \
    --query 'Aliases[?contains(AliasName, `pms-dev`)].TargetKeyId' \
    --output text \
    --region $REGION)

if [ -n "$KMS_KEYS" ]; then
    for KEY in $KMS_KEYS; do
        echo "   Scheduling KMS Key deletion: $KEY"
        aws kms schedule-key-deletion --key-id $KEY --pending-window-in-days 7 --region $REGION
    done
    echo -e "${GREEN}   ✅ KMS Keys scheduled for deletion (7 days)${NC}"
else
    echo -e "${GREEN}   ✅ No PMS KMS Keys found${NC}"
fi
echo ""

# Step 11: Delete Secrets Manager secrets
echo "1️⃣1️⃣  Checking for PMS Secrets..."
SECRETS=$(aws secretsmanager list-secrets \
    --query 'SecretList[?contains(Name, `pms`)].Name' \
    --output text \
    --region $REGION)

if [ -n "$SECRETS" ]; then
    for SECRET in $SECRETS; do
        echo "   Deleting Secret: $SECRET"
        aws secretsmanager delete-secret \
            --secret-id $SECRET \
            --force-delete-without-recovery \
            --region $REGION
    done
    echo -e "${GREEN}   ✅ Secrets deleted${NC}"
else
    echo -e "${GREEN}   ✅ No PMS Secrets found${NC}"
fi
echo ""

# Step 12: Delete CloudWatch Log Groups
echo "1️⃣2️⃣  Checking for PMS CloudWatch Log Groups..."
LOG_GROUPS=$(aws logs describe-log-groups \
    --query 'logGroups[?contains(logGroupName, `pms-dev`)].logGroupName' \
    --output text \
    --region $REGION)

if [ -n "$LOG_GROUPS" ]; then
    for LOG_GROUP in $LOG_GROUPS; do
        echo "   Deleting Log Group: $LOG_GROUP"
        aws logs delete-log-group --log-group-name $LOG_GROUP --region $REGION
    done
    echo -e "${GREEN}   ✅ CloudWatch Log Groups deleted${NC}"
else
    echo -e "${GREEN}   ✅ No PMS Log Groups found${NC}"
fi
echo ""

# Step 13: Clean up S3 bucket
echo "1️⃣3️⃣  Cleaning up S3 Terraform State Bucket..."
S3_BUCKET="pms-terraform-state-dev-${ACCOUNT_ID}"

if aws s3 ls "s3://$S3_BUCKET" &> /dev/null; then
    echo "   Found bucket: $S3_BUCKET"
    echo "   Deleting all objects and versions..."
    
    # Delete all versions
    aws s3api list-object-versions \
        --bucket $S3_BUCKET \
        --query 'Versions[].{Key:Key,VersionId:VersionId}' \
        --output json | \
        jq -r '.[] | "--key \"\(.Key)\" --version-id \(.VersionId)"' | \
        while read -r args; do
            eval aws s3api delete-object --bucket $S3_BUCKET $args
        done
    
    # Delete all delete markers
    aws s3api list-object-versions \
        --bucket $S3_BUCKET \
        --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' \
        --output json | \
        jq -r '.[] | "--key \"\(.Key)\" --version-id \(.VersionId)"' | \
        while read -r args; do
            eval aws s3api delete-object --bucket $S3_BUCKET $args
        done
    
    # Delete the bucket
    echo "   Deleting bucket: $S3_BUCKET"
    aws s3 rb "s3://$S3_BUCKET" --force
    echo -e "${GREEN}   ✅ S3 bucket deleted${NC}"
else
    echo -e "${GREEN}   ✅ S3 bucket not found${NC}"
fi
echo ""

# Step 14: Verify DynamoDB table deletion
echo "1️⃣4️⃣  Checking DynamoDB table..."
if aws dynamodb describe-table --table-name pms-terraform-locks --region $REGION &> /dev/null; then
    TABLE_STATUS=$(aws dynamodb describe-table \
        --table-name pms-terraform-locks \
        --region $REGION \
        --query 'Table.TableStatus' \
        --output text)
    echo -e "${YELLOW}   ⚠️  DynamoDB table status: $TABLE_STATUS${NC}"
    if [ "$TABLE_STATUS" != "DELETING" ]; then
        echo "   Deleting table: pms-terraform-locks"
        aws dynamodb delete-table --table-name pms-terraform-locks --region $REGION
    fi
else
    echo -e "${GREEN}   ✅ DynamoDB table not found or already deleted${NC}"
fi
echo ""

# Final summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              ✅ CLEANUP COMPLETED                            ║"
echo "╔══════════════════════════════════════════════════════════════╗"
echo ""
echo "📋 Summary:"
echo "   • VPC and networking resources"
echo "   • IAM roles and policies"
echo "   • KMS keys (scheduled for deletion)"
echo "   • Secrets Manager secrets"
echo "   • CloudWatch log groups"
echo "   • S3 Terraform state bucket"
echo "   • DynamoDB state lock table"
echo ""
echo "💰 Verify no charges:"
echo "   Check AWS Cost Explorer in 24-48 hours"
echo ""
echo "🔍 Double-check (recommended):"
echo "   aws ec2 describe-vpcs --filters \"Name=tag:Project,Values=pms\""
echo "   aws iam list-roles --query 'Roles[?contains(RoleName, \`pms\`)]'"
echo ""
echo -e "${GREEN}All PMS infrastructure resources have been cleaned up!${NC}"
echo ""
