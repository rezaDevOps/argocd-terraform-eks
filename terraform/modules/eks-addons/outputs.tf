output "aws_load_balancer_controller_role_arn" {
  description = "AWS Load Balancer Controller IAM role ARN"
  value       = module.aws_load_balancer_controller_irsa.iam_role_arn
}

output "external_dns_role_arn" {
  description = "External DNS IAM role ARN"
  value       = var.enable_external_dns ? module.external_dns_irsa[0].iam_role_arn : null
}

output "cert_manager_role_arn" {
  description = "Cert Manager IAM role ARN"
  value       = var.enable_cert_manager ? module.cert_manager_irsa[0].iam_role_arn : null
}

output "cluster_autoscaler_role_arn" {
  description = "Cluster Autoscaler IAM role ARN"
  value       = var.enable_cluster_autoscaler ? module.cluster_autoscaler_irsa[0].iam_role_arn : null
}

output "aws_load_balancer_controller_namespace" {
  description = "AWS Load Balancer Controller namespace"
  value       = var.enable_aws_load_balancer_controller ? "kube-system" : null
}

output "external_dns_namespace" {
  description = "External DNS namespace"
  value       = var.enable_external_dns ? "external-dns" : null
}

output "cert_manager_namespace" {
  description = "Cert Manager namespace"
  value       = var.enable_cert_manager ? "cert-manager" : null
}
