resource "aws_eks_cluster" "dashboard_eks" {
  name     = "${var.name_prefix}-eks"
  role_arn = var.eks_role_arn

  vpc_config {
    subnet_ids = var.subnets
  }
}

resource "aws_eks_node_group" "dashboard_node_group" {
  cluster_name    = aws_eks_cluster.dashboard_eks.name
  node_group_name = "${var.name_prefix}-node-group"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnets

  scaling_config {
    desired_size = 3
    max_size     = 5
    min_size     = 2
  }

  instance_types = ["t3.medium"]
}
