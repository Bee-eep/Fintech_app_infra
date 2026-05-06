output "eks_cluster_id" {
  description = "EKS Cluster ID"
  value       = module.eks.cluster_id
}

output "eks_cluster_endpoint" {
  description = "EKS Cluster Endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_ca_certificate" {
  description = "EKS Cluster CA Certificate"
  value       = module.eks.cluster_ca_certificate
  sensitive   = true
}

output "eks_cluster_security_group_id" {
  description = "EKS Cluster Security Group ID"
  value       = module.eks.cluster_security_group_id
}

output "eks_worker_security_group_id" {
  description = "EKS Worker Security Group ID"
  value       = module.eks.worker_security_group_id
}

output "rds_endpoint" {
  description = "RDS Database Endpoint"
  value       = module.rds.db_instance_endpoint
}

output "rds_port" {
  description = "RDS Database Port"
  value       = module.rds.db_instance_port
}

output "rds_database_name" {
  description = "RDS Database Name"
  value       = module.rds.db_instance_name
}

output "rds_security_group_id" {
  description = "RDS Security Group ID"
  value       = module.rds.security_group_id
}

output "ecr_backend_repository_url" {
  description = "ECR Backend Repository URL"
  value       = module.ecr.repositories["backend"].repository_url
}

output "ecr_frontend_repository_url" {
  description = "ECR Frontend Repository URL"
  value       = module.ecr.repositories["frontend"].repository_url
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "VPC CIDR Block"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "Public Subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private Subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "nat_gateway_ips" {
  description = "NAT Gateway Elastic IPs"
  value       = module.vpc.nat_gateway_ips
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_id} --region ${var.aws_region}"
}

output "kubectl_context" {
  description = "kubectl context name"
  value       = "arn:aws:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${module.eks.cluster_id}"
}

data "aws_caller_identity" "current" {}
