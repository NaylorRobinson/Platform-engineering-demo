resource "aws_instance" "module_ec2" {
  ami           = "ami-04b4f1a9cf54c11d0"
  instance_type = var.instance_type
  tags = {
    Name = var.instance_name
  }
}