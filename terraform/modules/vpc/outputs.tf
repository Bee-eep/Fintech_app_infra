output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR Block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "Public Subnet IDs"
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "private_subnet_ids" {
  description = "Private Subnet IDs"
  value       = [for subnet in aws_subnet.private : subnet.id]
}

output "nat_gateway_ips" {
  description = "NAT Gateway Elastic IPs"
  value       = var.enable_nat_gateway ? [for eip in aws_eip.nat : eip.public_ip] : []
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs"
  value       = var.enable_nat_gateway ? [for nat in aws_nat_gateway.main : nat.id] : []
}
