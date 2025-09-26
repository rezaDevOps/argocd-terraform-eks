terraform {
  backend "s3" {
    # Configuration will be provided via backend.tf
  }
}

module "argocd_terraform_staging" {
  source = "../../"

  aws_region   = var.aws_region
  environment  = "staging"
  cluster_name = "${var.project_name}-staging"

  # Staging configuration
  node_group_desired_size = 3
  node_group_min_size     = 2
  node_group_max_size     = 8

  # Staging optimizations (balance cost and performance)
  single_nat_gateway = false  # HA for staging
  node_group_instance_types = ["m5.large"]
  
  gitops_repo_url = var.gitops_repo_url
  domain_name     = var.domain_name
  
  # Enable all addons for staging
  enable_aws_load_balancer_controller = var.enable_aws_load_balancer_controller
  enable_external_dns                 = var.enable_external_dns
  enable_cert_manager                  = var.enable_cert_manager
  enable_cluster_autoscaler           = var.enable_cluster_autoscaler
  enable_metrics_server              = var.enable_metrics_server
  enable_prometheus                  = var.enable_prometheus
  
  aws_auth_users = var.aws_auth_users
}

# Same variables as dev
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "argocd-terraform"
}

variable "gitops_repo_url" {
  description = "GitOps repository URL"
  type        = string
}

variable "domain_name" {
  description = "Domain name for ingress"
  type        = string
  default     = ""
}

variable "enable_aws_load_balancer_controller" {
  description = "Enable AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "enable_external_dns" {
  description = "Enable External DNS"
  type        = bool
  default     = true
}

variable "enable_cert_manager" {
  description = "Enable Cert Manager"
  type        = bool
  default     = true
}

variable "enable_cluster_autoscaler" {
  description = "Enable Cluster Autoscaler"
  type        = bool
  default     = true
}

variable "enable_metrics_server" {
  description = "Enable Metrics Server"
  type        = bool
  default     = true
}

variable "enable_prometheus" {
  description = "Enable Prometheus monitoring"
  type        = bool
  default     = true  # Enable monitoring in staging
}

variable "aws_auth_users" {
  description = "Additional IAM users to add to the aws-auth configmap"
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}
