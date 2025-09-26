# ArgoCD Server IRSA for AWS integrations
module "argocd_server_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-argocd-server"

  role_policy_arns = {
    policy = aws_iam_policy.argocd_server.arn
  }

  oidc_providers = {
    ex = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["argocd:argocd-server"]
    }
  }

  tags = var.tags
}

# ArgoCD Server Policy
resource "aws_iam_policy" "argocd_server" {
  name        = "${var.cluster_name}-argocd-server-policy"
  description = "ArgoCD Server policy for AWS integrations"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:*:${data.aws_caller_identity.current.account_id}:secret:argocd/*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:parameter/argocd/*"
      }
    ]
  })

  tags = var.tags
}

# ArgoCD Application Controller IRSA
module "argocd_application_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-argocd-application-controller"

  role_policy_arns = {
    policy = aws_iam_policy.argocd_application_controller.arn
  }

  oidc_providers = {
    ex = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["argocd:argocd-application-controller"]
    }
  }

  tags = var.tags
}

# ArgoCD Application Controller Policy
resource "aws_iam_policy" "argocd_application_controller" {
  name        = "${var.cluster_name}-argocd-application-controller-policy"
  description = "ArgoCD Application Controller policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

data "aws_caller_identity" "current" {}
