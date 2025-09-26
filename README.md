# ArgoCD Terraform EKS

This project sets up a complete GitOps infrastructure using ArgoCD on Amazon EKS with Terraform. It provides a production-ready Kubernetes cluster with ArgoCD for continuous deployment and application management.

## 🏗️ Architecture Overview

The infrastructure includes:

- **Amazon EKS Cluster** (v1.28) with managed node groups
- **ArgoCD** for GitOps-based deployments
- **EKS Add-ons**: AWS Load Balancer Controller, External DNS, Cert Manager, Cluster Autoscaler, Metrics Server
- **VPC** with public/private subnets across multiple AZs
- **Security**: KMS encryption, IAM roles with IRSA (IAM Roles for Service Accounts)
- **Monitoring**: CloudWatch logging and metrics collection

## 📋 Prerequisites

- AWS CLI configured with appropriate permissions
- kubectl installed
- Helm 3.x installed
- Terraform >= 1.0
- Git

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/rezaDevOps/argocd-terraform-eks.git
cd argocd-terraform-eks
```

### 2. Configure Variables

Update the following values in `terraform/environments/dev/terraform.tfvars`:

```hcl
# Core Configuration
aws_region   = "us-west-2"
project_name = "argocd-terraform"

# GitOps Configuration - UPDATE THESE VALUES
gitops_repo_url = "https://github.com/rezaDevOps/argocd-terraform-eks.git"
domain_name     = "example.com"

# EKS Addons (Enable what you need)
enable_aws_load_balancer_controller = true
enable_external_dns                 = true
enable_cert_manager                  = true
enable_cluster_autoscaler           = true
enable_metrics_server              = true
enable_prometheus                  = false
```

### 3. Deploy Infrastructure

```bash
cd terraform

# Initialize Terraform
terraform init

# Plan the deployment
terraform plan -var-file="environments/dev/terraform.tfvars" -var="environment=dev" -var="cluster_name=argocd-terraform-dev"

# Apply the changes
terraform apply -var-file="environments/dev/terraform.tfvars" -var="environment=dev" -var="cluster_name=argocd-terraform-dev"
```

### 4. Connect to EKS Cluster

```bash
aws eks update-kubeconfig --region us-west-2 --name argocd-terraform-dev
kubectl cluster-info
```

### 5. Install ArgoCD

Install ArgoCD with Helm:

```bash
# Add ArgoCD Helm repository
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Create ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD
helm install argocd argo/argo-cd \
  --namespace argocd \
  --set server.extraArgs[0]="--insecure" \
  --wait
```

### 6. Access ArgoCD

Get the admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

Set up port forwarding:

```bash
kubectl port-forward service/argocd-server -n argocd 8080:443
```

Access ArgoCD at: **http://localhost:8080**
- **Username**: `admin`
- **Password**: Use the password from step above

## 📊 What's Included

### Infrastructure Components
- ✅ **EKS Cluster** (v1.28) with encryption, logging, and security
- ✅ **VPC** with public/private subnets and NAT gateways
- ✅ **AWS Load Balancer Controller** for ALB/NLB support
- ✅ **External DNS** for automatic Route53 management
- ✅ **Cert Manager** for TLS certificate automation
- ✅ **Cluster Autoscaler** for node scaling
- ✅ **Metrics Server** for resource monitoring
- ✅ **EBS CSI Driver** for persistent storage
- ✅ **IRSA roles** for secure AWS integration

### ArgoCD Features
- ✅ **GitOps Deployment** with automated sync
- ✅ **RBAC Configuration** with admin, developer, readonly roles
- ✅ **Sample Application** (Guestbook) deployed
- ✅ **Insecure Mode** enabled for easy access via port-forward
- ✅ **High Availability** configuration ready

### Sample Applications
After setup, you'll have:
- **ArgoCD UI** - GitOps dashboard and application management
- **Sample Guestbook App** - Deployed via ArgoCD from public repository

## 📁 Project Structure

```
argocd-terraform-eks/
├── terraform/                     # Infrastructure as Code
│   ├── main.tf                    # Main Terraform configuration
│   ├── variables.tf               # Variable definitions
│   ├── outputs.tf                 # Output definitions
│   ├── versions.tf                # Provider versions
│   ├── providers.tf               # Provider configurations
│   ├── environments/
│   │   └── dev/
│   │       └── terraform.tfvars   # Environment-specific variables
│   └── modules/
│       ├── argocd/                # ArgoCD module
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   ├── outputs.tf
│       │   └── values/
│       │       └── argocd-values.yaml
│       └── eks-addons/            # EKS addons module
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
├── argocd-values.yaml             # Simplified ArgoCD Helm values
├── sample-app.yaml                # Sample ArgoCD application
└── README.md                      # This file
```

## 🔧 Configuration Details

### EKS Cluster Configuration

The EKS cluster is configured with:

- **Cluster Version**: 1.28
- **Node Groups**:
  - General purpose nodes (t3.medium for dev)
  - Spot instances for cost optimization
- **Networking**: Custom VPC with public/private subnets
- **Security**:
  - Encryption at rest using KMS
  - IAM roles with least privilege access
  - Security groups with minimal required access

### ArgoCD Configuration

ArgoCD is configured with:

- **Server**: Running in insecure mode for easy access
- **RBAC**: Role-based access control with admin, developer, and readonly roles
- **Repository**: Connected to your GitOps repository
- **Applications**: Sample guestbook app deployed automatically

### EKS Add-ons

The following add-ons are available:

| Add-on | Purpose | Default |
|--------|---------|---------|
| AWS Load Balancer Controller | Manages ALB/NLB | Enabled |
| External DNS | Automatic DNS record management | Enabled |
| Cert Manager | Automatic TLS certificate management | Enabled |
| Cluster Autoscaler | Automatic node scaling | Enabled |
| Metrics Server | Resource metrics for HPA/VPA | Enabled |
| Prometheus | Monitoring and alerting | Disabled |

## 🌐 Accessing Applications

After deployment, you can access:

1. **ArgoCD UI**: http://localhost:8080 (via port-forward)
   - Username: `admin`
   - Password: Retrieved from Kubernetes secret
2. **Sample Guestbook App**: Deployed in the default namespace

## 🔒 Security Features

### IAM Roles for Service Accounts (IRSA)

The infrastructure uses IRSA for secure access to AWS services:

- **ArgoCD Server**: Role for AWS integrations
- **ArgoCD Application Controller**: Role for ECR access
- **AWS Load Balancer Controller**: Role for ALB/NLB management
- **External DNS**: Role for Route53 management
- **Cert Manager**: Role for Route53 DNS01 challenges
- **Cluster Autoscaler**: Role for EC2 autoscaling

### Encryption

- **EKS Secrets**: Encrypted at rest using KMS
- **EBS Volumes**: Encrypted using KMS keys
- **VPC Flow Logs**: Encrypted CloudWatch logs

### Network Security

- **VPC**: Private subnets for worker nodes
- **Security Groups**: Minimal required access
- **RBAC**: Kubernetes role-based access control

## 📱 Sample Applications

### Deploy a Sample Application

The project includes a sample guestbook application that's automatically deployed. You can create additional applications:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/your-app.git
    targetRevision: HEAD
    path: k8s-manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## 📊 Monitoring and Logging

### CloudWatch Integration

- **EKS Control Plane Logs**: API, audit, authenticator, controllerManager, scheduler
- **VPC Flow Logs**: Network traffic monitoring
- **Custom Metrics**: Available from ArgoCD components

### ArgoCD Health Monitoring

Check application and cluster health:

```bash
# Check ArgoCD applications
kubectl get applications -n argocd

# Check application sync status
kubectl describe application sample-app -n argocd

# Check ArgoCD components
kubectl get pods -n argocd
```

## 🛠️ Troubleshooting

### Common Issues

1. **Terraform State Conflicts**
   ```bash
   # Clean and reinitialize
   rm -rf .terraform .terraform.lock.hcl
   terraform init
   ```

2. **EKS Connection Issues**
   ```bash
   # Update kubeconfig
   aws eks update-kubeconfig --region us-west-2 --name argocd-terraform-dev
   ```

3. **ArgoCD Access Issues**
   ```bash
   # Get new admin password
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

   # Restart port-forward
   kubectl port-forward service/argocd-server -n argocd 8080:443
   ```

4. **Pod Creation Errors**
   ```bash
   # Check events
   kubectl get events --sort-by=.metadata.creationTimestamp -n argocd

   # Check specific pod logs
   kubectl logs -n argocd deployment/argocd-server
   ```

### Validation Steps

```bash
# Verify cluster status
kubectl get nodes
kubectl get pods --all-namespaces

# Verify ArgoCD installation
kubectl get applications -n argocd
kubectl get pods -n argocd

# Check sample application
kubectl get pods -n default | grep guestbook
```

## 🧹 Cleanup

To destroy the infrastructure:

```bash
cd terraform

# Destroy all resources
terraform destroy -var-file="environments/dev/terraform.tfvars" -var="environment=dev" -var="cluster_name=argocd-terraform-dev"
```

**Note**: Some resources like KMS keys have deletion windows and may not be immediately removed.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- [ArgoCD Project](https://argo-cd.readthedocs.io/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/)
- [EKS Terraform Modules](https://github.com/terraform-aws-modules/terraform-aws-eks)

---

**Current Status**: ✅ ArgoCD successfully deployed and configured with sample application running.

**Access Information**:
- ArgoCD UI: http://localhost:8080 (with port-forward)
- Username: admin
- Password: Retrieved via kubectl command above

For questions or support, please open an issue in the repository.
