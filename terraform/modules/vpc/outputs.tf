# ══════════════════════════════════════════════════════════════
# VPC MODULE — outputs.tf
# Exposes values from this module that other modules need.
# The EKS module references vpc_id and subnet IDs from here.
# ══════════════════════════════════════════════════════════════

output "vpc_id" {
  description = "The ID of the VPC — referenced by security groups and EKS"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs — used for load balancers and NAT gateways"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs — EKS worker nodes run in these subnets"
  value       = aws_subnet.private[*].id
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC — referenced by security group rules"
  value       = aws_vpc.main.cidr_block
}
