package aws.networking

deny contains msg if {
  r := input.resource_changes[_]
  r.type == "aws_security_group"
  r.change.actions[_] == "create"
  r.change.after.ingress[_].cidr_blocks[_] == "0.0.0.0/0"
  r.change.after.ingress[_].from_port <= 22
  r.change.after.ingress[_].to_port >= 22
  msg := sprintf("NETWORKING VIOLATION: '%v' allows SSH (port 22) from 0.0.0.0/0.", [r.address])
}