variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cluster_arn" {
  description = "EKS Cluster ARN"
  type        = string
}

variable "cluster_name" {
  description = "EKS Cluster Name"
  type        = string
}

variable "oidc_provider_arn" {
  description = "OIDC Provider ARN"
  type        = string
}

variable "enable_oidc" {
  description = "Enable OIDC provider for pod identity"
  type        = bool
  default     = true
}
