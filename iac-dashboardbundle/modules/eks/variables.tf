variable "name_prefix" {
  type = string
}

variable "subnets" {
  type = list(string)
}

variable "eks_role_arn" {
  type = string
}

variable "node_role_arn" {
  type = string
}
