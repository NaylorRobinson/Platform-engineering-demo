#!/bin/bash
# ==========================
# bootstrap.sh
# ==========================
# This script creates the S3 bucket and DynamoDB table that Terraform needs
# to store its state remotely. This solves the chicken-and-egg problem:
# Terraform needs somewhere to store state before it can manage resources,
# so we create these two resources manually via AWS CLI first.
#
# Run this script ONCE before running any Terraform commands.
# After this runs, never run it again - it will error if resources exist.
# ==========================

set -e  # Exit immediately if any command fails

# ==========================
# Configuration
# ==========================
# AWS region where state bucket will live - must match your terraform config
AWS_REGION="us-east-1"

# S3 bucket name for Terraform state - must be globally unique across all AWS
# We append account ID to ensure uniqueness
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
STATE_BUCKET="golden-path-terraform-state-${AWS_ACCOUNT_ID}"

# DynamoDB table name for state locking
# Prevents two people running terraform apply at the same time
LOCK_TABLE="golden-path-terraform-locks"

echo "========================================="
echo "Golden Path Platform - Bootstrap Script"
echo "========================================="
echo "AWS Account: ${AWS_ACCOUNT_ID}"
echo "Region:      ${AWS_REGION}"
echo "S3 Bucket:   ${STATE_BUCKET}"
echo "DynamoDB:    ${LOCK_TABLE}"
echo ""

# ==========================
# Step 1: Create S3 Bucket for Terraform State
# ==========================
echo "Creating S3 bucket for Terraform state..."

# Create the S3 bucket - this is where terraform.tfstate will live
aws s3api create-bucket \
  --bucket "${STATE_BUCKET}" \
  --region "${AWS_REGION}" \
  2>/dev/null || echo "Bucket may already exist, continuing..."

# Enable versioning on the bucket so we can recover previous state files
# This is critical - if state gets corrupted you can roll back
aws s3api put-bucket-versioning \
  --bucket "${STATE_BUCKET}" \
  --versioning-configuration Status=Enabled

# Block all public access - state files contain sensitive infrastructure details
aws s3api put-public-access-block \
  --bucket "${STATE_BUCKET}" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Enable server-side encryption on the bucket using AES256
# All state files will be encrypted at rest automatically
aws s3api put-bucket-encryption \
  --bucket "${STATE_BUCKET}" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

echo "S3 bucket created and configured successfully"

# ==========================
# Step 2: Create DynamoDB Table for State Locking
# ==========================
echo "Creating DynamoDB table for Terraform state locking..."

# Create the DynamoDB table - Terraform writes a lock entry here during apply
# This prevents two engineers from running terraform apply at the same time
# which would corrupt the state file
aws dynamodb create-table \
  --table-name "${LOCK_TABLE}" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "${AWS_REGION}" \
  2>/dev/null || echo "DynamoDB table may already exist, continuing..."

echo "DynamoDB table created successfully"

# ==========================
# Step 3: Create AWS Budget Alert
# ==========================
echo "Creating AWS budget alert at $45..."

# Create a monthly budget that emails you if spending exceeds $45
# This protects against accidentally leaving expensive resources running
aws budgets create-budget \
  --account-id "${AWS_ACCOUNT_ID}" \
  --budget '{
    "BudgetName": "golden-path-platform-budget",
    "BudgetLimit": {
      "Amount": "45",
      "Unit": "USD"
    },
    "BudgetType": "COST",
    "TimeUnit": "MONTHLY"
  }' \
  --notifications-with-subscribers '[{
    "Notification": {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 80,
      "ThresholdType": "PERCENTAGE"
    },
    "Subscribers": [{
      "SubscriptionType": "EMAIL",
      "Address": "YOUR_EMAIL_HERE"
    }]
  }]' \
  2>/dev/null || echo "Budget may already exist, continuing..."

echo "Budget alert created"

# ==========================
# Step 4: Output backend config for Terraform
# ==========================
echo ""
echo "========================================="
echo "Bootstrap Complete!"
echo "========================================="
echo ""
echo "Add the following backend configuration to your Terraform files:"
echo ""
echo "  terraform {"
echo "    backend \"s3\" {"
echo "      bucket         = \"${STATE_BUCKET}\""
echo "      key            = \"dev/terraform.tfstate\""
echo "      region         = \"${AWS_REGION}\""
echo "      dynamodb_table = \"${LOCK_TABLE}\""
echo "      encrypt        = true"
echo "    }"
echo "  }"
echo ""
echo "IMPORTANT: Save the bucket name above - you will need it in your terraform config"
echo "Bucket name: ${STATE_BUCKET}"
