output "namespace" {
  description = "ArgoCD namespace"
  value       = helm_release.argocd.namespace
}

output "server_service" {
  description = "ArgoCD server service name"
  value       = "${helm_release.argocd.name}-server"
}

output "release_name" {
  description = "Helm release name"
  value       = helm_release.argocd.name
}

output "server_role_arn" {
  description = "ArgoCD server IAM role ARN"
  value       = module.argocd_server_irsa.iam_role_arn
}

output "application_controller_role_arn" {
  description = "ArgoCD application controller IAM role ARN"
  value       = module.argocd_application_controller_irsa.iam_role_arn
}

# output "root_application_name" {
#   description = "Root application name"
#   value       = kubernetes_manifest.root_app.manifest.metadata.name
# }
