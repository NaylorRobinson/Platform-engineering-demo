# ══════════════════════════════════════════════════════════════
# IAM MODULE — outputs.tf
# Exposes role ARNs that the EKS module needs to reference
# ══════════════════════════════════════════════════════════════

output "eks_cluster_role_arn" {
  description = "ARN of the IAM role for the EKS control plane"
  value       = aws_iam_role.eks_cluster.arn
}

output "eks_nodes_role_arn" {
  description = "ARN of the IAM role for EKS worker nodes"
  value       = aws_iam_role.eks_nodes.arn
}

output "cicd_role_arn" {
  description = "ARN of the IAM role for the CI/CD pipeline"
  value       = aws_iam_role.cicd_pipeline.arn
}
