output "vpc_id" {
  description = "The ID of the created VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "The CIDR block of the created VPC"
  value       = aws_vpc.main.cidr_block
}

output "subnet_ids" {
  description = "List of subnet IDs created"
  value       = aws_subnet.subnets[*].id
}

output "subnet_cidrs" {
  description = "List of subnet CIDR blocks"
  value       = aws_subnet.subnets[*].cidr_block
}
