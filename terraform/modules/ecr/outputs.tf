output "repositories" {
  description = "ECR Repository details"
  value = {
    for k, v in aws_ecr_repository.main : k => {
      name              = v.name
      repository_url    = v.repository_url
      registry_id       = v.registry_id
      repository_arn    = v.arn
    }
  }
}

output "repository_urls" {
  description = "ECR Repository URLs"
  value = {
    for k, v in aws_ecr_repository.main : k => v.repository_url
  }
}

output "registry_id" {
  description = "AWS Account ID (ECR Registry ID)"
  value       = data.aws_caller_identity.current.account_id
}
