# ══════════════════════════════════════════════════════════════
# OPA POLICY — tagging.rego
# Every resource must have team, environment, and owner tags.
# ══════════════════════════════════════════════════════════════
package aws.tagging

# The set of tags every resource must have for cost allocation and ownership
required_tags := {"team", "environment", "owner"}

deny contains msg if {
  resource := input.resource_changes[_]
  resource.change.actions[_] == "create"
  resource.change.after != null

  # Build a set of tag keys that exist on this resource
  existing_tags := {tag | resource.change.after.tags[tag]}

  # Set difference — tags that are required but not present
  missing := required_tags - existing_tags

  # Violation: at least one required tag is missing
  count(missing) > 0

  msg := sprintf(
    "TAGGING VIOLATION: '%v' (%v) is missing required tags: %v. Add team, environment, and owner tags.",
    [resource.address, resource.type, missing]
  )
}
