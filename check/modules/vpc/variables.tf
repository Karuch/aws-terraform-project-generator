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

variable "vpc_cidr" {
  type = string
}

variable "availability_zones" {
  type = list(string)
}

variable "subnet_count" {
  type = number
}

variable "subnet_newbits" {
  type = number
}

variable "enable_dns_support" {
  type = bool
}

variable "enable_dns_hostnames" {
  type = bool
}
