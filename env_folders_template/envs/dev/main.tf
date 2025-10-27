module "vpc" {
  source = "../../modules/vpc"

  project              = var.project
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  subnet_count         = var.subnet_count
  subnet_newbits       = var.subnet_newbits
  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames
}

module "ec2" {
  source = "../../modules/ec2"

  project       = var.project
  environment   = var.environment
  vpc_id        = module.vpc.vpc_id
  subnet_ids    = module.vpc.subnet_ids
  vpc_cidr      = module.vpc.vpc_cidr
  ami_id        = var.ami_id
  instance_type = var.instance_type
}
