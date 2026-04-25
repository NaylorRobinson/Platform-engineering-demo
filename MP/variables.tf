# ═══════════════════════════════════════════════════════════════
#  modules/ec2/variables.tf — Task 10
#  Variables are the INPUTS to the module
#  They make the module flexible — instead of hardcoding values,
#  you pass them in from main.tf so the module can be reused
#  with different values each time
# ═══════════════════════════════════════════════════════════════

# This variable controls what size server the module creates
# When main.tf calls the module it passes in instance_type = "t2.micro"
variable "instance_type" {
  description = "The EC2 instance type — controls the size of the server"
  type        = string
  default     = "t2.micro"   # Default value if nothing is passed in
}

# This variable controls what name tag appears on the EC2 in AWS console
variable "instance_name" {
  description = "The name tag to apply to the EC2 instance"
  type        = string
  default     = "module-ec2"   # Default name if nothing is passed in
}
