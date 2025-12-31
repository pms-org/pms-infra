# Example terraform.tfvars for dev environment
# Copy this file to terraform.tfvars and customize

aws_region     = "us-east-1"
cluster_version = "1.28"

# Node configuration
node_instance_types = ["t3.large"]
node_desired_size   = 3
node_min_size       = 2
node_max_size       = 6
