output "vpc_id" {
  value = module.vpc.vpc_id
}

output "subnet_ids" {
  value = module.vpc.subnet_ids
}

output "subnet_cidrs" {
  value = module.vpc.subnet_cidrs
}
