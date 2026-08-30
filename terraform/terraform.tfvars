# =============================================================================
# Override default variable values here
# =============================================================================
project_name = "lucidity"
environment  = "dev"
aws_region   = "ap-south-1"

# Networking
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["ap-south-1a", "ap-south-1b"]
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24"]

# EKS
cluster_version = "1.30"

# Node Group — tune for your workload
node_instance_types = ["t3.medium"]
node_desired_size   = 2
node_min_size       = 1
node_max_size       = 5
node_disk_size      = 30

tags = {
  Assignment = "lucidity-devops"
}

