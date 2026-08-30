# =============================================================================
# Data Sources
# =============================================================================

# Current AWS account and caller identity
data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

# Fetch the latest Amazon Linux 2 EKS-optimized AMI (informational)
data "aws_ssm_parameter" "eks_ami" {
  name = "/aws/service/eks/optimized-ami/${var.cluster_version}/amazon-linux-2/recommended/image_id"
}

