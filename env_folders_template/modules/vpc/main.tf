# won't pass Chekhov intentionally on CI/CD

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = {
    Name        = "${var.project}-${var.environment}-${var.component}"
    Environment = var.environment
  }
}
