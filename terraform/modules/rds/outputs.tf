output "db_instance_id" {
  description = "RDS Instance ID"
  value       = aws_db_instance.main.id
}

output "db_instance_endpoint" {
  description = "RDS Instance Endpoint"
  value       = aws_db_instance.main.endpoint
}

output "db_instance_port" {
  description = "RDS Instance Port"
  value       = aws_db_instance.main.port
}

output "db_instance_name" {
  description = "RDS Database Name"
  value       = aws_db_instance.main.db_name
}

output "db_instance_username" {
  description = "RDS Database Username"
  value       = aws_db_instance.main.username
  sensitive   = true
}

output "db_instance_resource_id" {
  description = "RDS Instance Resource ID"
  value       = aws_db_instance.main.resource_id
}

output "db_instance_class" {
  description = "RDS Instance Class"
  value       = aws_db_instance.main.instance_class
}

output "security_group_id" {
  description = "RDS Security Group ID"
  value       = aws_security_group.rds.id
}

output "subnet_group_name" {
  description = "RDS Subnet Group Name"
  value       = aws_db_subnet_group.main.name
}
