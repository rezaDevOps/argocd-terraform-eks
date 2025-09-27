resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_version
  namespace  = "argocd"
  
  create_namespace = true
  atomic          = true
  cleanup_on_fail = true
  wait           = true
  timeout        = 600

  values = [
    templatefile("${path.module}/values/argocd-values.yaml", {
      cluster_name      = var.cluster_name
      environment       = var.environment
      gitops_repo_url   = var.gitops_repo_url
      domain_name       = var.domain_name
      server_role_arn   = module.argocd_server_irsa.iam_role_arn
      app_controller_role_arn = module.argocd_application_controller_irsa.iam_role_arn
    })
  ]

  depends_on = [
    module.argocd_server_irsa,
    module.argocd_application_controller_irsa
  ]
}

resource "time_sleep" "wait_for_argocd" {
  depends_on = [helm_release.argocd]
  
  create_duration = "60s"
}

# ArgoCD root application (App of Apps)
# Note: Commented out during initial bootstrap to avoid chicken-egg problem
# Uncomment after cluster is created and configured
resource "kubernetes_manifest" "root_app" {
  depends_on = [time_sleep.wait_for_argocd]
  
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "app-of-apps-${var.environment}"
      namespace = "argocd"
      finalizers = [
        "resources-finalizer.argocd.argoproj.io"
      ]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.gitops_repo_url
        targetRevision = "HEAD"
        path           = "environments/${var.environment}"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "argocd"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  }
}
