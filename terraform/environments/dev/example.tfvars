# ==========================
# example.tfvars
# ==========================
# This file is a SAFE TEMPLATE showing what values go in terraform.tfvars
# Copy this file to terraform.tfvars and fill in your actual values
# terraform.tfvars is gitignored - NEVER commit real credentials or account IDs
# ==========================

aws_region         = "us-east-1"
environment        = "dev"
team               = "platform-engineering"
owner              = "your.email@example.com"  # Replace with your email
vpc_cidr           = "10.0.0.0/16"
private_subnets    = ["10.0.1.0/24", "10.0.2.0/24"]
public_subnets     = ["10.0.101.0/24", "10.0.102.0/24"]
cluster_name       = "golden-path-dev"
node_instance_type = "t3.medium"
node_desired_count = 2
