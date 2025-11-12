variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "component" {
  type    = string
  default = "compute"
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "vpc_cidr" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
}
