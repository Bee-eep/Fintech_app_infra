terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ECR Repositories
resource "aws_ecr_repository" "main" {
  for_each = var.repositories

  name                 = "${var.project_name}-${each.key}"
  image_tag_mutability = each.value.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = each.value.scan_on_push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${var.project_name}-${each.key}"
  }
}

# ECR Lifecycle Policy to keep only recent images
resource "aws_ecr_lifecycle_policy" "main" {
  for_each = aws_ecr_repository.main

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Remove untagged images after 30 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Pull through cache rule (optional)
resource "aws_ecr_pull_through_cache_rule" "public" {
  ecr_repository_prefix = "public"
  upstream_registry_url = "public.ecr.aws"
}

resource "aws_ecr_pull_through_cache_rule" "docker" {
  ecr_repository_prefix = "docker"
  upstream_registry_url = "registry-1.docker.io"
}
