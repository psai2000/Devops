# =============================================================================
# EKS Cluster
# =============================================================================
resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids = concat(
      aws_subnet.private[*].id,
      aws_subnet.public[*].id
    )

    security_group_ids = [aws_security_group.eks_cluster.id]

    endpoint_private_access = var.cluster_endpoint_private_access
    endpoint_public_access  = var.cluster_endpoint_public_access
  }

  # Enable control-plane logging for observability
  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller,
  ]

  tags = {
    Name = local.cluster_name
  }
}

# =============================================================================
# EKS Managed Node Group
# =============================================================================
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${local.cluster_name}-nodes"
  node_role_arn   = aws_iam_role.eks_nodes.arn

  # Place worker nodes in private subnets
  subnet_ids = aws_subnet.private[*].id

  instance_types = var.node_instance_types
  disk_size      = var.node_disk_size
  capacity_type  = "ON_DEMAND"

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role        = "general"
    environment = var.environment
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_readonly,
  ]

  tags = {
    Name = "${local.cluster_name}-nodes"
  }

  # Allow Kubernetes Cluster Autoscaler to manage capacity
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

# =============================================================================
# EKS Add-ons
# =============================================================================

# CoreDNS — cluster DNS resolution
resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.main]
}

# kube-proxy — network rules on nodes
resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.main]
}

# VPC CNI — pod networking
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.main]
}

# EBS CSI Driver — persistent volumes (needed for Prometheus/Grafana)
resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.main]
}

