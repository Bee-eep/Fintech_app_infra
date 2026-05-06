output "cluster_id" {
  description = "EKS Cluster ID"
  value       = aws_eks_cluster.main.id
}

output "cluster_arn" {
  description = "EKS Cluster ARN"
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "EKS Cluster Endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_version" {
  description = "EKS Cluster Version"
  value       = aws_eks_cluster.main.version
}

output "cluster_ca_certificate" {
  description = "Base64 encoded EKS Cluster CA Certificate"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "EKS Cluster Security Group ID"
  value       = aws_security_group.eks_cluster.id
}

output "worker_security_group_id" {
  description = "EKS Worker Security Group ID"
  value       = aws_security_group.eks_worker.id
}

output "worker_role_arn" {
  description = "EKS Worker Role ARN"
  value       = aws_iam_role.eks_worker_role.arn
}

output "worker_role_name" {
  description = "EKS Worker Role Name"
  value       = aws_iam_role.eks_worker_role.name
}

output "oidc_provider_arn" {
  description = "OIDC Provider ARN"
  value       = aws_iam_openid_connect_provider.cluster.arn
}

output "node_group_ids" {
  description = "EKS Node Group IDs"
  value       = { for k, v in aws_eks_node_group.main : k => v.id }
}

output "cluster_log_group_name" {
  description = "CloudWatch Log Group Name"
  value       = aws_cloudwatch_log_group.eks_cluster.name
}
