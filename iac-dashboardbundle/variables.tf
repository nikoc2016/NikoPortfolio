variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "eks_role_arn" {
  type = string
}

variable "node_role_arn" {
  type = string
}

variable "pem_name" {
  type = string
}