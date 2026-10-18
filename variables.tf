variable "aws_region" {
  description = "AWS region containing your existing default VPC and EC2 key pair."
  type        = string
  default     = "ap-south-1"

  validation {
    condition     = length(trimspace(var.aws_region)) > 0
    error_message = "Set a non-empty AWS region."
  }
}

variable "key_name" {
  description = "Name of an existing EC2 key pair in the selected region (not a .pem path)."
  type        = string

  validation {
    condition     = length(trimspace(var.key_name)) > 0
    error_message = "Supply the name of an existing EC2 key pair."
  }
}

variable "ssh_cidr" {
  description = "IPv4 CIDR allowed to use SSH; defaults to public access for this assignment."
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrnetmask(var.ssh_cidr))
    error_message = "Use a valid IPv4 CIDR, such as 0.0.0.0/0 or a single public IPv4 address with /32."
  }
}
