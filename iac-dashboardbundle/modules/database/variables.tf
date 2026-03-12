variable "name_prefix" {
  type        = string
  description = "Prefix for resource names"
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_id" {
  type = string
}

variable "public_subnets" {
  type        = list(string)
  description = "List of public subnet IDs"
}

variable "vpc_cidr_block" {
  type = string
}

variable "pem_name" {
  type = string
}