terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment below to use S3 backend for state management in AWS Learner's Lab
  # backend "s3" {
  #   bucket         = "fintech-terraform-state"
  #   key            = "fintech/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "fintech-terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
      CreatedAt   = timestamp()
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  project_name           = var.project_name
  environment            = var.environment
  vpc_cidr_block         = var.vpc_cidr_block
  private_subnet_cidrs   = var.private_subnet_cidrs
  public_subnet_cidrs    = var.public_subnet_cidrs
  availability_zones     = slice(data.aws_availability_zones.available.names, 0, 3)
  enable_nat_gateway     = true
  enable_vpn_gateway     = false
  enable_flow_logs       = true
}

# EKS Module
module "eks" {
  source = "./modules/eks"

  project_name             = var.project_name
  environment              = var.environment
  cluster_version          = var.kubernetes_version
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = concat(module.vpc.public_subnet_ids, module.vpc.private_subnet_ids)
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  cluster_log_retention_in_days    = 30

  worker_groups = {
    general = {
      name           = "general-workers"
      capacity_type  = "ON_DEMAND"
      instance_types = ["t3.medium"]
      disk_size      = 50
      min_size       = 2
      max_size       = 10
      desired_size   = 2
      labels = {
        Environment = var.environment
        ManagedBy   = "Terraform"
      }
      taints = []
    }
    spot = {
      name           = "spot-workers"
      capacity_type  = "SPOT"
      instance_types = ["t3.medium", "t3a.medium"]
      disk_size      = 50
      min_size       = 1
      max_size       = 5
      desired_size   = 1
      labels = {
        Environment = var.environment
        WorkloadType = "Spot"
      }
      taints = [
        {
          key    = "spot"
          value  = "true"
          effect = "NoSchedule"
        }
      ]
    }
  }

  depends_on = [module.vpc]
}

# RDS Module
module "rds" {
  source = "./modules/rds"

  project_name             = var.project_name
  environment              = var.environment
  db_engine_version        = var.postgres_version
  db_instance_class        = var.db_instance_class
  allocated_storage        = var.db_allocated_storage
  max_allocated_storage    = var.db_max_allocated_storage
  db_name                  = var.db_name
  db_username              = var.db_username
  db_password              = var.db_password
  vpc_id                   = module.vpc.vpc_id
  private_subnet_ids       = module.vpc.private_subnet_ids
  multi_az                 = true
  storage_encrypted        = true
  enable_backup            = true
  backup_retention_period  = 30
  backup_window            = "03:00-04:00"
  maintenance_window       = "mon:04:00-mon:05:00"
  enable_monitoring        = true
  monitoring_interval      = 60

  depends_on = [module.vpc]
}

# ECR Module
module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
  environment  = var.environment

  repositories = {
    backend = {
      image_tag_mutability = "IMMUTABLE"
      scan_on_push         = true
    }
    frontend = {
      image_tag_mutability = "IMMUTABLE"
      scan_on_push         = true
    }
  }
}

# IAM Module
module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
  environment  = var.environment
  cluster_arn  = module.eks.cluster_arn
  cluster_name = module.eks.cluster_id
  oidc_provider_arn = module.eks.oidc_provider_arn
  
  # Enable OIDC provider for pod identity
  enable_oidc = true
}

# CloudWatch Module (Logging and Monitoring)
module "monitoring" {
  source = "./modules/monitoring"

  project_name = var.project_name
  environment  = var.environment
  cluster_name = module.eks.cluster_id

  # Log retention in days
  log_retention_days = 30

  # Alert email
  alert_email = var.alert_email

  depends_on = [module.eks]
}
