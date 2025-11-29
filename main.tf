terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  # Uses AWS_PROFILE=personal-tunnel-manager set by up.sh/down.sh
}

# Find the latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Reference your existing security group by name
data "aws_security_group" "tunnel_sg" {
  name = var.security_group_name
}

# User data script to configure sshd on port 443 ONLY
# This runs via cloud-init on first boot - no SSH access needed!
locals {
  user_data = <<-EOF
    #!/bin/bash
    set -ex
    
    # Configure sshd to listen ONLY on port 443 (not 22)
    echo "Port 443" > /etc/ssh/sshd_config.d/99-port443.conf
    
    # Restart sshd to apply
    systemctl restart sshd
    
    # Auto-terminate after ${var.auto_shutdown_hours} hours (safety net)
    nohup bash -c "sleep $((${var.auto_shutdown_hours} * 3600)) && sudo shutdown -h now" &>/dev/null &
  EOF
}

# The tunnel instance - t3.nano is the cheapest general purpose
resource "aws_instance" "tunnel" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [data.aws_security_group.tunnel_sg.id]
  key_name               = var.key_name

  # When instance shuts itself down, terminate it (don't just stop)
  instance_initiated_shutdown_behavior = "terminate"

  user_data = local.user_data

  tags = {
    Name = "cafe-tunnel"
  }
}

# Output the public IP
output "tunnel_ip" {
  value       = aws_instance.tunnel.public_ip
  description = "Public IP of the tunnel instance"
}

output "instance_id" {
  value       = aws_instance.tunnel.id
  description = "Instance ID for status checks"
}

