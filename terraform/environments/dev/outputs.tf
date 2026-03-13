# ══════════════════════════════════════════════════════════════
# DEV ENVIRONMENT — outputs.tf
# Values printed after 'terraform apply' completes
# ══════════════════════════════════════════════════════════════

output "vpc_id" {
  description = "VPC ID — useful for debugging network issues"
  value       = module.vpc.vpc_id
}

output "eks_cluster_name" {
  description = "EKS cluster name — use this with kubectl and the MCP server"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS API server endpoint — used by kubectl to communicate with the cluster"
  value       = module.eks.cluster_endpoint
}
