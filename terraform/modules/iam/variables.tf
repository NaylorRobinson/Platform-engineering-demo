# ══════════════════════════════════════════════════════════════
# IAM MODULE — variables.tf
# ══════════════════════════════════════════════════════════════

variable "project_name" {
  description = "Project name used as a prefix on resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment — dev, staging, or prod"
  type        = string
}

variable "aws_account_id" {
  description = "Your AWS account ID — used to build ARNs for IAM policies"
  type        = string
}

variable "github_repo" {
  description = "GitHub repo in owner/repo format — used to scope the CI/CD role to your repo only"
  type        = string
  default     = "NaylorRobinson/platform-engineering-demo"
}

variable "tf_state_bucket" {
  description = "Name of the S3 bucket storing Terraform state — grants the pipeline access to it"
  type        = string
}

variable "tf_lock_table" {
  description = "Name of the DynamoDB table used for Terraform state locking"
  type        = string
  default     = "platform-demo-tfstate-lock"
}

variable "tags" {
  description = "Tags to apply to all IAM resources"
  type        = map(string)
  default     = {}
}
