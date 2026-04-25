# ═══════════════════════════════════════════════════════════════
#  modules/ec2/outputs.tf — Task 10
#  Outputs send values FROM the module BACK to main.tf
#  Without this, main.tf can't read the instance ID from the module
# ═══════════════════════════════════════════════════════════════

# Send the instance ID back to main.tf so it can print it as an output
output "instance_id" {
  description = "The ID of the EC2 instance created by this module"
  value       = aws_instance.module_ec2.id
}

# Send the public IP back to main.tf
output "public_ip" {
  description = "The public IP of the EC2 instance created by this module"
  value       = aws_instance.module_ec2.public_ip
}
