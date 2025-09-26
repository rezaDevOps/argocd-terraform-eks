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

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

echo "🗑️  WARNING: This will destroy all infrastructure for environment: $ENVIRONMENT"
echo ""

# Validate environment
ENV_DIR="$PROJECT_ROOT/terraform/environments/$ENVIRONMENT"
if [ ! -d "$ENV_DIR" ]; then
    log_error "Environment '$ENVIRONMENT' not found. Available environments: dev, staging, prod"
    exit 1
fi

cd "$ENV_DIR"

# Check if Terraform is initialized
if [ ! -d ".terraform" ]; then
    log_error "Terraform not initialized in $ENV_DIR"
    echo "Please run setup first: ./scripts/setup.sh $ENVIRONMENT"
    exit 1
fi

# Show what will be destroyed
log_info "Checking what will be destroyed..."
if terraform plan -destroy >/dev/null 2>&1; then
    RESOURCE_COUNT=$(terraform plan -destroy 2>/dev/null | grep -c "Plan:" | tail -1 || echo "unknown")
    log_warning "This will destroy infrastructure including:"
    echo "  • EKS Cluster and all workloads"
    echo "  • VPC, subnets, and networking resources" 
    echo "  • Load balancers and security groups"
    echo "  • KMS keys and encrypted volumes"
    echo "  • All applications deployed via ArgoCD"
    echo "  • Any data stored in the cluster (databases, etc.)"
else
    log_warning "Could not generate destroy plan, but will attempt to destroy existing resources"
fi

echo ""
if [ "$ENVIRONMENT" = "prod" ]; then
    log_error "🚨 PRODUCTION ENVIRONMENT DESTRUCTION 🚨"
    echo ""
    echo "You are about to destroy the PRODUCTION environment!"
    echo "This will permanently delete all production data and resources."
    echo "This action cannot be undone."
    echo ""
    read -p "Type 'DELETE-PRODUCTION' to confirm: " confirm
    if [ "$confirm" != "DELETE-PRODUCTION" ]; then
        echo "Destruction cancelled."
        exit 0
    fi
else
    echo "💰 This will stop AWS charges for this environment."
    echo "⚠️  All data will be permanently lost."
    echo "🔄 You can redeploy later with ./scripts/deploy.sh $ENVIRONMENT"
    echo ""
    read -p "Are you sure you want to destroy the $ENVIRONMENT environment? (type 'yes' to confirm): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Destruction cancelled."
        exit 0
    fi
fi

echo ""
log_info "Starting destruction of $ENVIRONMENT environment..."

# Step 1: Try to drain nodes gracefully (if cluster is accessible)
log_info "Attempting to gracefully drain cluster nodes..."
if kubectl get nodes >/dev/null 2>&1; then
    log_info "Cluster is accessible, draining nodes..."
    
    # Delete ArgoCD applications first to avoid conflicts
    if kubectl get applications -n argocd >/dev/null 2>&1; then
        log_info "Deleting ArgoCD applications..."
        kubectl delete applications --all -n argocd --timeout=300s || true
    fi
    
    # Delete all applications in guestbook namespace
    if kubectl get namespace guestbook >/dev/null 2>&1; then
        log_info "Cleaning up guestbook applications..."
        kubectl delete all --all -n guestbook --timeout=300s || true
    fi
    
    # Get all nodes and attempt to drain them
    NODES=$(kubectl get nodes --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null || echo "")
    if [ -n "$NODES" ]; then
        for NODE in $NODES; do
            log_info "Draining node: $NODE"
            kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --force --timeout=300s || true
        done
    fi
    
    log_success "Node draining completed"
else
    log_warning "Cluster not accessible, skipping graceful drain"
fi

# Step 2: Terraform destroy
log_info "Running Terraform destroy..."
START_TIME=$(date +%s)

# Use destroy with auto-approve and parallelism for faster destruction
if terraform destroy -auto-approve -parallelism=10; then
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    log_success "Infrastructure destroyed successfully in ${DURATION} seconds"
else
    log_error "Terraform destroy failed"
    echo ""
    log_warning "Some resources might still exist. Common issues:"
    echo "1. Load balancers or security groups with dependencies"
    echo "2. EBS volumes that couldn't be deleted"
    echo "3. Network interfaces still attached"
    echo ""
    echo "To force cleanup, you can:"
    echo "1. Check AWS Console for remaining resources"
    echo "2. Run terraform destroy again"
    echo "3. Manually delete stuck resources from AWS Console"
    echo ""
    exit 1
fi

# Step 3: Clean up local files
log_info "Cleaning up local state files..."
if [ -f "terraform.tfplan" ]; then
    rm -f terraform.tfplan
    log_info "Removed terraform.tfplan"
fi

if [ -f "argocd-password.txt" ]; then
    rm -f argocd-password.txt
    log_info "Removed argocd-password.txt"
fi

# Step 4: Update kubeconfig (remove cluster context)
log_info "Cleaning up kubeconfig..."
CLUSTER_NAME="${PROJECT_NAME:-argocd-terraform}-${ENVIRONMENT}"
if kubectl config get-contexts -o name | grep -q "$CLUSTER_NAME" 2>/dev/null; then
    kubectl config delete-context "$CLUSTER_NAME" >/dev/null 2>&1 || true
    kubectl config delete-cluster "$CLUSTER_NAME" >/dev/null 2>&1 || true
    log_info "Removed cluster context from kubeconfig"
fi

echo ""
log_success "🎉 Environment '$ENVIRONMENT' has been successfully destroyed!"
echo ""
echo "📊 Summary:"
echo "  🗑️  Environment: $ENVIRONMENT"
echo "  ⏱️  Duration: ${DURATION:-N/A} seconds"
echo "  💰 AWS charges have stopped"
echo "  🔄 You can redeploy anytime with: ./scripts/deploy.sh $ENVIRONMENT"
echo ""

if [ "$ENVIRONMENT" = "prod" ]; then
    log_warning "Production environment destroyed!"
    echo "  📧 Consider notifying your team"
    echo "  📝 Update any external documentation"
    echo "  🔍 Verify no resources remain in AWS Console"
else
    log_info "Development/staging environment cleaned up"
    echo "  🧪 Perfect for testing and experimentation"
    echo "  🔄 Quick to redeploy when needed"
fi

echo ""
log_info "Next steps:"
echo "1. Verify no unexpected AWS charges on your bill"
echo "2. Check AWS Console to confirm all resources are deleted"
echo "3. To redeploy: ./scripts/deploy.sh $ENVIRONMENT"

# Optional: Show any remaining AWS resources (requires AWS CLI)
if command -v aws >/dev/null 2>&1; then
    echo ""
    log_info "Checking for any remaining EKS clusters in your account..."
    REMAINING_CLUSTERS=$(aws eks list-clusters --query 'clusters[?contains(@, `argocd-terraform`)]' --output text 2>/dev/null || echo "")
    if [ -n "$REMAINING_CLUSTERS" ]; then
        log_warning "Found remaining EKS clusters:"
        echo "$REMAINING_CLUSTERS"
    else
        log_success "No remaining EKS clusters found"
    fi
fi
