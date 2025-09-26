# ArgoCD + Terraform + EKS Troubleshooting Guide

This guide covers common issues and their solutions when deploying and operating the ArgoCD + Terraform + EKS stack.

## Table of Contents

1. [Infrastructure Deployment Issues](#infrastructure-deployment-issues)
2. [ArgoCD Issues](#argocd-issues)
3. [Application Deployment Issues](#application-deployment-issues)
4. [Networking Issues](#networking-issues)
5. [Authentication and RBAC Issues](#authentication-and-rbac-issues)
6. [Performance Issues](#performance-issues)
7. [AWS-Specific Issues](#aws-specific-issues)
8. [General Debugging Commands](#general-debugging-commands)

## Infrastructure Deployment Issues

### Terraform Apply Fails

**Issue:** `terraform apply` fails with various errors

**Common Causes and Solutions:**

#### 1. AWS Credentials/Permissions

```bash
# Check credentials
aws sts get-caller-identity

# Check if you have necessary permissions
aws iam get-user
aws iam list-attached-user-policies --user-name YOUR_USERNAME
```

**Required AWS permissions:**
- `AmazonEKSClusterPolicy`
- `AmazonEKSWorkerNodePolicy`
- `AmazonEKS_CNI_Policy`
- `AmazonEC2ContainerRegistryReadOnly`
- VPC and EC2 management permissions

#### 2. Resource Limits

```bash
# Check AWS service limits
aws service-quotas list-service-quotas --service-code eks
aws service-quotas list-service-quotas --service-code ec2
```

**Solution:** Request limit increases through AWS Console if needed

#### 3. EKS Cluster Creation Timeout

```bash
# Check EKS cluster status
aws eks describe-cluster --name argocd-terraform-dev --region us-west-2
```

**Solutions:**
- Increase Terraform timeout in provider configuration
- Check AWS Console for detailed error messages
- Verify subnet configurations and availability zones

#### 4. Node Group Creation Fails

```bash
# Check node group status
aws eks describe-nodegroup --cluster-name argocd-terraform-dev --nodegroup-name general
```

**Common issues:**
- Instance type not available in selected AZ
- Insufficient capacity in selected subnets
- Invalid AMI or instance type

### Backend Configuration Issues

**Issue:** Terraform backend initialization fails

```bash
# Check if S3 bucket exists
aws s3 ls s3://your-terraform-state-bucket

# Check DynamoDB table
aws dynamodb describe-table --table-name terraform-state-lock
```

**Solutions:**
1. Create S3 bucket and DynamoDB table (see deployment guide)
2. Verify bucket permissions
3. Check region consistency

## ArgoCD Issues

### ArgoCD Server Not Starting

**Issue:** ArgoCD server pod not reaching Ready state

```bash
# Check pod status
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server

# Check pod events
kubectl describe pod -n argocd -l app.kubernetes.io/name=argocd-server

# Check pod logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
```

**Common solutions:**
1. **Resource constraints:**
   ```bash
   # Check node resources
   kubectl top nodes
   kubectl describe nodes
   ```

2. **Image pull issues:**
   ```bash
   # Check image pull secrets
   kubectl get secrets -n argocd
   ```

3. **RBAC issues:**
   ```bash
   # Check service account
   kubectl get serviceaccount -n argocd argocd-server
   ```

### ArgoCD Applications Not Syncing

**Issue:** Applications stuck in "OutOfSync" or "Unknown" state

```bash
# Check application status
kubectl get applications -n argocd
kubectl describe application guestbook-dev -n argocd
```

**Common causes:**

#### 1. Git Repository Access
```bash
# Check repository credentials
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=repository

# Test git access from ArgoCD pod
kubectl exec -n argocd deployment/argocd-repo-server -- git ls-remote https://github.com/your-org/gitops-repo.git
```

#### 2. Invalid Manifests
```bash
# Check application events
kubectl get events -n argocd --field-selector involvedObject.name=guestbook-dev

# Validate manifests locally
helm template gitops-repo/applications/guestbook
```

#### 3. Sync Policy Issues
```bash
# Manual sync
kubectl patch application guestbook-dev -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'
```

### ArgoCD UI Access Issues

**Issue:** Cannot access ArgoCD UI via port-forward

**Debugging steps:**
```bash
# Check ArgoCD server service
kubectl get svc -n argocd argocd-server

# Check if port is in use
lsof -i :8080

# Try different port
kubectl port-forward svc/argocd-server -n argocd 8081:443
```

**Alternative access methods:**
```bash
# Create LoadBalancer service (temporary)
kubectl patch svc argocd-server -n argocd -p '{"spec":{"type":"LoadBalancer"}}'

# Get external IP
kubectl get svc -n argocd argocd-server
```

## Application Deployment Issues

### Pods Not Starting

**Issue:** Application pods stuck in Pending or CrashLoopBackOff

```bash
# Check pod status
kubectl get pods -n guestbook
kubectl describe pod -n guestbook POD_NAME
kubectl logs -n guestbook POD_NAME
```

**Common solutions:**

#### 1. Resource Constraints
```bash
# Check resource quotas
kubectl describe quota -n guestbook
kubectl top nodes
kubectl top pods -n guestbook
```

#### 2. Image Pull Issues
```bash
# Check if image exists
docker pull gcr.io/heptio-images/ks-guestbook-demo:0.2

# Check image pull secrets
kubectl get secrets -n guestbook
```

#### 3. Configuration Issues
```bash
# Check ConfigMaps and Secrets
kubectl get configmaps -n guestbook
kubectl get secrets -n guestbook

# Validate environment variables
kubectl exec -n guestbook FRONTEND_POD -- env | grep GUESTBOOK
```

### Persistent Volume Issues

**Issue:** PVCs stuck in Pending state

```bash
# Check PVC status
kubectl get pvc -n guestbook
kubectl describe pvc -n guestbook redis-pvc

# Check storage classes
kubectl get storageclass
```

**Solutions:**
1. **EBS CSI Driver not installed:**
   ```bash
   kubectl get pods -n kube-system -l app=ebs-csi-controller
   ```

2. **Insufficient permissions:**
   ```bash
   # Check EBS CSI driver IAM role
   kubectl describe pod -n kube-system -l app=ebs-csi-controller
   ```

## Networking Issues

### Ingress Not Working

**Issue:** Applications not accessible via ingress

```bash
# Check ingress status
kubectl get ingress -n guestbook
kubectl describe ingress -n guestbook guestbook-frontend-ingress
```

**Common solutions:**

#### 1. AWS Load Balancer Controller Issues
```bash
# Check controller status
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

#### 2. DNS Resolution
```bash
# Check External DNS
kubectl get pods -n external-dns
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns

# Check Route53 records
aws route53 list-hosted-zones
aws route53 list-resource-record-sets --hosted-zone-id YOUR_ZONE_ID
```

### Service Discovery Issues

**Issue:** Services cannot communicate with each other

```bash
# Test service connectivity
kubectl exec -n guestbook FRONTEND_POD -- nslookup guestbook-backend
kubectl exec -n guestbook FRONTEND_POD -- curl -v guestbook-backend:3000/healthz
```

**Common solutions:**

#### 1. Network Policies
```bash
# Check network policies
kubectl get networkpolicies -n guestbook
kubectl describe networkpolicy -n guestbook
```

#### 2. DNS Issues
```bash
# Check CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns
```

## Authentication and RBAC Issues

### ArgoCD RBAC Issues

**Issue:** Users cannot access specific applications

```bash
# Check ArgoCD RBAC configuration
kubectl get configmap argocd-rbac-cm -n argocd -o yaml

# Test user permissions
argocd app list --auth-token YOUR_TOKEN
```

**Solutions:**
1. **Update RBAC policy:**
   ```bash
   kubectl edit configmap argocd-rbac-cm -n argocd
   ```

2. **Check user groups:**
   ```bash
   # Verify user groups in ArgoCD
   kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server | grep "user groups"
   ```

### AWS Auth Issues

**Issue:** Cannot access EKS cluster

```bash
# Check aws-auth ConfigMap
kubectl get configmap aws-auth -n kube-system -o yaml

# Test cluster access
aws eks update-kubeconfig --region us-west-2 --name argocd-terraform-dev
kubectl auth can-i get pods --as=system:node:YOUR_USER
```

## Performance Issues

### Slow Application Sync

**Issue:** ArgoCD applications take too long to sync

```bash
# Check ArgoCD controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Check resource usage
kubectl top pods -n argocd
```

**Solutions:**
1. **Increase controller resources:**
   ```bash
   kubectl patch deployment argocd-application-controller -n argocd -p '{"spec":{"template":{"spec":{"containers":[{"name":"application-controller","resources":{"requests":{"cpu":"2000m","memory":"2Gi"}}}]}}}}'
   ```

2. **Reduce sync frequency:**
   ```yaml
   # In argocd-cm ConfigMap
   timeout.reconciliation: 300s
   ```

### Node Performance Issues

**Issue:** Nodes running out of resources

```bash
# Check node resources
kubectl top nodes
kubectl describe nodes

# Check resource requests vs limits
kubectl describe quota --all-namespaces
```

**Solutions:**
1. **Enable Cluster Autoscaler:**
   ```bash
   kubectl get deployment cluster-autoscaler -n kube-system
   ```

2. **Adjust resource requests:**
   ```yaml
   # In application values
   resources:
     requests:
       cpu: 100m
       memory: 128Mi
   ```

## AWS-Specific Issues

### IRSA Role Issues

**Issue:** Pods cannot assume AWS IAM roles

```bash
# Check service account annotations
kubectl get serviceaccount -n kube-system aws-load-balancer-controller -o yaml

# Check pod environment variables
kubectl exec POD_NAME -- env | grep AWS
```

**Solutions:**
1. **Verify OIDC provider:**
   ```bash
   aws eks describe-cluster --name argocd-terraform-dev --query "cluster.identity.oidc.issuer"
   aws iam list-open-id-connect-providers
   ```

2. **Check IAM role trust policy:**
   ```bash
   aws iam get-role --role-name argocd-terraform-dev-aws-load-balancer-controller
   ```

### VPC and Networking Issues

**Issue:** Connectivity problems between resources

```bash
# Check VPC configuration
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=argocd-terraform-dev"

# Check security groups
aws ec2 describe-security-groups --filters "Name=group-name,Values=*argocd-terraform-dev*"
```

## General Debugging Commands

### Cluster Health Check

```bash
#!/bin/bash
echo "=== Cluster Info ==="
kubectl cluster-info

echo "=== Node Status ==="
kubectl get nodes -o wide

echo "=== System Pods ==="
kubectl get pods -n kube-system

echo "=== ArgoCD Status ==="
kubectl get pods -n argocd
kubectl get applications -n argocd

echo "=== Application Status ==="
kubectl get pods --all-namespaces -l app.kubernetes.io/managed-by=argocd

echo "=== Recent Events ==="
kubectl get events --sort-by='.lastTimestamp' | tail -20
```

### Log Collection Script

```bash
#!/bin/bash
NAMESPACE=${1:-guestbook}
OUTPUT_DIR="debug-logs-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUTPUT_DIR"

# Collect pod logs
for pod in $(kubectl get pods -n $NAMESPACE -o name); do
    echo "Collecting logs for $pod"
    kubectl logs -n $NAMESPACE $pod > "$OUTPUT_DIR/${pod//\//-}.log" 2>&1
done

# Collect events
kubectl get events -n $NAMESPACE > "$OUTPUT_DIR/events.txt"

# Collect descriptions
kubectl describe pods -n $NAMESPACE > "$OUTPUT_DIR/pod-descriptions.txt"

echo "Debug information collected in $OUTPUT_DIR"
```

### Quick Health Check

```bash
# One-liner health check
kubectl get pods --all-namespaces | grep -v Running | grep -v Completed
```

## Getting Help

### ArgoCD Specific
1. Check ArgoCD documentation: https://argo-cd.readthedocs.io/
2. ArgoCD Slack community: https://argoproj.github.io/community/join-slack/
3. GitHub issues: https://github.com/argoproj/argo-cd/issues

### Kubernetes General
1. Kubernetes documentation: https://kubernetes.io/docs/
2. Kubernetes Slack: http://slack.k8s.io/
3. Stack Overflow: Use tags `kubernetes`, `amazon-eks`

### AWS EKS Specific
1. AWS EKS documentation: https://docs.aws.amazon.com/eks/
2. AWS Support (if you have a support plan)
3. AWS forums: https://forums.aws.amazon.com/

### Emergency Procedures

#### Complete Cluster Reset
```bash
# If everything is broken, reset the cluster
./scripts/destroy.sh dev
./scripts/deploy.sh dev
```

#### ArgoCD Reset
```bash
# Reset ArgoCD only
kubectl delete namespace argocd
# Re-run Terraform apply to recreate ArgoCD
```

#### Application Reset
```bash
# Reset specific application
kubectl delete application guestbook-dev -n argocd
# Let ArgoCD recreate it from Git
```

Remember: Most issues are temporary and can be resolved by understanding the error messages and checking the relevant logs. Take your time to read error messages carefully and use the debugging commands provided above.
