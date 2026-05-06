variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "repositories" {
  description = "ECR repository configurations"
  type = map(object({
    image_tag_mutability = string
    scan_on_push         = bool
  }))
  default = {}
}
