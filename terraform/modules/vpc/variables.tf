# ══════════════════════════════════════════════════════════════
# VPC MODULE — variables.tf
# Defines all input parameters the VPC module accepts.
# These are set by the environment config (e.g. environments/dev/main.tf)
# ══════════════════════════════════════════════════════════════

variable "project_name" {
  description = "The name of the project — used as a prefix on all resource names"
  type        = string
}

variable "environment" {
  description = "The deployment environment — dev, staging, or prod"
  type        = string

  # Restrict to known environment values to prevent typos
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC — defines the total IP address space"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of AWS availability zones to deploy subnets into — use at least 2 for HA"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "tags" {
  description = "Map of tags to apply to all resources — must include team, environment, owner to pass OPA policy"
  type        = map(string)
  default     = {}
}
