output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "public_subnet_cidrs" {
  value = aws_subnet.public[*].cidr_block
}

output "private_subnet_cidrs" {
  value = aws_subnet.private[*].cidr_block
}

output "subnet_azs" {
  value = concat(
    aws_subnet.public[*].availability_zone,
    aws_subnet.private[*].availability_zone
  )
}
