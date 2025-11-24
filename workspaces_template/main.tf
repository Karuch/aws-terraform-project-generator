module "vpc" {
  source = "./modules/vpc"

  project              = var.project
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames
}

module "subnets" {
  source = "./modules/subnet_generator"

  project              = var.project
  environment          = var.environment
  vpc_id               = module.vpc.vpc_id
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_count  = var.public_subnet_count
  private_subnet_count = var.private_subnet_count
  subnet_newbits       = var.subnet_newbits
}

module "ec2" {
  source = "./modules/ec2"

  project            = var.project
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = module.vpc.vpc_cidr
  public_subnet_ids  = module.subnets.public_subnet_ids
  private_subnet_ids = module.subnets.private_subnet_ids
  ami_id             = var.ami_id
  instance_type      = var.instance_type
}
