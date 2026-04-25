# ═══════════════════════════════════════════════════════════════
#  TERRAFORM + ANSIBLE PROJECT — main.tf
#  This script creates 4 EC2 instances:
#    - 1 Main Control Node (runs Ansible)
#    - 3 Web Servers (will have NGINX installed by Ansible)
# ═══════════════════════════════════════════════════════════════

# ── PROVIDER ────────────────────────────────────────────────────
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ════════════════════════════════════════════════════════════════
#  SECURITY GROUP
#  This controls what traffic is allowed in and out of our servers
#  We need:
#    - Port 22 (SSH) so Ansible can talk to the web servers
#    - Port 80 (HTTP) so people can visit the web servers
#    - Port 443 (HTTPS) for secure web traffic
# ════════════════════════════════════════════════════════════════

resource "aws_security_group" "ansible_sg" {
  name        = "ansible-project-sg"
  description = "Security group for Ansible + NGINX project"

  # SSH — needed for Ansible to connect from main server to web servers
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP — so web traffic can reach the NGINX web servers
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS — secure web traffic
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic so servers can download packages
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ansible-project-sg"
  }
}

# ════════════════════════════════════════════════════════════════
#  TASK 1 — THREE WEB SERVER EC2 INSTANCES
#  These are the servers Ansible will manage
#  NGINX will be installed on all three by the Ansible playbook
# ════════════════════════════════════════════════════════════════

# Web Server 1
resource "aws_instance" "web1" {
  ami                    = "ami-04b4f1a9cf54c11d0"   # Ubuntu 22.04 LTS
  instance_type          = "t2.micro"                 # Free tier eligible
  key_name               = "GameKeys"                 # Your key pair for SSH access
  vpc_security_group_ids = [aws_security_group.ansible_sg.id]

  tags = {
    Name = "WebServer1"
  }
}

# Web Server 2
resource "aws_instance" "web2" {
  ami                    = "ami-04b4f1a9cf54c11d0"
  instance_type          = "t2.micro"
  key_name               = "GameKeys"
  vpc_security_group_ids = [aws_security_group.ansible_sg.id]

  tags = {
    Name = "WebServer2"
  }
}

# Web Server 3
resource "aws_instance" "web3" {
  ami                    = "ami-04b4f1a9cf54c11d0"
  instance_type          = "t2.micro"
  key_name               = "GameKeys"
  vpc_security_group_ids = [aws_security_group.ansible_sg.id]

  tags = {
    Name = "WebServer3"
  }
}

# ════════════════════════════════════════════════════════════════
#  TASK 2 — MAIN CONTROL NODE
#  This is the server you will SSH into and run Ansible FROM
#  It controls all three web servers
#  user_data installs Ansible automatically on first boot
# ════════════════════════════════════════════════════════════════

resource "aws_instance" "main_control" {
  ami                    = "ami-04b4f1a9cf54c11d0"   # Ubuntu 22.04 LTS
  instance_type          = "t2.micro"
  key_name               = "GameKeys"
  vpc_security_group_ids = [aws_security_group.ansible_sg.id]

  # This script runs automatically when the instance first boots
  # It installs Ansible so it's ready when you SSH in
  user_data = base64encode(join("\n", [
    "#!/bin/bash",
    "# Update the package list",
    "apt-get update -y",
    "# Install software-properties-common needed to add Ansible repo",
    "apt-get install -y software-properties-common",
    "# Add the official Ansible repository",
    "add-apt-repository --yes --update ppa:ansible/ansible",
    "# Install Ansible",
    "apt-get install -y ansible",
    "# Install nano so you can edit files easily",
    "apt-get install -y nano",
    "echo 'Ansible installation complete' > /home/ubuntu/ansible_ready.txt",
  ]))

  tags = {
    Name = "MainControlNode"
  }
}

# ════════════════════════════════════════════════════════════════
#  OUTPUTS
#  These print the IP addresses after terraform apply finishes
#  You will need the web server IPs for the inventory.ini file
#  You will need the main control node IP to SSH into it
# ════════════════════════════════════════════════════════════════

output "web1_public_ip" {
  description = "Public IP of Web Server 1 — add to inventory.ini"
  value       = aws_instance.web1.public_ip
}

output "web2_public_ip" {
  description = "Public IP of Web Server 2 — add to inventory.ini"
  value       = aws_instance.web2.public_ip
}

output "web3_public_ip" {
  description = "Public IP of Web Server 3 — add to inventory.ini"
  value       = aws_instance.web3.public_ip
}

output "main_control_public_ip" {
  description = "Public IP of Main Control Node — SSH into this one first"
  value       = aws_instance.main_control.public_ip
}
