#!/bin/bash
set -e

eval $(aws configure export-credentials --format env --profile default)

VPC_IDS="vpc-0ac6270d95938934d vpc-0c1eea9d0431a063e"

echo "=== Cleaning up AWS Resources ==="

# Delete RDS instances
echo "1. Deleting RDS instances..."
aws rds describe-db-instances --region us-east-1 --query 'DBInstances[?contains(DBInstanceIdentifier, `pms-dev`)].DBInstanceIdentifier' --output text | while read db; do
  if [ ! -z "$db" ]; then
    echo "  Deleting RDS: $db"
    aws rds delete-db-instance --db-instance-identifier "$db" --skip-final-snapshot --region us-east-1 2>/dev/null || echo "  Already deleted or error"
  fi
done

# Delete EKS clusters
echo "2. Deleting EKS clusters..."
aws eks list-clusters --region us-east-1 --query 'clusters' --output text | grep pms | while read cluster; do
  if [ ! -z "$cluster" ]; then
    echo "  Deleting EKS cluster: $cluster"
    aws eks delete-cluster --name "$cluster" --region us-east-1 2>/dev/null || echo "  Already deleted or error"
  fi
done

# Delete Secrets Manager secrets
echo "3. Deleting Secrets Manager secrets..."
aws secretsmanager list-secrets --region us-east-1 --query 'SecretList[?starts_with(Name, `pms/dev`)].Name' --output text | while read secret; do
  if [ ! -z "$secret" ]; then
    echo "  Deleting secret: $secret"
    aws secretsmanager delete-secret --secret-id "$secret" --force-delete-without-recovery --region us-east-1 2>/dev/null || echo "  Already deleted"
  fi
done

# Delete CloudWatch Log Groups
echo "4. Deleting CloudWatch Log Groups..."
aws logs describe-log-groups --region us-east-1 --query 'logGroups[?starts_with(logGroupName, `/aws/eks/pms-dev`)].logGroupName' --output text | while read lg; do
  if [ ! -z "$lg" ]; then
    echo "  Deleting log group: $lg"
    aws logs delete-log-group --log-group-name "$lg" --region us-east-1 2>/dev/null || echo "  Already deleted"
  fi
done

# Wait for EKS and RDS to delete
echo "5. Waiting for EKS/RDS deletion (30s)..."
sleep 30

# Clean up VPCs
for VPC_ID in $VPC_IDS; do
  echo "6. Cleaning VPC: $VPC_ID"
  
  # Delete NAT Gateways
  echo "  6a. Deleting NAT Gateways..."
  aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" --region us-east-1 --query 'NatGateways[?State!=`deleted`].NatGatewayId' --output text | while read ngw; do
    if [ ! -z "$ngw" ]; then
      echo "    Deleting NAT Gateway: $ngw"
      aws ec2 delete-nat-gateway --nat-gateway-id "$ngw" --region us-east-1 2>/dev/null || true
    fi
  done
  
  # Delete Network Interfaces
  echo "  6b. Deleting Network Interfaces..."
  aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$VPC_ID" --region us-east-1 --query 'NetworkInterfaces[].NetworkInterfaceId' --output text | while read eni; do
    if [ ! -z "$eni" ]; then
      echo "    Deleting ENI: $eni"
      aws ec2 delete-network-interface --network-interface-id "$eni" --region us-east-1 2>/dev/null || true
    fi
  done
  
  # Delete Security Groups (except default)
  echo "  6c. Deleting Security Groups..."
  aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" --region us-east-1 --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text | while read sg; do
    if [ ! -z "$sg" ]; then
      echo "    Deleting SG: $sg"
      aws ec2 delete-security-group --group-id "$sg" --region us-east-1 2>/dev/null || true
    fi
  done
  
  # Detach and delete Internet Gateways
  echo "  6d. Deleting Internet Gateways..."
  aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --region us-east-1 --query 'InternetGateways[].InternetGatewayId' --output text | while read igw; do
    if [ ! -z "$igw" ]; then
      echo "    Detaching and deleting IGW: $igw"
      aws ec2 detach-internet-gateway --internet-gateway-id "$igw" --vpc-id "$VPC_ID" --region us-east-1 2>/dev/null || true
      aws ec2 delete-internet-gateway --internet-gateway-id "$igw" --region us-east-1 2>/dev/null || true
    fi
  done
  
  # Delete Subnets
  echo "  6e. Deleting Subnets..."
  aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --region us-east-1 --query 'Subnets[].SubnetId' --output text | while read subnet; do
    if [ ! -z "$subnet" ]; then
      echo "    Deleting Subnet: $subnet"
      aws ec2 delete-subnet --subnet-id "$subnet" --region us-east-1 2>/dev/null || true
    fi
  done
  
  # Delete Route Tables (except main)
  echo "  6f. Deleting Route Tables..."
  MAIN_RT=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=association.main,Values=true" --region us-east-1 --query 'RouteTables[0].RouteTableId' --output text)
  aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --region us-east-1 --query 'RouteTables[].RouteTableId' --output text | while read rt; do
    if [ ! -z "$rt" ] && [ "$rt" != "$MAIN_RT" ]; then
      echo "    Deleting Route Table: $rt"
      aws ec2 delete-route-table --route-table-id "$rt" --region us-east-1 2>/dev/null || true
    fi
  done
done

# Wait for NAT Gateways to delete
echo "7. Waiting for NAT Gateways to delete (60s)..."
sleep 60

# Release Elastic IPs
echo "8. Releasing Elastic IPs..."
aws ec2 describe-addresses --region us-east-1 --query 'Addresses[?Tags[?Key==`Project` && Value==`pms`]].AllocationId' --output text | while read eip; do
  if [ ! -z "$eip" ]; then
    echo "  Releasing EIP: $eip"
    aws ec2 release-address --allocation-id "$eip" --region us-east-1 2>/dev/null || true
  fi
done

# Delete VPCs
echo "9. Deleting VPCs..."
for VPC_ID in $VPC_IDS; do
  echo "  Deleting VPC: $VPC_ID"
  aws ec2 delete-vpc --vpc-id "$VPC_ID" --region us-east-1 2>/dev/null || echo "  Could not delete VPC (may have dependencies)"
done

# Delete KMS Keys
echo "10. Scheduling KMS keys for deletion..."
aws kms list-aliases --region us-east-1 --query 'Aliases[?starts_with(AliasName, `alias/eks/pms-dev`)].TargetKeyId' --output text | while read key; do
  if [ ! -z "$key" ]; then
    echo "  Scheduling KMS key for deletion: $key"
    aws kms schedule-key-deletion --key-id "$key" --pending-window-in-days 7 --region us-east-1 2>/dev/null || true
  fi
done

# Delete IAM Policies
echo "11. Deleting IAM Policies..."
aws iam list-policies --scope Local --region us-east-1 --query 'Policies[?contains(PolicyName, `pms-dev`) || contains(PolicyName, `AmazonEKS_EBS_CSI_Policy`) || contains(PolicyName, `AmazonEKS_AWS_Load_Balancer_Controller`)].Arn' --output text | while read policy; do
  if [ ! -z "$policy" ]; then
    echo "  Deleting policy: $policy"
    aws iam delete-policy --policy-arn "$policy" --region us-east-1 2>/dev/null || true
  fi
done

# Delete IAM Roles
echo "12. Deleting IAM Roles..."
aws iam list-roles --region us-east-1 --query 'Roles[?contains(RoleName, `pms-dev`) || contains(RoleName, `general-eks-node-group`)].RoleName' --output text | while read role; do
  if [ ! -z "$role" ]; then
    echo "  Detaching policies from role: $role"
    aws iam list-attached-role-policies --role-name "$role" --region us-east-1 --query 'AttachedPolicies[].PolicyArn' --output text | while read policy; do
      aws iam detach-role-policy --role-name "$role" --policy-arn "$policy" --region us-east-1 2>/dev/null || true
    done
    echo "  Deleting role: $role"
    aws iam delete-role --role-name "$role" --region us-east-1 2>/dev/null || true
  fi
done

echo ""
echo "=== Cleanup Complete ==="
echo "You can now run: terraform plan && terraform apply"
