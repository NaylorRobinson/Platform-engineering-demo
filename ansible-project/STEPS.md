# ═══════════════════════════════════════════════════════════════
#  ANSIBLE PROJECT — STEP BY STEP GUIDE
#  Follow these steps IN ORDER after terraform apply finishes
# ═══════════════════════════════════════════════════════════════

# ── STEP 1: Deploy infrastructure with Terraform ────────────────
# Run these in PowerShell from your ansible-project folder

    terraform init
    terraform plan
    terraform apply

# After apply finishes, copy down the 4 IP addresses printed in the output:
#   web1_public_ip
#   web2_public_ip
#   web3_public_ip
#   main_control_public_ip

# ── STEP 2: SSH into the Main Control Node ──────────────────────
# Use PuTTY or PowerShell to SSH in with your GameKeys.pem
# Replace MAIN_IP with your main_control_public_ip

    ssh -i "GameKeys.pem" ubuntu@MAIN_IP

# ── STEP 3: Upload your GameKeys.pem to the Main Control Node ───
# Ansible needs the key to SSH from the main server into the web servers
# Run this in PowerShell on your LOCAL machine (not inside SSH):

    scp -i "GameKeys.pem" "GameKeys.pem" ubuntu@MAIN_IP:/home/ubuntu/

# Then fix the permissions on the key (run this INSIDE the SSH session):

    chmod 400 ~/GameKeys.pem

# ── STEP 4: Verify Ansible installed correctly ──────────────────
# Run this inside the Main Control Node SSH session:

    ansible --version

# Screenshot this output for Task 4 proof

# ── STEP 5: Create the inventory file ───────────────────────────
# Run this inside the Main Control Node SSH session:

    nano inventory.ini

# Paste this content and replace the IPs with your actual web server IPs:
# ─────────────────────────────────────────────
# [webservers]
# YOUR_WEB1_IP
# YOUR_WEB2_IP
# YOUR_WEB3_IP
#
# [webservers:vars]
# ansible_user=ubuntu
# ansible_ssh_private_key_file=~/GameKeys.pem
# ansible_ssh_common_args='-o StrictHostKeyChecking=no'
# ─────────────────────────────────────────────
# Press Ctrl+O to save, Ctrl+X to exit
# Screenshot this for Task 3 proof

# ── STEP 6: Create the playbook ─────────────────────────────────
# Run this inside the Main Control Node SSH session:

    nano playbook.yml

# Paste the contents of playbook.yml into nano
# Press Ctrl+O to save, Ctrl+X to exit

# ── STEP 7: Run the playbook ────────────────────────────────────
# This installs NGINX on all 3 web servers simultaneously

    ansible-playbook -i inventory.ini playbook.yml

# Screenshot the output for Task 5 proof

# ── STEP 8: Verify NGINX is running ─────────────────────────────
# SSH into one of the web servers to confirm NGINX is running
# Run this inside the Main Control Node:

    ssh -i ~/GameKeys.pem ubuntu@YOUR_WEB1_IP

# Then run:
    systemctl status nginx

# Screenshot this for Task 5 proof
# Type exit to leave the web server and go back to main control node
