# ══════════════════════════════════════════════════════════════
# OPA POLICY — networking.rego
# Blocks security groups that open port 22 (SSH) or 3389 (RDP)
# to the entire internet (0.0.0.0/0).
# ══════════════════════════════════════════════════════════════
package aws.networking

# Ports that must never be open to the internet
sensitive_ports := {22, 3389}

deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_security_group"
  resource.change.actions[_] == "create"

  # Loop over every ingress rule
  ingress := resource.change.after.ingress[_]

  # Check if this rule opens to the entire internet
  ingress.cidr_blocks[_] == "0.0.0.0/0"

  # Check if a sensitive port falls within the port range of this rule
  port := sensitive_ports[_]
  ingress.from_port <= port
  ingress.to_port >= port

  msg := sprintf(
    "NETWORKING VIOLATION: Security group '%v' opens port %v to 0.0.0.0/0. Use AWS Systems Manager Session Manager instead.",
    [resource.address, port]
  )
}
