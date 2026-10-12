variable "availability_zone_a" {
  description = "Availability Zone 1"
  type        = string
  default     = "us-east-1a"
}

variable "availability_zone_b" {
  description = "Availability Zone 2"
  type        = string
  default     = "us-east-1b"
}

variable "instance_type" {
  description = "Customer Gateway EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "on_prem_vpc_cidr" {
  description = "CIDR block for the On-Premises VPC"
  type        = string
  default     = "172.16.0.0/16"
}

variable "on_prem_public_subnet_cidr" {
  description = "CIDR block for Public subnet"
  type        = string
  default     = "172.16.0.0/24"
}

variable "on_prem_private_subnet_cidr" {
  description = "CIDR block for Private subnet"
  type        = string
  default     = "172.16.1.0/24"
}
