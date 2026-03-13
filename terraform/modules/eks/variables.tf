# ══════════════════════════════════════════════════════════════
# EKS MODULE — variables.tf
# ══════════════════════════════════════════════════════════════

variable "project_name" {
  description = "Project name prefix for all EKS resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment — dev, staging, or prod"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.29"
}

variable "cluster_role_arn" {
  description = "ARN of the IAM role for the EKS control plane — comes from the IAM module output"
  type        = string
}

variable "node_role_arn" {
  description = "ARN of the IAM role for worker nodes — comes from the IAM module output"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for worker nodes — comes from the VPC module output"
  type        = list(string)
}

variable "cluster_sg_id" {
  description = "Security group ID for the EKS cluster — comes from the security-groups module output"
  type        = string
}

variable "node_instance_type" {
  description = "EC2 instance type for worker nodes — t3.medium is the minimum recommended"
  type        = string
  default     = "t3.medium"
}

variable "node_disk_size" {
  description = "EBS disk size in GB for each worker node"
  type        = number
  default     = 20
}

variable "node_min_size" {
  description = "Minimum number of worker nodes — keeps at least this many running at all times"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes — auto-scaler will not exceed this"
  type        = number
  default     = 3
}

variable "node_desired_size" {
  description = "Desired number of worker nodes at startup"
  type        = number
  default     = 2
}

variable "tags" {
  description = "Tags to apply to all EKS resources"
  type        = map(string)
  default     = {}
}
