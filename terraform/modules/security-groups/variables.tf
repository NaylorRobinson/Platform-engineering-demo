# ══════════════════════════════════════════════════════════════
# SECURITY GROUPS MODULE — variables.tf
# ══════════════════════════════════════════════════════════════

variable "project_name" {
  description = "Project name used as a prefix on resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment — dev, staging, or prod"
  type        = string
}

variable "vpc_id" {
  description = "The VPC ID where security groups will be created — comes from the VPC module output"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources — must include team, environment, owner for OPA compliance"
  type        = map(string)
  default     = {}
}
