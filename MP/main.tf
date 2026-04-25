# ═══════════════════════════════════════════════════════════════
#  modules/ec2/main.tf — Task 10
#  This is the MODULE file — it defines a reusable EC2 resource
#  Think of a module like a function in Python — write it once,
#  use it as many times as you want from your main.tf
# ═══════════════════════════════════════════════════════════════

# This EC2 resource uses VARIABLES instead of hardcoded values
# The variables are defined in variables.tf and passed in from main.tf
resource "aws_instance" "module_ec2" {
  ami           = "ami-04b4f1a9cf54c11d0"   # Ubuntu 22.04 LTS
  instance_type = var.instance_type          # Comes from variables.tf

  tags = {
    Name = var.instance_name   # Comes from variables.tf
  }
}
