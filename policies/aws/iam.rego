# ══════════════════════════════════════════════════════════════
# OPA POLICY — iam.rego
# Blocks IAM policies that use wildcard (*) actions.
# Wildcard actions violate least-privilege and are blocked by default.
# ══════════════════════════════════════════════════════════════
package aws.iam

deny contains msg if {
  resource := input.resource_changes[_]
  resource.type == "aws_iam_policy"
  resource.change.actions[_] == "create"

  policy_doc := json.unmarshal(resource.change.after.policy)
  statement := policy_doc.Statement[_]
  statement.Effect == "Allow"
  statement.Action == "*"

  msg := sprintf(
    "IAM VIOLATION: Policy '%v' uses wildcard (*) Action. Specify explicit actions for least-privilege access.",
    [resource.address]
  )
}
