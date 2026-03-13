# ══════════════════════════════════════════════════════════════
# SECURITY GROUPS MODULE — main.tf
# Defines who can talk to what inside the VPC.
# These rules are the PRIMARY target of your OPA policies.
# The golden path enforces: no open 0.0.0.0/0 on sensitive ports.
# ══════════════════════════════════════════════════════════════

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ── EKS Cluster Security Group ────────────────────────────────
# Controls traffic to and from the EKS control plane
resource "aws_security_group" "eks_cluster" {
  name        = "${var.project_name}-eks-cluster-sg-${var.environment}"
  description = "Security group for the EKS cluster control plane"
  vpc_id      = var.vpc_id

  # Allow all outbound traffic from the control plane
  # EKS needs to reach AWS APIs, ECR for images, and worker nodes
  egress {
    description = "Allow all outbound traffic from EKS control plane"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"         # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-eks-cluster-sg-${var.environment}"
    # This tag lets EKS know this security group belongs to the cluster
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "owned"
  })
}

# ── EKS Worker Node Security Group ───────────────────────────
# Controls traffic to and from the EC2 instances that run your pods
resource "aws_security_group" "eks_nodes" {
  name        = "${var.project_name}-eks-nodes-sg-${var.environment}"
  description = "Security group for EKS worker nodes"
  vpc_id      = var.vpc_id

  # Allow worker nodes to communicate with each other
  # Required for pod-to-pod communication across nodes
  ingress {
    description = "Allow all traffic between worker nodes in the same cluster"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true         # 'self' means other resources in this same security group
  }

  # Allow the EKS control plane to reach worker nodes
  # Required for kubectl exec, logs, and health checks
  ingress {
    description     = "Allow EKS control plane to communicate with worker nodes"
    from_port       = 1025
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
  }

  # Allow all outbound traffic from worker nodes
  # Nodes need to reach ECR for images, S3, and other AWS services
  egress {
    description = "Allow all outbound traffic from worker nodes"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-eks-nodes-sg-${var.environment}"
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "owned"
  })
}

# ── NOTICE: No SSH (port 22) or RDP (port 3389) rules ─────────
# The OPA networking policy blocks any security group that opens
# port 22 or 3389 to 0.0.0.0/0. This module intentionally excludes
# those rules — access to nodes is handled through AWS Systems Manager
# Session Manager instead, which requires no open inbound ports.
