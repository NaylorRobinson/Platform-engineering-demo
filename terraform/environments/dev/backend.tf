# ══════════════════════════════════════════════════════════════
# BACKEND CONFIG — backend.tf
# Tells Terraform to store state in S3 instead of locally.
# IMPORTANT: Replace YOUR_NAME with your actual name to match
# the bucket you created in Phase 2 of the steps guide.
# ══════════════════════════════════════════════════════════════

terraform {
  backend "s3" {
    # The S3 bucket that holds Terraform state — must already exist (created in Phase 2)
    bucket = "platform-demo-tfstate-YOUR_NAME"

    # The path inside the bucket where this environment's state file is stored
    key = "dev/terraform.tfstate"

    # Must match the region the bucket was created in
    region = "us-east-1"

    # The DynamoDB table that prevents two Terraform runs from conflicting
    dynamodb_table = "platform-demo-tfstate-lock"

    # Encrypt the state file at rest in S3
    encrypt = true
  }
}
