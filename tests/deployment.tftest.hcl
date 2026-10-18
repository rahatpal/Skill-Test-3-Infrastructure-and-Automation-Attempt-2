# Local author checks only; mocks never contact AWS or launch an instance.
mock_provider "aws" {
  override_data {
    target = data.aws_vpc.default
    values = { id = "vpc-test" }
  }
  override_data {
    target = data.aws_subnets.default
    values = { ids = ["subnet-b", "subnet-a"] }
  }
  override_data {
    target = data.aws_ami.ubuntu
    values = { id = "ami-test" }
  }
}

variables {
  key_name = "existing-test-key"
}

run "assignment_contract" {
  command = plan
  variables {
    ssh_cidr = "203.0.113.10/32"
  }

  assert {
    condition     = aws_instance.nginx.instance_type == "t3.micro" && aws_instance.nginx.ami == "ami-test"
    error_message = "Use t3.micro and the selected Ubuntu image."
  }
  assert {
    condition     = aws_instance.nginx.subnet_id == "subnet-a" && aws_instance.nginx.associate_public_ip_address
    error_message = "Use an existing default subnet with a public IP."
  }
  assert {
    condition     = aws_security_group.nginx.vpc_id == "vpc-test" && length(aws_security_group.nginx.ingress) == 2
    error_message = "Use the default VPC and exactly two inbound rules."
  }
  assert {
    condition = alltrue([
      for rule in aws_security_group.nginx.ingress : rule.protocol == "tcp" && (
        (rule.from_port == 80 && rule.to_port == 80 && toset(rule.cidr_blocks) == toset(["0.0.0.0/0"])) ||
        (rule.from_port == 22 && rule.to_port == 22 && toset(rule.cidr_blocks) == toset([var.ssh_cidr]))
      )
    ])
    error_message = "Allow public HTTP and SSH only from the configured host."
  }
  assert {
    condition     = aws_instance.nginx.root_block_device[0].delete_on_termination && aws_instance.nginx.root_block_device[0].encrypted
    error_message = "The encrypted root disk must be deleted with the instance."
  }
  assert {
    condition     = aws_instance.nginx.user_data_replace_on_change && aws_instance.nginx.key_name == var.key_name
    error_message = "Use the existing key and rerun bootstrap through instance replacement when user data changes."
  }
  assert {
    condition = alltrue([
      strcontains(aws_instance.nginx.user_data, "install -y nginx"),
      strcontains(aws_instance.nginx.user_data, "Welcome to the Terraform-managed Nginx Server on Ubuntu"),
      strcontains(aws_instance.nginx.user_data, "systemctl enable --now nginx")
    ])
    error_message = "User data must install and enable Nginx with the exact assignment message."
  }
}

run "allow_public_ssh_by_default" {
  command = plan
  assert {
    condition = anytrue([
      for rule in aws_security_group.nginx.ingress : rule.from_port == 22 && toset(rule.cidr_blocks) == toset(["0.0.0.0/0"])
    ])
    error_message = "The assignment default must permit SSH without supplying a personal IP."
  }
}

run "reject_invalid_ssh_cidr" {
  command = plan
  variables {
    ssh_cidr = "not-a-cidr"
  }
  expect_failures = [var.ssh_cidr]
}

run "reject_empty_key" {
  command = plan
  variables {
    key_name = " "
  }
  expect_failures = [var.key_name]
}
