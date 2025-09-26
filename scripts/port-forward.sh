#!/bin/bash

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

echo "🚀 Starting port-forward to ArgoCD..."
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if we can connect to the cluster
if ! kubectl cluster-info >/dev/null 2>&1; then
    log_error "Cannot connect to Kubernetes cluster"
    echo "Please make sure your kubeconfig is set up correctly."
    echo "You might need to run: aws eks update-kubeconfig --region <region> --name <cluster-name>"
    exit 1
fi

# Check if ArgoCD namespace exists
if ! kubectl get namespace argocd >/dev/null 2>&1; then
    log_error "ArgoCD namespace not found"
    echo "Make sure ArgoCD is deployed by running: ./scripts/deploy.sh"
    exit 1
fi

# Check if ArgoCD server service exists
if ! kubectl get service argocd-server -n argocd >/dev/null 2>&1; then
    log_error "ArgoCD server service not found"
    echo "Make sure ArgoCD is properly deployed."
    exit 1
fi

# Check if ArgoCD server is ready
POD_STATUS=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
if [ "$POD_STATUS" != "Running" ]; then
    log_warning "ArgoCD server pod is not running (Status: $POD_STATUS)"
    log_info "Waiting for ArgoCD server to be ready..."
    
    # Wait up to 5 minutes for the pod to be ready
    if kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s; then
        log_success "ArgoCD server is now ready"
    else
        log_error "ArgoCD server is not ready after 5 minutes"
        echo "Check the pod status with: kubectl get pods -n argocd"
        echo "Check pod logs with: kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server"
        exit 1
    fi
fi

# Get ArgoCD server info
SERVER_POD=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$SERVER_POD" ]; then
    log_success "ArgoCD server pod: $SERVER_POD"
else
    log_warning "Could not find ArgoCD server pod"
fi

# Start port-forward
log_info "Starting port-forward to ArgoCD server..."
echo ""
log_success "ArgoCD UI will be available at: http://localhost:8080"
log_success "Username: admin"
echo ""
log_info "To get the admin password, run (in another terminal):"
echo "  ./scripts/get-argocd-password.sh"
echo ""
log_warning "Press Ctrl+C to stop port-forwarding"
echo ""

# Function to cleanup on exit
cleanup() {
    echo ""
    log_info "Stopping port-forward..."
    log_success "Port-forward stopped"
}

# Set trap to cleanup on script exit
trap cleanup EXIT INT TERM

# Start port-forward (this will block until interrupted)
if kubectl port-forward svc/argocd-server -n argocd 8080:443; then
    log_success "Port-forward completed"
else
    log_error "Port-forward failed"
    echo ""
    echo "Troubleshooting tips:"
    echo "1. Check if port 8080 is already in use: lsof -i :8080"
    echo "2. Try a different port: kubectl port-forward svc/argocd-server -n argocd 8081:443"
    echo "3. Check ArgoCD service status: kubectl get svc -n argocd argocd-server"
    echo "4. Check ArgoCD pods: kubectl get pods -n argocd"
    exit 1
fi
