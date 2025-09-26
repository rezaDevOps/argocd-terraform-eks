terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    argocd = {
      source  = "argoproj-labs/argocd"
      version = "~> 7.7"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}
