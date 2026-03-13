# ══════════════════════════════════════════════════════════════
# DEV ENVIRONMENT — variables.tf
# ══════════════════════════════════════════════════════════════

variable "aws_account_id" {
  description = "Your 12-digit AWS account ID — find it in the AWS console under your account name"
  type        = string
  sensitive   = true
}
