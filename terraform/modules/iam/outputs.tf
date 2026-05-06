output "ebs_csi_driver_role_arn" {
  description = "EBS CSI Driver Role ARN"
  value       = aws_iam_role.ebs_csi_driver.arn
}

output "cluster_autoscaler_role_arn" {
  description = "Cluster Autoscaler Role ARN"
  value       = aws_iam_role.cluster_autoscaler.arn
}

output "alb_ingress_controller_role_arn" {
  description = "ALB Ingress Controller Role ARN"
  value       = aws_iam_role.alb_ingress_controller.arn
}

output "external_secrets_operator_role_arn" {
  description = "External Secrets Operator Role ARN"
  value       = aws_iam_role.external_secrets_operator.arn
}

output "app_pod_role_arn" {
  description = "Application Pod Role ARN"
  value       = aws_iam_role.app_pod_role.arn
}
