locals {
  name = "${var.project_name}-${var.environment}"
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }

  # EKS Addons configuration
  eks_addons = {
    # Core addons
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent              = true
      before_compute           = true
      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          ENABLE_POD_ENI           = "true"
        }
      })
    }
    # Storage
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}
data "aws_partition" "current" {}

# VPC with advanced configuration
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = [for k, v in var.availability_zones : cidrsubnet(var.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in var.availability_zones : cidrsubnet(var.vpc_cidr, 8, k + 48)]
  intra_subnets   = [for k, v in var.availability_zones : cidrsubnet(var.vpc_cidr, 8, k + 52)]

  enable_nat_gateway   = true
  single_nat_gateway   = var.single_nat_gateway
  enable_dns_hostnames = true
  enable_dns_support   = true
  enable_flow_log      = true
  create_flow_log_cloudwatch_iam_role = true
  create_flow_log_cloudwatch_log_group = true

  # VPC endpoints will be created separately if needed

  public_subnet_tags = {
    "kubernetes.io/role/elb"                              = "1"
    "kubernetes.io/cluster/${var.cluster_name}"          = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"                     = "1"
    "kubernetes.io/cluster/${var.cluster_name}"          = "shared"
  }

  tags = local.tags
}

# EKS Cluster with comprehensive configuration
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.15"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                          = module.vpc.vpc_id
  subnet_ids                      = module.vpc.private_subnets
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = true

  # Encryption at rest
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }

  # Logging
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # EKS Addons
  cluster_addons = local.eks_addons

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    instance_types = var.node_group_instance_types
    
    attach_cluster_primary_security_group = true
    vpc_security_group_ids                = [aws_security_group.additional.id]
    
    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }

    # Enable detailed monitoring
    enable_monitoring = true

    # Block device mappings
    block_device_mappings = {
      xvda = {
        device_name = "/dev/xvda"
        ebs = {
          volume_size           = 100
          volume_type          = "gp3"
          iops                 = 3000
          throughput           = 150
          encrypted            = true
          # kms_key_id          = aws_kms_key.ebs.arn  # Temporarily disabled due to KMS key state issue
          delete_on_termination = true
        }
      }
    }
  }

  eks_managed_node_groups = {
    # General purpose nodes
    general = {
      name = "${local.name}-gen"
      
      min_size     = var.node_group_min_size
      max_size     = var.node_group_max_size
      desired_size = var.node_group_desired_size

      instance_types = var.node_group_instance_types
      capacity_type  = "ON_DEMAND"
      
      iam_role_use_name_prefix = false
      iam_role_name = "${local.name}-gen-role"
      
      labels = {
        Environment = var.environment
        NodeGroup   = "general"
        WorkerType  = "general-purpose"
      }

      tags = merge(local.tags, {
        "k8s.io/cluster-autoscaler/enabled" = "true"
        "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
      })
    }

    # Spot instances for cost optimization
    spot = {
      name = "${local.name}-spt"
      
      min_size     = 0
      max_size     = var.node_group_max_size * 2
      desired_size = 2

      instance_types = var.spot_instance_types
      capacity_type  = "SPOT"
      
      iam_role_use_name_prefix = false
      iam_role_name = "${local.name}-spt-role"
      
      labels = {
        Environment = var.environment
        NodeGroup   = "spot"
        WorkerType  = "spot-instances"
      }

      taints = {
        spotInstance = {
          key    = "spot-instance"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }

      tags = merge(local.tags, {
        "k8s.io/cluster-autoscaler/enabled" = "true"
        "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
        "k8s.io/cluster-autoscaler/node-template/label/spot" = "true"
      })
    }
  }

  # aws-auth configmap with extended permissions
  manage_aws_auth_configmap = true

  aws_auth_roles = [
    {
      rolearn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/AWSReservedSSO_PowerUserAccess_*"
      username = "poweruser"
      groups   = ["system:masters"]
    }
  ]

  aws_auth_users = var.aws_auth_users

  tags = local.tags
}

# KMS Keys for encryption
resource "aws_kms_key" "eks" {
  description             = "EKS Secret Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(local.tags, {
    Name = "${local.name}-eks-encryption-key"
  })
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${local.name}-eks"
  target_key_id = aws_kms_key.eks.key_id
}

resource "aws_kms_key" "ebs" {
  description             = "EBS Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(local.tags, {
    Name = "${local.name}-ebs-encryption-key"
  })
}

resource "aws_kms_alias" "ebs" {
  name          = "alias/${local.name}-ebs"
  target_key_id = aws_kms_key.ebs.key_id
}

# Additional Security Groups
resource "aws_security_group" "additional" {
  name        = "${local.name}-additional"
  description = "Additional security group for EKS nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Cluster API to node groups"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Node to node communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${local.name}-additional-sg"
  })
}

# IRSA roles for VPC CNI
module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.name}-vpc-cni"

  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }

  tags = local.tags
}

# IRSA role for EBS CSI
module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.name}-ebs-csi"

  attach_ebs_csi_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = local.tags
}

# EKS Addons Module
module "eks_addons" {
  source = "./modules/eks-addons"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnets
  environment          = var.environment
  domain_name          = var.domain_name

  # Enable/disable addons
  enable_aws_load_balancer_controller = var.enable_aws_load_balancer_controller
  enable_external_dns                 = var.enable_external_dns
  enable_cert_manager                  = var.enable_cert_manager
  enable_cluster_autoscaler           = var.enable_cluster_autoscaler
  enable_metrics_server              = var.enable_metrics_server
  enable_prometheus                  = var.enable_prometheus

  depends_on = [module.eks]
  tags = local.tags
}

# ArgoCD Installation with IRSA
module "argocd" {
  source = "./modules/argocd"

  cluster_name      = var.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  oidc_provider_arn = module.eks.oidc_provider_arn
  
  environment      = var.environment
  argocd_version   = var.argocd_version
  gitops_repo_url  = var.gitops_repo_url
  domain_name      = var.domain_name

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets

  depends_on = [module.eks_addons]
  tags = local.tags
}

# GitOps Bridge Metadata
# Note: Commented out during initial bootstrap to avoid chicken-egg problem
# Uncomment after cluster is created and kubectl is configured
resource "kubernetes_config_map" "argocd_metadata" {
  metadata {
    name      = "argocd-metadata"
    namespace = "argocd"
  }

  data = {
    "aws_account_id"        = data.aws_caller_identity.current.account_id
    "aws_region"            = var.aws_region
    "aws_partition"         = data.aws_partition.current.partition
    "cluster_name"          = var.cluster_name
    "cluster_endpoint"      = module.eks.cluster_endpoint
    "cluster_arn"           = module.eks.cluster_arn
    "oidc_provider_arn"     = module.eks.oidc_provider_arn
    "environment"           = var.environment
    "vpc_id"                = module.vpc.vpc_id
    "private_subnets"       = jsonencode(module.vpc.private_subnets)
    "public_subnets"        = jsonencode(module.vpc.public_subnets)
    "load_balancer_controller_role_arn" = module.eks_addons.aws_load_balancer_controller_role_arn
    "external_dns_role_arn" = module.eks_addons.external_dns_role_arn
    "cert_manager_role_arn" = module.eks_addons.cert_manager_role_arn
  }

  depends_on = [module.argocd]
}
