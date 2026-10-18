terraform {
  required_version = ">= 1.7.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "terraform-nginx-ubuntu"
      ManagedBy = "Terraform"
    }
  }
}

# Read existing networking; do not create or take ownership of the default VPC.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }

  lifecycle {
    postcondition {
      condition     = length(self.ids) > 0
      error_message = "This region needs an existing default subnet in its default VPC."
    }
  }
}

# Canonical's official Ubuntu 20.04 LTS x86_64 image for the selected region.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_security_group" "nginx" {
  name_prefix = "terraform-nginx-ubuntu-"
  description = "Public HTTP and configurable SSH access"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP for the assignment web page"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from the configured IPv4 range"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  # Package installation needs outbound access to Ubuntu repositories.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "terraform-nginx-ubuntu-sg" }
}

resource "aws_instance" "nginx" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = sort(data.aws_subnets.default.ids)[0]
  vpc_security_group_ids      = [aws_security_group.nginx.id]
  associate_public_ip_address = true
  key_name                    = var.key_name
  user_data_replace_on_change = true

  user_data = <<-USER_DATA
    #!/bin/bash
    set -euxo pipefail
    export DEBIAN_FRONTEND=noninteractive

    apt-get -o Acquire::Retries=5 update
    apt-get -o Acquire::Retries=5 install -y nginx

    cat > /var/www/html/index.html <<'HTML'
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>Terraform-managed Nginx Server</title>
    </head>
    <body>
      <h1>Welcome to the Terraform-managed Nginx Server on Ubuntu</h1>
    </body>
    </html>
    HTML

    rm -f /var/www/html/index.nginx-debian.html
    chmod 644 /var/www/html/index.html
    nginx -t
    systemctl enable --now nginx
    systemctl is-active --quiet nginx
    grep -Fq 'Welcome to the Terraform-managed Nginx Server on Ubuntu' /var/www/html/index.html
  USER_DATA

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true
    delete_on_termination = true
    tags                  = { Name = "terraform-nginx-ubuntu-root" }
  }

  tags = { Name = "terraform-nginx-ubuntu" }
}
