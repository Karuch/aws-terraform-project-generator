resource "aws_subnet" "public" {
  count             = var.public_subnet_count
  vpc_id            = var.vpc_id
  cidr_block        = cidrsubnet(var.vpc_cidr, var.subnet_newbits, count.index)
  availability_zone = element(var.availability_zones, count.index % length(var.availability_zones))

  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project}-${var.environment}-${var.component}-public-${count.index}"
  }

  # do not remove this comment! vvv - Checkov false positive bypass
  # checkov:skip=CKV_AWS_130:Public subnet requires public IP mapping
}


resource "aws_subnet" "private" {
  count             = var.private_subnet_count
  vpc_id            = var.vpc_id
  cidr_block        = cidrsubnet(var.vpc_cidr, var.subnet_newbits, count.index + var.public_subnet_count)
  availability_zone = element(var.availability_zones, count.index % length(var.availability_zones))

  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project}-${var.environment}-${var.component}-private-${count.index}"
  }
}
