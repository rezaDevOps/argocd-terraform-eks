variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS cluster endpoint"
  type        = string
}

variable "oidc_provider_arn" {
  description = "EKS cluster OIDC provider ARN"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "argocd_version" {
  description = "ArgoCD Helm chart version"
  type        = string
}

variable "gitops_repo_url" {
  description = "GitOps repository URL"
  type        = string
}

variable "domain_name" {
  description = "Domain name for ArgoCD"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
  default     = {}
}
