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

echo "🔐 Retrieving ArgoCD admin credentials..."
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
    exit 1
fi

# Check if ArgoCD namespace exists
if ! kubectl get namespace argocd >/dev/null 2>&1; then
    log_error "ArgoCD namespace not found"
    echo "Make sure ArgoCD is deployed by running: ./scripts/deploy.sh"
    exit 1
fi

# Try to get the initial admin secret
log_info "Looking for ArgoCD initial admin secret..."

if kubectl get secret argocd-initial-admin-secret -n argocd >/dev/null 2>&1; then
    # Get the password from the secret
    PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null)
    
    if [ -n "$PASSWORD" ]; then
        log_success "ArgoCD admin credentials retrieved from initial secret"
        echo ""
        echo "🔑 ArgoCD Admin Credentials:"
        echo "  Username: admin"
        echo "  Password: $PASSWORD"
        echo ""
        log_info "Access ArgoCD at: http://localhost:8080 (after running ./scripts/port-forward.sh)"
        
        # Save password to file for reference
        echo "$PASSWORD" > argocd-password.txt
        log_success "Password saved to: argocd-password.txt"
        
        echo ""
        log_warning "Security Note:"
        echo "  The initial admin secret is automatically generated and stored in Kubernetes."
        echo "  Consider changing the password after first login for additional security."
        echo "  You can delete the initial secret after setting up proper authentication:"
        echo "  kubectl delete secret argocd-initial-admin-secret -n argocd"
    else
        log_error "Could not decode password from secret"
        echo "The secret exists but the password could not be decoded."
    fi
else
    # Initial secret doesn't exist, try alternative methods
    log_warning "Initial admin secret not found"
    echo ""
    
    # Check if ArgoCD server is running
    if kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server >/dev/null 2>&1; then
        SERVER_POD=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        
        if [ -n "$SERVER_POD" ]; then
            log_info "Attempting to retrieve password from ArgoCD server pod..."
            
            # Try to get password from the running pod
            POD_PASSWORD=$(kubectl exec -n argocd "$SERVER_POD" -- argocd admin initial-password 2>/dev/null | head -n1 | tr -d '\n\r' || echo "")
            
            if [ -n "$POD_PASSWORD" ] && [ "$POD_PASSWORD" != "error" ]; then
                log_success "ArgoCD admin credentials retrieved from server pod"
                echo ""
                echo "🔑 ArgoCD Admin Credentials:"
                echo "  Username: admin"
                echo "  Password: $POD_PASSWORD"
                echo ""
                log_info "Access ArgoCD at: http://localhost:8080 (after running ./scripts/port-forward.sh)"
                
                # Save password to file
                echo "$POD_PASSWORD" > argocd-password.txt
                log_success "Password saved to: argocd-password.txt"
            else
                log_error "Could not retrieve password from ArgoCD server pod"
                show_troubleshooting_tips
            fi
        else
            log_error "ArgoCD server pod not found"
            show_troubleshooting_tips
        fi
    else
        log_error "ArgoCD server is not running"
        show_troubleshooting_tips
    fi
fi

show_troubleshooting_tips() {
    echo ""
    log_warning "Troubleshooting tips:"
    echo ""
    echo "1. Check ArgoCD deployment status:"
    echo "   kubectl get pods -n argocd"
    echo ""
    echo "2. Check if ArgoCD is still starting up:"
    echo "   kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server"
    echo ""
    echo "3. Wait for ArgoCD to be fully ready:"
    echo "   kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd"
    echo ""
    echo "4. If you've changed the admin password, use your custom password."
    echo ""
    echo "5. You can reset the admin password by deleting the ArgoCD server pod:"
    echo "   kubectl delete pod -n argocd -l app.kubernetes.io/name=argocd-server"
    echo ""
    echo "6. For custom authentication (SSO), check your ArgoCD configuration:"
    echo "   kubectl get configmap argocd-cm -n argocd -o yaml"
}

echo ""
log_info "Next steps:"
echo "1. Start port-forwarding: ./scripts/port-forward.sh"
echo "2. Open browser to: http://localhost:8080"
echo "3. Login with the credentials above"
echo "4. Explore your applications in the ArgoCD UI"
