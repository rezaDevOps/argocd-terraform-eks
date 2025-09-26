#!/bin/bash
set -e

ENVIRONMENT=${1:-dev}
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Helper functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

echo "🚀 Deploying ArgoCD Terraform EKS infrastructure for environment: $ENVIRONMENT"
echo ""

# Validate environment
ENV_DIR="$PROJECT_ROOT/terraform/environments/$ENVIRONMENT"
if [ ! -d "$ENV_DIR" ]; then
    log_error "Environment '$ENVIRONMENT' not found. Available environments: dev, staging, prod"
    exit 1
fi

cd "$ENV_DIR"

# Check if setup was run
if [ ! -f "terraform.tfvars" ]; then
    log_error "terraform.tfvars not found. Please run setup first:"
    echo "  ./scripts/setup.sh $ENVIRONMENT"
    exit 1
fi

if [ ! -f ".terraform/terraform.tfstate" ] && [ ! -f "terraform.tfplan" ]; then
    log_warning "Terraform not initialized. Running setup first..."
    "$SCRIPT_DIR/setup.sh" "$ENVIRONMENT"
fi

# Confirm deployment for production
if [ "$ENVIRONMENT" = "prod" ]; then
    log_warning "You are about to deploy to PRODUCTION environment!"
    echo ""
    read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Deployment cancelled."
        exit 0
    fi
    echo ""
fi

# Plan
log_info "Creating Terraform execution plan..."
if terraform plan -out=terraform.tfplan; then
    log_success "Terraform plan created successfully"
else
    log_error "Terraform plan failed"
    exit 1
fi

echo ""
log_warning "Review the plan above. This will create AWS resources that may incur costs."
echo ""
echo "📊 Estimated deployment time: 15-20 minutes"
echo "💰 Estimated monthly cost (varies by region and usage):"
echo "  - Development: $150-200/month"
echo "  - Staging: $250-350/month"
echo "  - Production: $400-600/month"
echo ""

if [ "$ENVIRONMENT" != "dev" ]; then
    read -p "Do you want to proceed with the deployment? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Deployment cancelled."
        exit 0
    fi
fi

# Apply
log_info "Applying Terraform configuration..."
START_TIME=$(date +%s)

if terraform apply terraform.tfplan; then
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    log_success "Terraform apply completed in ${DURATION} seconds"
else
    log_error "Terraform apply failed"
    exit 1
fi

# Update kubeconfig
log_info "Updating kubeconfig..."
if terraform output cluster_name >/dev/null 2>&1; then
    CLUSTER_NAME=$(terraform output -raw cluster_name)
    AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-west-2")
    
    if aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"; then
        log_success "Kubeconfig updated for cluster: $CLUSTER_NAME"
    else
        log_warning "Failed to update kubeconfig. You can update it manually with:"
        echo "  aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME"
    fi
else
    log_warning "Could not determine cluster name from Terraform output"
fi

# Wait for cluster to be ready
log_info "Waiting for EKS cluster to be ready..."
if kubectl cluster-info >/dev/null 2>&1; then
    log_success "EKS cluster is accessible"
else
    log_warning "EKS cluster not immediately accessible. This is normal, please wait a few minutes."
fi

# Wait for ArgoCD to be ready
log_info "Waiting for ArgoCD to be ready (this may take several minutes)..."
if kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd 2>/dev/null; then
    log_success "ArgoCD server is ready"
else
    log_warning "ArgoCD server not ready yet. You can check status with:"
    echo "  kubectl get pods -n argocd"
fi

# Check if root application was created
log_info "Checking ArgoCD applications..."
sleep 30  # Give ArgoCD time to sync
if kubectl get application -n argocd >/dev/null 2>&1; then
    APP_COUNT=$(kubectl get application -n argocd --no-headers 2>/dev/null | wc -l || echo "0")
    if [ "$APP_COUNT" -gt 0 ]; then
        log_success "Found $APP_COUNT ArgoCD application(s)"
        echo ""
        echo "📱 ArgoCD Applications:"
        kubectl get application -n argocd -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status 2>/dev/null || true
    else
        log_warning "No ArgoCD applications found yet. They may still be syncing."
    fi
else
    log_warning "ArgoCD applications not accessible yet"
fi

# Final status check
echo ""
log_info "Deployment Summary:"
echo "  🏗️  Infrastructure: Deployed"
echo "  🎯 Environment: $ENVIRONMENT"
echo "  ⚙️  Cluster: $CLUSTER_NAME"
echo "  🌍 Region: $AWS_REGION"

# Get service information
if kubectl get svc -n argocd argocd-server >/dev/null 2>&1; then
    ARGOCD_SERVICE=$(kubectl get svc -n argocd argocd-server -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "Not available")
    echo "  🚀 ArgoCD Service: $ARGOCD_SERVICE"
fi

echo ""
log_success "🎉 Deployment completed successfully!"
echo ""
echo "🚀 Next steps:"
echo "1. Get ArgoCD admin password:"
echo "   ./scripts/get-argocd-password.sh"
echo ""
echo "2. Access ArgoCD UI (in a new terminal):"
echo "   ./scripts/port-forward.sh"
echo ""
echo "3. Open your browser to:"
echo "   http://localhost:8080"
echo ""
echo "4. Check application status:"
echo "   kubectl get applications -n argocd"
echo "   kubectl get pods -n guestbook"
echo ""
echo "📚 For more information:"
echo "   - Documentation: $PROJECT_ROOT/docs/"
echo "   - Troubleshooting: kubectl describe applications -n argocd"
echo ""

if [ "$ENVIRONMENT" = "dev" ]; then
    echo "💡 Development Tips:"
    echo "   - Use 'kubectl port-forward' to access services locally"
    echo "   - ArgoCD will automatically sync your GitOps repository"  
    echo "   - Check application logs: kubectl logs -n guestbook -l app.kubernetes.io/name=guestbook-frontend"
fi
