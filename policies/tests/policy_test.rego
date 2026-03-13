# ══════════════════════════════════════════════════════════════
# OPA POLICY TESTS — policy_test.rego
# Unit tests for all four policy files.
# These confirm policies CATCH violations and PASS compliant configs.
# Run with: conftest verify --policy ./policies
# ══════════════════════════════════════════════════════════════
package aws.tests

# ── TEST: Encryption policy catches unencrypted S3 bucket ─────
# This mock Terraform plan represents an S3 bucket with NO encryption
# The encryption policy should deny this with a violation message
test_encryption_violation if {
  # Build a mock Terraform plan that has an unencrypted S3 bucket
  mock_plan := {
    "resource_changes": [{
      "address": "aws_s3_bucket.bad_bucket",
      "type": "aws_s3_bucket",
      "change": {
        "actions": ["create"],
        # after = the state the resource will be in after apply
        # No server_side_encryption_configuration key = violation
        "after": {
          "bucket": "my-unencrypted-bucket",
          "tags": {"team": "platform", "environment": "dev", "owner": "test"}
        }
      }
    }]
  }

  # Import the encryption package and check it produces at least one denial
  count(data.aws.encryption.deny) > 0 with input as mock_plan
}

# ── TEST: Encryption policy passes compliant S3 bucket ────────
test_encryption_compliant if {
  mock_plan := {
    "resource_changes": [{
      "address": "aws_s3_bucket.good_bucket",
      "type": "aws_s3_bucket",
      "change": {
        "actions": ["create"],
        "after": {
          "bucket": "my-encrypted-bucket",
          # Encryption configuration IS present — should pass
          "server_side_encryption_configuration": [{"rule": [{"apply_server_side_encryption_by_default": [{"sse_algorithm": "AES256"}]}]}],
          "tags": {"team": "platform", "environment": "dev", "owner": "test"}
        }
      }
    }]
  }

  # Count should be 0 — no violations for a compliant resource
  count(data.aws.encryption.deny) == 0 with input as mock_plan
}

# ── TEST: Tagging policy catches missing tags ─────────────────
test_tagging_violation if {
  mock_plan := {
    "resource_changes": [{
      "address": "aws_s3_bucket.untagged_bucket",
      "type": "aws_s3_bucket",
      "change": {
        "actions": ["create"],
        "after": {
          "bucket": "my-bucket",
          # Only has one tag — missing environment and owner
          "tags": {"team": "platform"}
        }
      }
    }]
  }

  count(data.aws.tagging.deny) > 0 with input as mock_plan
}

# ── TEST: Networking policy catches open SSH port ─────────────
test_networking_ssh_violation if {
  mock_plan := {
    "resource_changes": [{
      "address": "aws_security_group.bad_sg",
      "type": "aws_security_group",
      "change": {
        "actions": ["create"],
        "after": {
          "name": "bad-sg",
          "tags": {"team": "platform", "environment": "dev", "owner": "test"},
          # Ingress rule opens SSH (port 22) to the entire internet
          "ingress": [{
            "from_port": 22,
            "to_port": 22,
            "protocol": "tcp",
            "cidr_blocks": ["0.0.0.0/0"],
            "description": "SSH from anywhere — this should be blocked"
          }]
        }
      }
    }]
  }

  count(data.aws.networking.deny) > 0 with input as mock_plan
}

# ── TEST: IAM policy catches wildcard action ──────────────────
test_iam_wildcard_violation if {
  mock_plan := {
    "resource_changes": [{
      "address": "aws_iam_policy.bad_policy",
      "type": "aws_iam_policy",
      "change": {
        "actions": ["create"],
        "after": {
          "name": "bad-policy",
          "tags": {"team": "platform", "environment": "dev", "owner": "test"},
          # Policy document as a JSON string — contains wildcard Action
          "policy": "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"*\",\"Resource\":\"*\"}]}"
        }
      }
    }]
  }

  count(data.aws.iam.deny) > 0 with input as mock_plan
}
