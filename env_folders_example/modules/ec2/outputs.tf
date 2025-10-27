output "public_subnet_id" {
  description = "ID of the public subnet used for the public instance"
  value       = local.public_subnet_id
}

output "private_subnet_id" {
  description = "ID of the private subnet used for the private instance"
  value       = local.private_subnet_id
}

output "public_security_group_id" {
  description = "ID of the security group for the public instance"
  value       = aws_security_group.public.id
}

output "private_security_group_id" {
  description = "ID of the security group for the private instance"
  value       = aws_security_group.private.id
}

output "public_instance_id" {
  description = "ID of the public EC2 instance"
  value       = aws_instance.public.id
}