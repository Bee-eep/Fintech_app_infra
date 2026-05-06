terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/fintech/application"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project_name}-application-logs"
  }
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/aws/fintech/backend"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project_name}-backend-logs"
  }
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/aws/fintech/frontend"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project_name}-frontend-logs"
  }
}

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"

  tags = {
    Name = "${var.project_name}-alerts"
  }
}

resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# CloudWatch Alarms for EKS

# Pod Error Rate Alarm
resource "aws_cloudwatch_metric_alarm" "pod_error_rate" {
  alarm_name          = "${var.project_name}-pod-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "PodErrorRate"
  namespace           = "ContainerInsights"
  period              = "300"
  statistic           = "Average"
  threshold           = "5"
  alarm_description   = "Alarm when pod error rate exceeds 5%"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = var.cluster_name
  }
}

# Node CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "node_cpu_utilization" {
  alarm_name          = "${var.project_name}-node-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "node_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "Alarm when node CPU utilization exceeds 85%"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = var.cluster_name
  }
}

# Node Memory Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "node_memory_utilization" {
  alarm_name          = "${var.project_name}-node-memory-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "node_memory_utilization"
  namespace           = "ContainerInsights"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "Alarm when node memory utilization exceeds 85%"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = var.cluster_name
  }
}

# Cluster Node Count Alarm
resource "aws_cloudwatch_metric_alarm" "cluster_node_count" {
  alarm_name          = "${var.project_name}-cluster-node-count"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "node_count"
  namespace           = "ContainerInsights"
  period              = "300"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "Alarm when cluster node count drops below expected"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = var.cluster_name
  }
}

# Composite Alarm for Overall Health
resource "aws_cloudwatch_composite_alarm" "cluster_health" {
  alarm_name          = "${var.project_name}-cluster-health"
  alarm_description   = "Composite alarm for overall cluster health"
  actions_enabled     = true
  alarm_actions       = [aws_sns_topic.alerts.arn]

  alarm_rule = join(" OR ", [
    "arn:aws:cloudwatch:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:alarm:${aws_cloudwatch_metric_alarm.pod_error_rate.alarm_name}",
    "arn:aws:cloudwatch:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:alarm:${aws_cloudwatch_metric_alarm.node_cpu_utilization.alarm_name}",
    "arn:aws:cloudwatch:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:alarm:${aws_cloudwatch_metric_alarm.node_memory_utilization.alarm_name}"
  ])
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "cluster" {
  dashboard_name = "${var.project_name}-cluster"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["ContainerInsights", "node_cpu_utilization", { stat = "Average" }],
            [".", "node_memory_utilization", { stat = "Average" }],
            [".", "pod_cpu_utilization", { stat = "Average" }],
            [".", "pod_memory_utilization", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Cluster Resource Utilization"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["ContainerInsights", "node_count", { stat = "Average" }],
            [".", "pod_count", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Cluster Resource Count"
        }
      }
    ]
  })
}

# Log Metric Filter for Errors
resource "aws_cloudwatch_log_group_metric_filter" "error_log_filter" {
  name           = "${var.project_name}-error-filter"
  log_group_name = aws_cloudwatch_log_group.application.name
  filter_pattern = "[ERROR]"

  metric_transformation {
    name      = "${var.project_name}-error-count"
    namespace = "FinTechApp"
    value     = "1"
  }
}
