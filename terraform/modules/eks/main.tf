# ══════════════════════════════════════════════════════════════
# EKS MODULE — main.tf
# The compute layer — a managed Kubernetes cluster where
# containerized workloads run. Uses private subnets for nodes
# so worker instances are not directly exposed to the internet.
# ══════════════════════════════════════════════════════════════

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ── EKS Cluster — the Kubernetes control plane ────────────────
resource "aws_eks_cluster" "main" {
  name    = "${var.project_name}-${var.environment}"
  version = var.kubernetes_version
  role_arn = var.cluster_role_arn

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [var.cluster_sg_id]
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  # Captures API server, audit, authenticator, controller, and scheduler logs
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = merge(var.tags, {
    Name = "${var.project_name}-eks-${var.environment}"
  })
}

# ── EKS Node Group — the EC2 worker nodes ────────────────────
# AWS manages node lifecycle — patching and replacing unhealthy nodes
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-nodes-${var.environment}"
  node_role_arn   = var.node_role_arn

  # Worker nodes run in private subnets — no direct internet exposure
  subnet_ids = var.private_subnet_ids

  # t3.medium = 2 vCPU, 4GB RAM — minimum recommended for EKS workloads
  instance_types = [var.node_instance_type]

  # Disk size per worker node in GB
  disk_size = var.node_disk_size

  scaling_config {
    min_size     = var.node_min_size
    max_size     = var.node_max_size
    desired_size = var.node_desired_size
  }

  # Only 1 node can be unavailable at a time during rolling updates
  update_config {
    max_unavailable = 1
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-node-group-${var.environment}"
  })
}
