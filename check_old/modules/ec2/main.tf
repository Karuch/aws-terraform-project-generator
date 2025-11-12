locals {
  public_subnet_id  = element(var.subnet_ids, 0)
  private_subnet_id = element(var.subnet_ids, 1)
}

resource "aws_security_group" "public" {
  name        = "${var.project}-${var.environment}-${var.component}-public"
  description = "Allow SSH and HTTP"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-${var.environment}-${var.component}-public"
  }
}

resource "aws_security_group" "private" {
  name        = "${var.project}-${var.environment}-${var.component}-private"
  description = "Allow SSH only from within VPC"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-${var.environment}-${var.component}-private"
  }
}

resource "aws_instance" "public" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = local.public_subnet_id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.public.id]

  tags = {
    Name = "${var.project}-${var.environment}-${var.component}-public"
  }
}

resource "aws_instance" "private" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = local.private_subnet_id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.private.id]

  tags = {
    Name = "${var.project}-${var.environment}-${var.component}-private"
  }
}
