package aws.tagging

required_tags := {"team", "environment", "owner"}

# Resource types that do not support tags in AWS — exclude from tagging check
untaggable_resources := {
  "aws_iam_role_policy_attachment",
  "aws_route_table_association"
}

deny contains msg if {
  resource := input.resource_changes[_]
  resource.change.actions[_] == "create"
  resource.change.after != null

  # Skip resource types that don't support tags
  not untaggable_resources[resource.type]

  existing_tags := {tag | resource.change.after.tags[tag]}
  missing := required_tags - existing_tags
  count(missing) > 0

  msg := sprintf(
    "TAGGING VIOLATION: '%v' (%v) is missing required tags: %v. Add team, environment, and owner tags.",
    [resource.address, resource.type, missing]
  )
}