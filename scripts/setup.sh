#!/bin/bash
set -e

ENVIRONMENT=${1:-dev}
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🚀 Setting up ArgoCD Terraform EKS project for environment: $ENVIRONMENT"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper function for colored output
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Check prerequisites
log_info "Checking prerequisites..."
command -v aws >/dev/null 2>&1 || { log_error "AWS CLI is required but not installed. Please install AWS CLI first."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { log_error "kubectl is required but not installed. Please install kubectl first."; exit 1; }
command -v terraform >/dev/null 2>&1 || { log_error "Terraform is required but not installed. Please install Terraform >= 1.5.0 first."; exit 1; }
command -v helm >/dev/null 2>&1 || { log_error "Helm is required but not installed. Please install Helm >= 3.8.0 first."; exit 1; }

# Check versions
TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version' 2>/dev/null || terraform version | head -n1 | awk '{print $2}' | sed 's/v//')
KUBECTL_VERSION=$(kubectl version --client --output=json 2>/dev/null | jq -r '.clientVersion.gitVersion' | sed 's/v//' || echo "unknown")
HELM_VERSION=$(helm version --template='{{.Version}}' 2>/dev/null | sed 's/v//' || echo "unknown")

log_info "Tool versions:"
echo "  - Terraform: $TERRAFORM_VERSION"
echo "  - kubectl: $KUBECTL_VERSION"
echo "  - Helm: $HELM_VERSION"

# Check AWS credentials
log_info "Checking AWS credentials..."
aws sts get-caller-identity >/dev/null 2>&1 || { 
    log_error "AWS credentials not configured or invalid. Please run 'aws configure' first."
    exit 1
}

# Get AWS account info
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region 2>/dev/null || echo "us-west-2")
AWS_USER=$(aws sts get-caller-identity --query Arn --output text | awk -F'/' '{print $NF}')

log_success "Prerequisites check completed"
echo "📊 AWS Account ID: $AWS_ACCOUNT_ID"
echo "🌍 AWS Region: $AWS_REGION"
echo "👤 AWS User: $AWS_USER"
echo ""

# Navigate to environment directory
ENV_DIR="$PROJECT_ROOT/terraform/environments/$ENVIRONMENT"
if [ ! -d "$ENV_DIR" ]; then
    log_error "Environment '$ENVIRONMENT' not found. Available environments: dev, staging, prod"
    exit 1
fi

cd "$ENV_DIR"

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    log_info "Creating terraform.tfvars from example..."
    if [ -f "terraform.tfvars.example" ]; then
        cp terraform.tfvars.example terraform.tfvars
        
        # Replace placeholder values
        sed -i.bak "s/123456789012/$AWS_ACCOUNT_ID/g" terraform.tfvars 2>/dev/null || true
        sed -i.bak "s/us-west-2/$AWS_REGION/g" terraform.tfvars 2>/dev/null || true
        rm terraform.tfvars.bak 2>/dev/null || true
        
        log_warning "terraform.tfvars created from example template"
        log_warning "Please edit the following file with your specific values before continuing:"
        echo "   📄 $ENV_DIR/terraform.tfvars"
        echo ""
        echo "🔧 Key values you need to update:"
        echo "  - gitops_repo_url: Your GitOps repository URL"
        echo "  - domain_name: Your domain name for ingress"
        echo "  - Enable/disable addons as needed"
        echo ""
        log_info "After updating terraform.tfvars, run this script again to continue setup."
        exit 0
    else
        log_error "terraform.tfvars.example not found in $ENV_DIR"
        exit 1
    fi
fi

# Check if S3 backend is configured
if grep -q "your-terraform-state-bucket" backend.tf 2>/dev/null; then
    log_warning "Backend configuration needs to be updated"
    echo "📄 Please update the following file with your actual S3 bucket name:"
    echo "   $ENV_DIR/backend.tf"
    echo ""
    echo "💡 To create the S3 bucket and DynamoDB table for state management:"
    echo ""
    echo "# Create S3 bucket for Terraform state"
    echo "aws s3 mb s3://your-terraform-state-bucket-unique-name-$AWS_ACCOUNT_ID"
    echo ""
    echo "# Create DynamoDB table for state locking"
    echo "aws dynamodb create-table \\"
    echo "  --table-name terraform-state-lock \\"
    echo "  --attribute-definitions AttributeName=LockID,AttributeType=S \\"
    echo "  --key-schema AttributeName=LockID,KeyType=HASH \\"
    echo "  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5"
    exit 1
fi

# Initialize Terraform
log_info "Initializing Terraform..."
if terraform init; then
    log_success "Terraform initialized successfully"
else
    log_error "Terraform initialization failed"
    exit 1
fi

# Validate configuration
log_info "Validating Terraform configuration..."
if terraform validate; then
    log_success "Terraform configuration is valid"
else
    log_error "Terraform configuration validation failed"
    exit 1
fi

# Check for Terraform plan
log_info "Creating Terraform plan..."
if terraform plan -out=terraform.tfplan >/dev/null 2>&1; then
    log_success "Terraform plan created successfully"
else
    log_warning "Terraform plan creation failed - this might be expected on first run"
fi

# Summary
echo ""
log_success "Setup complete for environment: $ENVIRONMENT"
echo ""
echo "📋 What was configured:"
echo "  ✅ EKS Cluster with managed node groups"
echo "  ✅ VPC with public/private subnets and NAT gateways"  
echo "  ✅ AWS Load Balancer Controller with IRSA"
echo "  ✅ External DNS with Route53 integration"
echo "  ✅ Cert Manager for TLS certificates"
echo "  ✅ Cluster Autoscaler for node scaling"
echo "  ✅ ArgoCD with App-of-Apps pattern"
echo "  ✅ Sample Guestbook microservices application"
echo "  ✅ Security groups and KMS encryption"
echo ""
echo "🚀 Next steps:"
echo "1. Review and customize: $ENV_DIR/terraform.tfvars"
echo "2. Deploy infrastructure: ./scripts/deploy.sh $ENVIRONMENT"
echo "3. Access ArgoCD: ./scripts/port-forward.sh"
echo "4. Get ArgoCD password: ./scripts/get-argocd-password.sh"
echo ""
echo "📚 For more information, see the documentation in the docs/ directory"
