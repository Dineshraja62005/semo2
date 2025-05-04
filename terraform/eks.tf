# Simulated EKS configuration for AWS Learner Lab
# This file attempts to create EKS resources but includes fallback mechanisms
# for when IAM permissions are restricted

locals {
  # This variable controls whether we try to create actual EKS resources
  # Set to false to completely skip EKS creation attempts
  attempt_eks = false
}

# Null resource to create a simulation of EKS resources
resource "null_resource" "eks_simulation" {
  count = local.attempt_eks ? 0 : 1

  provisioner "local-exec" {
    command = "echo 'Simulating EKS cluster creation. In a real environment with proper IAM permissions, an EKS cluster would be created.'"
  }

  # Add tags for documentation
  triggers = {
    simulated_cluster_name = var.cluster_name
    simulated_k8s_version  = "1.27"
    simulation_reason      = "AWS Learner Lab IAM restrictions"
  }
}

# Only attempt to create these resources if attempt_eks is true
# IAM Role for EKS Cluster
resource "aws_iam_role" "eks_cluster" {
  count = local.attempt_eks ? 1 : 0
  name  = "${var.project_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  lifecycle {
    ignore_changes = all
  }
}

# Attach required policies to EKS cluster role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  count      = local.attempt_eks ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster[0].name
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  count    = local.attempt_eks ? 1 : 0
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster[0].arn
  version  = "1.27"

  vpc_config {
    subnet_ids = aws_subnet.public[*].id
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

# IAM Role for EKS Node Group
resource "aws_iam_role" "eks_nodes" {
  count = local.attempt_eks ? 1 : 0
  name  = "${var.project_name}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach required policies to EKS node role
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  count      = local.attempt_eks ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes[0].name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  count      = local.attempt_eks ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes[0].name
}

resource "aws_iam_role_policy_attachment" "ec2_container_registry_read" {
  count      = local.attempt_eks ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes[0].name
}

# EKS Node Group
resource "aws_eks_node_group" "main" {
  count           = local.attempt_eks ? 1 : 0
  cluster_name    = aws_eks_cluster.main[0].name
  node_group_name = "${var.project_name}-node-group"
  node_role_arn   = aws_iam_role.eks_nodes[0].arn
  subnet_ids      = aws_subnet.public[*].id
  instance_types  = ["t3.medium"]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ec2_container_registry_read
  ]
}

# Output EKS cluster name for documentation
output "eks_cluster_name" {
  value = local.attempt_eks ? (length(aws_eks_cluster.main) > 0 ? aws_eks_cluster.main[0].name : "failed-to-create") : "java-app-cluster-simulated"
}

# Output EKS cluster endpoint for documentation
output "eks_cluster_endpoint" {
  value = local.attempt_eks ? (length(aws_eks_cluster.main) > 0 ? aws_eks_cluster.main[0].endpoint : "not-available") : "https://eks.${var.aws_region}.amazonaws.com/simulated-endpoint"
}