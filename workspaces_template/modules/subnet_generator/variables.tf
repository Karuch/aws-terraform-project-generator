variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "component" {
  type    = string
  default = "network"
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "availability_zones" {
  type = list(string)
}

variable "public_subnet_count" {
  type        = number
  description = "Number of PUBLIC subnets to create"
}

variable "private_subnet_count" {
  type        = number
  description = "Number of PRIVATE subnets to create"
}

variable "subnet_newbits" {
  type        = number
  description = "CIDR split bits for subnetting"
}
