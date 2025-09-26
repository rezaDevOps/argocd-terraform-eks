# Core variables
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "argocd-terraform"
}

variable "created_by" {
  description = "Creator identification"
  type        = string
  default     = "terraform"
}

# Cluster configuration
variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "cluster_endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
  default     = true
}

# Networking
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway for cost savings"
  type        = bool
  default     = false
}

# Node Groups
variable "node_group_instance_types" {
  description = "EKS node group instance types"
  type        = list(string)
  default     = ["m5.large"]
}

variable "spot_instance_types" {
  description = "Spot instance types for cost optimization"
  type        = list(string)
  default     = ["m5.large", "m5a.large", "m4.large"]
}

variable "node_group_desired_size" {
  description = "EKS node group desired size"
  type        = number
  default     = 3
}

variable "node_group_min_size" {
  description = "EKS node group minimum size"
  type        = number
  default     = 2
}

variable "node_group_max_size" {
  description = "EKS node group maximum size"
  type        = number
  default     = 10
}

# ArgoCD
variable "argocd_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "5.46.8"
}

variable "gitops_repo_url" {
  description = "GitOps repository URL"
  type        = string
  default     = "https://github.com/your-org/gitops-repo.git"
}

variable "domain_name" {
  description = "Domain name for ingress"
  type        = string
  default     = ""
}

# EKS Addons Control
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
  default     = false
}

# Authentication
variable "aws_auth_users" {
  description = "Additional IAM users to add to the aws-auth configmap"
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}
