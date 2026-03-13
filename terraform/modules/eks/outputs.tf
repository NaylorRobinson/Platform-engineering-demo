# ══════════════════════════════════════════════════════════════
# EKS MODULE — outputs.tf
# ══════════════════════════════════════════════════════════════

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "The API server endpoint URL for the EKS cluster"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_version" {
  description = "The Kubernetes version running on the cluster"
  value       = aws_eks_cluster.main.version
}

output "cluster_arn" {
  description = "The ARN of the EKS cluster — used for IAM policy scoping"
  value       = aws_eks_cluster.main.arn
}
