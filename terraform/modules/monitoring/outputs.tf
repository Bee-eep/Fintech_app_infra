output "sns_topic_arn" {
  description = "SNS Topic ARN for Alerts"
  value       = aws_sns_topic.alerts.arn
}

output "sns_topic_name" {
  description = "SNS Topic Name for Alerts"
  value       = aws_sns_topic.alerts.name
}

output "application_log_group_name" {
  description = "Application Log Group Name"
  value       = aws_cloudwatch_log_group.application.name
}

output "backend_log_group_name" {
  description = "Backend Log Group Name"
  value       = aws_cloudwatch_log_group.backend.name
}

output "frontend_log_group_name" {
  description = "Frontend Log Group Name"
  value       = aws_cloudwatch_log_group.frontend.name
}

output "dashboard_url" {
  description = "CloudWatch Dashboard URL"
  value       = "https://console.aws.amazon.com/cloudwatch/home#dashboards:name=${aws_cloudwatch_dashboard.cluster.dashboard_name}"
}
