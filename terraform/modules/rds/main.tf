terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# RDS Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Security group for RDS database"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "PostgreSQL from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# KMS Key for RDS Encryption
resource "aws_kms_key" "rds" {
  count                   = var.storage_encrypted ? 1 : 0
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "${var.project_name}-rds-key"
  }
}

resource "aws_kms_alias" "rds" {
  count         = var.storage_encrypted ? 1 : 0
  name          = "alias/${var.project_name}-rds"
  target_key_id = aws_kms_key.rds[0].key_id
}

# Enhanced Monitoring Role
resource "aws_iam_role" "rds_monitoring" {
  count = var.enable_monitoring ? 1 : 0
  name  = "${var.project_name}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count      = var.enable_monitoring ? 1 : 0
  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# RDS Parameter Group
resource "aws_db_parameter_group" "main" {
  name        = "${var.project_name}-postgres-params"
  family      = "postgres${split(".", var.db_engine_version)[0]}"
  description = "Parameter group for ${var.project_name}"

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_duration"
    value = "on"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements"
    apply_method = "pending-reboot"
  }

  tags = {
    Name = "${var.project_name}-postgres-params"
  }
}

# RDS Cluster Parameter Group
resource "aws_rds_cluster_parameter_group" "main" {
  name        = "${var.project_name}-cluster-postgres-params"
  family      = "postgres${split(".", var.db_engine_version)[0]}"
  description = "Cluster parameter group for ${var.project_name}"

  parameter {
    name  = "binlog_format"
    value = "ROW"
  }

  tags = {
    Name = "${var.project_name}-cluster-postgres-params"
  }
}

# RDS Instance
resource "aws_db_instance" "main" {
  allocated_storage            = var.allocated_storage
  max_allocated_storage        = var.max_allocated_storage
  db_name                      = var.db_name
  engine                       = "postgres"
  engine_version               = var.db_engine_version
  instance_class               = var.db_instance_class
  username                     = var.db_username
  password                     = var.db_password
  parameter_group_name         = aws_db_parameter_group.main.name
  db_subnet_group_name         = aws_db_subnet_group.main.name
  publicly_accessible          = false
  skip_final_snapshot          = false
  final_snapshot_identifier    = "${var.project_name}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  multi_az                     = var.multi_az
  storage_encrypted            = var.storage_encrypted
  kms_key_id                   = var.storage_encrypted ? aws_kms_key.rds[0].arn : null
  vpc_security_group_ids       = [aws_security_group.rds.id]
  backup_retention_period      = var.backup_retention_period
  backup_window                = var.backup_window
  maintenance_window           = var.maintenance_window
  copy_tags_to_snapshot        = true
  enable_iam_database_authentication = true
  enable_cloudwatch_logs_exports = ["postgresql"]
  deletion_protection          = var.environment == "production" ? true : false

  # Enhanced monitoring
  monitoring_interval = var.enable_monitoring ? var.monitoring_interval : 0
  monitoring_role_arn = var.enable_monitoring ? aws_iam_role.rds_monitoring[0].arn : null

  # Performance Insights
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  tags = {
    Name = "${var.project_name}-db"
  }

  depends_on = [aws_db_parameter_group.main]
}

# CloudWatch Alarms for RDS
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.project_name}-rds-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Alarm when RDS CPU exceeds 80%"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  alarm_name          = "${var.project_name}-rds-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "2147483648" # 2GB in bytes
  alarm_description   = "Alarm when free storage is below 2GB"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name          = "${var.project_name}-rds-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Alarm when database connections exceed 80"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }
}
