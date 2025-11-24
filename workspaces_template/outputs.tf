output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "List of PUBLIC subnet IDs"
  value       = module.subnets.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of PRIVATE subnet IDs"
  value       = module.subnets.private_subnet_ids
}

output "public_subnet_cidrs" {
  description = "List of PUBLIC subnet CIDRs"
  value       = module.subnets.public_subnet_cidrs
}

output "private_subnet_cidrs" {
  description = "List of PRIVATE subnet CIDRs"
  value       = module.subnets.private_subnet_cidrs
}

output "subnet_azs" {
  description = "List of Availability Zones for all subnets"
  value       = module.subnets.subnet_azs
}
