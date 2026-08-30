# =============================================================================
# EKS Cluster Security Group (additional rules)
# =============================================================================
resource "aws_security_group" "eks_cluster" {
  name        = "${local.cluster_name}-cluster-sg"
  description = "Security group for EKS cluster control plane"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.cluster_name}-cluster-sg"
  }
}

resource "aws_security_group_rule" "cluster_ingress_nodes" {
  description              = "Allow worker nodes to communicate with the cluster API server"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_nodes.id
  security_group_id        = aws_security_group.eks_cluster.id
}

resource "aws_security_group_rule" "cluster_egress_all" {
  description       = "Allow cluster egress to the internet"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_cluster.id
}

# =============================================================================
# EKS Node Security Group
# =============================================================================
resource "aws_security_group" "eks_nodes" {
  name        = "${local.cluster_name}-node-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.cluster_name}-node-sg"
  }
}

# Nodes talk to each other
resource "aws_security_group_rule" "nodes_internal" {
  description              = "Allow nodes to communicate with each other"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  source_security_group_id = aws_security_group.eks_nodes.id
  security_group_id        = aws_security_group.eks_nodes.id
}

# Control plane to nodes (kubelet, extensions)
resource "aws_security_group_rule" "nodes_ingress_cluster" {
  description              = "Allow control plane to communicate with worker nodes"
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_cluster.id
  security_group_id        = aws_security_group.eks_nodes.id
}

# Control plane to nodes on 443 (metrics-server, webhook)
resource "aws_security_group_rule" "nodes_ingress_cluster_https" {
  description              = "Allow control plane to reach node HTTPS endpoints"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_cluster.id
  security_group_id        = aws_security_group.eks_nodes.id
}

resource "aws_security_group_rule" "nodes_egress_all" {
  description       = "Allow nodes egress to the internet"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_nodes.id
}

