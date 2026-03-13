# ══════════════════════════════════════════════════════════════
# OPA POLICY — iam.rego
# Blocks IAM policies that use wildcard (*) actions.
# Wildcard actions violate least-privilege and are blocked by default.
# ══════════════════════════════════════════════════════════════
package aws.iam

# Rule 1: Catches wildcard when Action is a single string
deny contains msg if {
  resource := input.resource_changes[_]
  resource.type == "aws_iam_policy"
  resource.change.actions[_] == "create"

  # json.unmarshal parses the policy document string into a queryable object
  policy_doc := json.unmarshal(resource.change.after.policy)
  statement := policy_doc.Statement[_]
  statement.Effect == "Allow"

  # Violation: Action is the string "*" (wildcard)
  statement.Action == "*"

  msg := sprintf(
    "IAM VIOLATION: Policy '%v' uses wildcard (*) Action. Specify explicit actions for least-privilege access.",
    [resource.address]
  )
}

# Rule 2: Catches wildcard when Action is an array
deny contains msg if {
  resource := input.resource_changes[_]
  resource.type == "aws_iam_policy"
  resource.change.actions[_] == "create"

  policy_doc := json.unmarshal(resource.change.after.policy)
  statement := policy_doc.Statement[_]
  statement.Effect == "Allow"

  # Loop over each action in the array — catches ["s3:GetObject", "*"] patterns
  action := statement.Action[_]
  action == "*"

  msg := sprintf(
    "IAM VIOLATION: Policy '%v' contains wildcard (*) in Action array. Replace with specific action names.",
    [resource.address]
  )
}
