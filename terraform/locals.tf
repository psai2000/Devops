locals {
  cluster_name = "${var.project_name}-${var.environment}-eks"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

