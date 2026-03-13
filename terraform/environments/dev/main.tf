# ══════════════════════════════════════════════════════════════
# DEV ENVIRONMENT — main.tf
# Wires all four modules together to create the full
# platform stack in the dev environment.
# This is the entry point — 'terraform apply' runs from here.
# ══════════════════════════════════════════════════════════════

terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ── AWS Provider — sets the default region ────────────────────
provider "aws" {
  region = "us-east-1"

  # Apply these default tags to every resource Terraform creates
  # This ensures all resources pass the OPA tagging policy
  default_tags {
    tags = {
      project     = "platform-engineering-demo"
      environment = "dev"
      team        = "platform"
      owner       = "naylor.robinson"
      managed_by  = "terraform"
    }
  }
}

# ── Layer 1: VPC — the network foundation ─────────────────────
# Creates the VPC, subnets, NAT gateway, and routing
module "vpc" {
  # Path to the VPC module — relative to this file
  source = "../../modules/vpc"

  project_name       = "platform-demo"
  environment        = "dev"
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]

  tags = {
    team        = "platform"
    environment = "dev"
    owner       = "naylor.robinson"
  }
}

# ── Layer 2: IAM — roles and permissions ──────────────────────
# Creates IAM roles for EKS and the CI/CD pipeline
module "iam" {
  source = "../../modules/iam"

  project_name    = "platform-demo"
  environment     = "dev"
  aws_account_id  = var.aws_account_id
  github_repo     = "NaylorRobinson/platform-engineering-demo"
  tf_state_bucket = "platform-demo-tfstate-YOUR_NAME"

  tags = {
    team        = "platform"
    environment = "dev"
    owner       = "naylor.robinson"
  }
}

# ── Layer 3: Security Groups — network access rules ───────────
# Creates security groups for EKS — depends on the VPC being created first
module "security_groups" {
  source = "../../modules/security-groups"

  project_name = "platform-demo"
  environment  = "dev"

  # Reference the VPC ID from the VPC module output
  vpc_id = module.vpc.vpc_id

  tags = {
    team        = "platform"
    environment = "dev"
    owner       = "naylor.robinson"
  }
}

# ── Layer 4: EKS — the Kubernetes cluster ─────────────────────
# Creates the EKS cluster and worker nodes — depends on VPC, IAM, and security groups
module "eks" {
  source = "../../modules/eks"

  project_name = "platform-demo"
  environment  = "dev"

  # Reference IAM role ARNs from the IAM module outputs
  cluster_role_arn = module.iam.eks_cluster_role_arn
  node_role_arn    = module.iam.eks_nodes_role_arn

  # Reference subnet IDs from the VPC module outputs
  private_subnet_ids = module.vpc.private_subnet_ids

  # Reference security group ID from the security-groups module output
  cluster_sg_id = module.security_groups.eks_cluster_sg_id

  # Keep costs low in dev — minimal node configuration
  node_instance_type = "t3.medium"
  node_min_size      = 1
  node_max_size      = 2
  node_desired_size  = 1

  tags = {
    team        = "platform"
    environment = "dev"
    owner       = "naylor.robinson"
  }
}
# INTENTIONAL VIOLATION — security group open to the internet on port 22
# This should be caught and blocked by networking.rego
resource "aws_security_group" "bad_example" {
  name        = "bad-sg-open-ssh"
  description = "Intentionally bad security group for demo"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH open to the world - intentional violation"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


}