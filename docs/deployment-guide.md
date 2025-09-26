# ArgoCD + Terraform + EKS Deployment Guide

This comprehensive guide walks you through deploying a production-ready EKS cluster with ArgoCD and the App-of-Apps pattern.

## Overview

This project deploys:
- **EKS Cluster** with managed node groups and comprehensive security
- **ArgoCD** with App-of-Apps pattern for GitOps workflow
- **Essential AWS addons** (Load Balancer Controller, External DNS, Cert Manager, etc.)
- **Sample microservices** (Guestbook) demonstrating the complete workflow
- **Multi-environment support** (dev/staging/prod) with appropriate configurations

## Prerequisites

### Required Tools

```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /

# Install kubectl
brew install kubectl

# Install Terraform
brew install terraform

# Install Helm
brew install helm
```

### AWS Account Setup

1. **Configure AWS credentials:**
   ```bash
   aws configure
   # Enter your Access Key ID, Secret Access Key, Region, and Output format
   ```

2. **Verify AWS access:**
   ```bash
   aws sts get-caller-identity
   ```

3. **Required AWS permissions:**
   - EKS cluster creation and management
   - VPC and networking resources
   - IAM roles and policies
   - KMS key management
   - Route53 (if using External DNS)
   - Certificate Manager (if using cert-manager)

### Terraform State Backend (First-time setup)

Create S3 bucket and DynamoDB table for Terraform state:

```bash
# Replace with a unique bucket name
BUCKET_NAME="your-terraform-state-bucket-unique-$(date +%s)"
AWS_REGION="us-west-2"

# Create S3 bucket
aws s3 mb s3://$BUCKET_NAME --region $AWS_REGION

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region $AWS_REGION
```

## Step-by-Step Deployment

### Step 1: Project Setup

```bash
# Clone or download the project
cd /Users/admin/Documents/DEV/AWS/EKS/argocd-terraform-eks

# Make scripts executable
chmod +x scripts/*.sh

# Run initial setup for development environment
./scripts/setup.sh dev
```

### Step 2: Configure Environment

Edit the generated configuration file:

```bash
code terraform/environments/dev/terraform.tfvars
```

**Key configurations to update:**

```hcl
# Core Configuration
aws_region   = "us-west-2"
project_name = "argocd-terraform"

# IMPORTANT: Update these with your actual values
gitops_repo_url = "https://github.com/your-org/gitops-repo.git"
domain_name     = "your-domain.com"  # Optional: for ingress

# EKS Addons - Enable what you need
enable_aws_load_balancer_controller = true
enable_external_dns                 = true   # Requires domain_name
enable_cert_manager                  = true   # Requires domain_name
enable_cluster_autoscaler           = true
enable_metrics_server              = true
enable_prometheus                  = false   # Enable if you want monitoring

# Optional: Add team members
aws_auth_users = [
  {
    userarn  = "arn:aws:iam::123456789012:user/teammate"
    username = "teammate"
    groups   = ["system:masters"]
  }
]
```

### Step 3: Update Backend Configuration

Edit the backend configuration:

```bash
code terraform/environments/dev/backend.tf
```

Update with your actual bucket name:

```hcl
terraform {
  backend "s3" {
    bucket = "your-actual-bucket-name"  # Update this
    key    = "argocd-terraform/dev/terraform.tfstate"
    region = "us-west-2"
    
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

### Step 4: Deploy Infrastructure

```bash
# Deploy the complete infrastructure
./scripts/deploy.sh dev
```

This will:
- ✅ Create EKS cluster with all dependencies
- ✅ Install ArgoCD with proper IRSA roles
- ✅ Deploy AWS Load Balancer Controller
- ✅ Configure External DNS (if enabled)
- ✅ Install Cert Manager (if enabled)
- ✅ Set up Cluster Autoscaler
- ✅ Create the root App-of-Apps application

**Expected deployment time:** 15-20 minutes

### Step 5: Access ArgoCD

1. **Get ArgoCD admin password:**
   ```bash
   ./scripts/get-argocd-password.sh
   ```

2. **Start port-forwarding (in a separate terminal):**
   ```bash
   ./scripts/port-forward.sh
   ```

3. **Access ArgoCD UI:**
   - Open browser to: http://localhost:8080
   - Username: `admin`
   - Password: (from step 1)

### Step 6: Verify Applications

Check that ArgoCD applications are syncing:

```bash
# Check ArgoCD applications
kubectl get applications -n argocd

# Check sample guestbook application
kubectl get pods -n guestbook

# Check all namespaces
kubectl get pods --all-namespaces
```

## Environment-Specific Configurations

### Development Environment

**Features:**
- Smaller instance types (t3.medium)
- Single NAT gateway (cost optimization)
- Minimal replicas
- Simplified monitoring

**Configuration:**
```hcl
# Automatically configured for dev
node_group_instance_types = ["t3.medium"]
single_nat_gateway        = true
node_group_desired_size   = 2
```

### Staging Environment

**Features:**
- Balanced performance (m5.large)
- High availability setup
- Monitoring enabled
- Production-like configuration

**Deployment:**
```bash
./scripts/setup.sh staging
# Edit terraform/environments/staging/terraform.tfvars
./scripts/deploy.sh staging
```

### Production Environment

**Features:**
- High-performance instances (m5.xlarge)
- Multi-AZ deployment
- Full monitoring and logging
- Enhanced security
- Manual sync for safety

**Deployment:**
```bash
./scripts/setup.sh prod
# Carefully edit terraform/environments/prod/terraform.tfvars
./scripts/deploy.sh prod  # Requires additional confirmation
```

## GitOps Repository Structure

If you're using your own GitOps repository, structure it like this:

```
your-gitops-repo/
├── environments/
│   ├── dev/
│   │   ├── app-of-apps.yaml
│   │   └── values.yaml
│   ├── staging/
│   └── prod/
├── apps/
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
└── applications/
    └── guestbook/
        ├── Chart.yaml
        ├── values.yaml
        └── templates/
```

## Application Management

### Adding New Applications

1. **Create application directory:**
   ```bash
   mkdir -p gitops-repo/applications/my-new-app/templates
   ```

2. **Create Helm chart structure:**
   ```yaml
   # gitops-repo/applications/my-new-app/Chart.yaml
   apiVersion: v2
   name: my-new-app
   version: 0.1.0
   ```

3. **Update environment values:**
   ```yaml
   # gitops-repo/environments/dev/values.yaml
   applications:
     my-new-app:
       enabled: true
       namespace: my-new-app
       syncWave: 2
   ```

### Managing Sync Waves

Applications deploy in order based on sync waves:

- **Wave -2:** Critical infrastructure (cert-manager)
- **Wave -1:** Supporting infrastructure (external-secrets, ingress)
- **Wave 0:** Platform services (monitoring, logging)
- **Wave 1+:** Business applications

## Monitoring and Observability

### Enable Prometheus Stack

```hcl
# In terraform.tfvars
enable_prometheus = true
```

Then update your environment values:

```yaml
# In environments/{env}/values.yaml
platform:
  monitoring:
    enabled: true
```

### Accessing Monitoring

```bash
# Port-forward to Grafana
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80

# Access at http://localhost:3000
# Default credentials: admin/prom-operator
```

## Security Considerations

### RBAC Configuration

ArgoCD RBAC is configured with three default roles:

```yaml
# Defined in argocd-values.yaml
roles:
  - role:admin    # Full access
  - role:developer # Limited to specific environments
  - role:readonly  # Read-only access
```

### Network Security

- **Security Groups:** Properly configured for EKS
- **Network Policies:** Available for application-level segmentation
- **Private Subnets:** All worker nodes in private subnets
- **NAT Gateways:** For outbound internet access

### Encryption

- **EKS Secrets:** Encrypted with KMS
- **EBS Volumes:** Encrypted with KMS
- **In-transit:** TLS encryption for all communications

## Cost Optimization

### Development Environment

- Use t3.medium instances
- Single NAT gateway
- Minimal replicas
- **Estimated cost:** $150-200/month

### Production Environment

- Use larger instances for performance
- Multi-AZ setup for HA
- Auto-scaling enabled
- **Estimated cost:** $400-600/month

### Cost-Saving Tips

1. **Use Spot instances for non-critical workloads**
2. **Enable Cluster Autoscaler** for automatic scaling
3. **Monitor unused resources** with AWS Cost Explorer
4. **Use smaller instances** for development
5. **Destroy dev environments** when not in use

## Backup and Disaster Recovery

### Terraform State Backup

```bash
# State is automatically backed up to S3 with versioning
aws s3api list-object-versions --bucket your-terraform-state-bucket
```

### Application Data Backup

```bash
# Backup persistent volumes
kubectl get pv,pvc --all-namespaces

# Use Velero for cluster backups (recommended)
helm install velero vmware-tanzu/velero \
  --namespace velero \
  --create-namespace
```

### Cluster Recreation

```bash
# Complete cluster recreation
./scripts/destroy.sh dev
./scripts/deploy.sh dev
```

## Troubleshooting

See [troubleshooting.md](troubleshooting.md) for common issues and solutions.

## Security Guide

See [security-guide.md](security-guide.md) for security best practices and configurations.

## Next Steps

1. **Explore ArgoCD UI:** Familiarize yourself with the application management interface
2. **Deploy your applications:** Add your own applications to the GitOps repository
3. **Set up CI/CD:** Integrate with your CI/CD pipeline to update application images
4. **Configure monitoring:** Enable and customize monitoring for your applications
5. **Implement security policies:** Add network policies and pod security standards

## Support

For issues and questions:

1. Check the [troubleshooting guide](troubleshooting.md)
2. Review ArgoCD application status in the UI
3. Check Kubernetes events: `kubectl get events --sort-by='.lastTimestamp'`
4. Review pod logs: `kubectl logs -n <namespace> <pod-name>`

## Additional Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
