# ══════════════════════════════════════════════════════════════
# OPA POLICY — encryption.rego
# Blocks S3 buckets created without server-side encryption.
# ══════════════════════════════════════════════════════════════
package aws.encryption

deny[msg] {
  # Loop over every resource change in the Terraform plan
  resource := input.resource_changes[_]

  # Only evaluate S3 bucket resources
  resource.type == "aws_s3_bucket"

  # Only check resources being created
  resource.change.actions[_] == "create"

  # Violation: no encryption configuration block present
  not resource.change.after.server_side_encryption_configuration

  # Error message shown in the PR comment bot
  msg := sprintf(
    "ENCRYPTION VIOLATION: S3 bucket '%v' must have server_side_encryption_configuration. Add aws_s3_bucket_server_side_encryption_configuration.",
    [resource.address]
  )
}
