# ══════════════════════════════════════════════════════════════
# IAM MODULE — main.tf
# Creates the IAM roles and policies EKS needs to function.
# The OPA IAM policy blocks any wildcard (*) actions.
# All roles here follow least-privilege — only the permissions required.
# ══════════════════════════════════════════════════════════════

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ── EKS Cluster Role ──────────────────────────────────────────
# This role is assumed by the EKS control plane itself.
# It allows EKS to manage AWS resources on your behalf —
# like creating load balancers and managing network interfaces.
resource "aws_iam_role" "eks_cluster" {
  name = "${var.project_name}-eks-cluster-role-${var.environment}"

  # The trust policy defines WHO can assume this role
  # Here we allow the EKS service (eks.amazonaws.com) to assume it
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

# ── Attach AWS managed policy for EKS cluster permissions ─────
# AmazonEKSClusterPolicy is an AWS-managed policy that grants
# the minimum permissions the EKS control plane needs
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ── EKS Node Group Role ───────────────────────────────────────
# This role is assumed by the EC2 instances that are your worker nodes.
# Nodes need permissions to join the cluster and pull container images.
resource "aws_iam_role" "eks_nodes" {
  name = "${var.project_name}-eks-nodes-role-${var.environment}"

  # Allow EC2 instances (the worker nodes) to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

# ── Attach required AWS managed policies for worker nodes ─────

# Allows nodes to join the EKS cluster and be managed by the control plane
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

# Allows nodes to pull container images from Amazon ECR (Elastic Container Registry)
resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# Allows nodes to pull images from ECR — required for core Kubernetes components
resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# ── CI/CD Pipeline Role ───────────────────────────────────────
# This role is assumed by GitHub Actions when running Terraform.
# It has exactly the permissions needed to manage this project — nothing more.
resource "aws_iam_role" "cicd_pipeline" {
  name = "${var.project_name}-cicd-role-${var.environment}"

  # Allow GitHub Actions (via OIDC) to assume this role
  # This is more secure than using long-lived AWS access keys
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${var.aws_account_id}:oidc-provider/token.actions.githubusercontent.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Restrict to your specific GitHub repo — prevents other repos from assuming this role
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
          }
        }
      }
    ]
  })

  tags = var.tags
}

# ── CI/CD Pipeline Policy — least privilege ───────────────────
# Grants only the specific permissions needed to run Terraform for this project.
# Notice: no wildcards (*) in action or resource — this passes the OPA IAM policy check.
resource "aws_iam_policy" "cicd_pipeline" {
  name        = "${var.project_name}-cicd-policy-${var.environment}"
  description = "Least-privilege policy for the CI/CD pipeline to manage platform-engineering-demo resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Allow the pipeline to read and write Terraform state in S3
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.tf_state_bucket}",
          "arn:aws:s3:::${var.tf_state_bucket}/*"
        ]
      },
      {
        # Allow the pipeline to lock and unlock Terraform state in DynamoDB
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:us-east-1:${var.aws_account_id}:table/${var.tf_lock_table}"
      },
      {
        # Allow the pipeline to manage EKS clusters
        Effect = "Allow"
        Action = [
          "eks:CreateCluster",
          "eks:DeleteCluster",
          "eks:DescribeCluster",
          "eks:UpdateClusterConfig",
          "eks:CreateNodegroup",
          "eks:DeleteNodegroup",
          "eks:DescribeNodegroup"
        ]
        Resource = "arn:aws:eks:us-east-1:${var.aws_account_id}:cluster/${var.project_name}-*"
      }
    ]
  })

  tags = var.tags
}

# ── Attach the CI/CD policy to the CI/CD role ─────────────────
resource "aws_iam_role_policy_attachment" "cicd_pipeline" {
  role       = aws_iam_role.cicd_pipeline.name
  policy_arn = aws_iam_policy.cicd_pipeline.arn
}
