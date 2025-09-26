# ArgoCD App of Apps Pattern

This directory contains a complete implementation of the **App of Apps pattern** for ArgoCD, providing a scalable GitOps solution for managing multiple applications across different environments.

## 🏗️ Architecture Overview

The App of Apps pattern creates a hierarchical structure where a root application manages multiple child applications automatically.

```
┌─────────────────────────────────────────┐
│ 1. ROOT APPLICATION (Manual Deploy)     │
│ environments/dev/app-of-apps.yaml       │
└─────────────────┬───────────────────────┘
                  │ points to
                  ▼
┌─────────────────────────────────────────┐
│ 2. APP FACTORY (Helm Chart)             │
│ apps/                                   │
│ ├── Chart.yaml                          │
│ ├── values.yaml ← defines applications  │
│ └── templates/ ← generates child apps   │
└─────────────────┬───────────────────────┘
                  │ creates child applications
                  ▼
┌─────────────────────────────────────────┐
│ 3. CHILD APPLICATIONS (Auto-Generated)  │
│ guestbook-dev                           │
│ ingress-nginx-dev                       │
│ monitoring-dev (if enabled)             │
└─────────────────┬───────────────────────┘
                  │ deploys actual workloads
                  ▼
┌─────────────────────────────────────────┐
│ 4. ACTUAL APPLICATIONS                   │
│ applications/guestbook/                  │
│ applications/monitoring/                 │
│ applications/platform/                   │
└─────────────────────────────────────────┘
```

## 📁 Directory Structure

```
gitops-repo/
├── environments/                    # Environment-specific configurations
│   ├── dev/
│   │   ├── app-of-apps.yaml        # 🎯 ROOT APP - Deploy this first!
│   │   └── values.yaml             # Dev environment overrides
│   ├── staging/
│   │   ├── app-of-apps.yaml        # Staging root app
│   │   └── values.yaml             # Staging overrides
│   └── prod/
│       ├── app-of-apps.yaml        # Production root app
│       └── values.yaml             # Production overrides
├── apps/                           # 🏭 APP FACTORY (Helm Chart)
│   ├── Chart.yaml                  # Factory chart definition
│   ├── values.yaml                 # Defines which apps to deploy
│   └── templates/
│       ├── applications/
│       │   ├── business-apps.yaml  # Template for business apps
│       │   └── platform-apps.yaml  # Template for platform apps
│       └── infrastructure/
│           └── infrastructure-apps.yaml  # Template for infra apps
└── applications/                   # 📦 ACTUAL APPLICATIONS
    ├── guestbook/                  # Sample business application
    │   ├── Chart.yaml
    │   ├── values.yaml
    │   └── templates/
    │       ├── backend.yaml
    │       ├── database.yaml
    │       └── frontend.yaml
    └── infrastructure/             # Infrastructure applications
        └── ingress-nginx/          # (placeholder for infra apps)
```

## 🚀 Quick Start

### 1. Deploy the Root Application

Choose your environment and deploy the root App of Apps:

```bash
# For development environment
kubectl apply -f environments/dev/app-of-apps.yaml

# For staging environment
kubectl apply -f environments/staging/app-of-apps.yaml

# For production environment
kubectl apply -f environments/prod/app-of-apps.yaml
```

### 2. Verify Deployment

Check that the root application is created:

```bash
kubectl get applications -n argocd
```

You should see:
- `app-of-apps-dev` (or staging/prod)
- Child applications being created automatically

### 3. Monitor Child Applications

Watch as child applications are automatically created and synced:

```bash
# Watch applications
kubectl get applications -n argocd -w

# Check specific application status
kubectl describe application guestbook-dev -n argocd
```

## 🔧 How It Works

### Step 1: Root Application Points to Factory

The root application (`environments/dev/app-of-apps.yaml`) points to the app factory:

```yaml
spec:
  source:
    repoURL: https://github.com/rezaDevOps/argocd-terraform-eks.git
    targetRevision: HEAD
    path: gitops-repo/apps  # 👈 Points to the factory
    helm:
      valueFiles:
        - ../environments/dev/values.yaml  # 👈 Environment-specific config
```

### Step 2: Factory Reads Configuration

The factory (`apps/values.yaml`) defines which applications to deploy:

```yaml
applications:
  guestbook:
    enabled: true                              # 👈 Enable this app
    namespace: guestbook
    syncWave: 1
    path: gitops-repo/applications/guestbook   # 👈 Points to actual app
```

### Step 3: Templates Generate Child Applications

The factory templates (`apps/templates/`) generate ArgoCD Application manifests:

```yaml
# Generated application points to actual workload
spec:
  source:
    repoURL: {{ $.Values.global.repository.url }}
    path: {{ $config.path }}  # gitops-repo/applications/guestbook
```

### Step 4: Child Applications Deploy Workloads

Child applications deploy actual Kubernetes resources from `applications/*/templates/`.

## 🎛️ Configuration

### Environment-Specific Configuration

Each environment has its own values file that overrides defaults:

**`environments/dev/values.yaml`**
```yaml
# Development - minimal resources
applications:
  guestbook:
    enabled: true
    helm:
      values: |
        frontend:
          replicas: 1  # 👈 Single replica for dev
          resources:
            requests:
              cpu: 100m
              memory: 128Mi

infrastructure:
  cert-manager:
    enabled: false  # 👈 Skip for dev to save resources
```

**`environments/prod/values.yaml`**
```yaml
# Production - full resources
applications:
  guestbook:
    enabled: true
    helm:
      values: |
        frontend:
          replicas: 3  # 👈 High availability
          resources:
            requests:
              cpu: 500m
              memory: 512Mi

infrastructure:
  cert-manager:
    enabled: true  # 👈 Enable for production
```

### Sync Waves

Applications are deployed in order using sync waves:

- **Wave -2**: Critical infrastructure (cert-manager)
- **Wave -1**: Platform components (ingress-nginx, external-secrets)
- **Wave 0**: Platform services (monitoring, logging)
- **Wave 1+**: Business applications (guestbook)

## 📦 Adding New Applications

### 1. Create Application Directory

```bash
mkdir -p applications/my-new-app/templates
```

### 2. Create Helm Chart

```yaml
# applications/my-new-app/Chart.yaml
apiVersion: v2
name: my-new-app
description: My new application
version: 0.1.0
```

### 3. Add Kubernetes Resources

Create your templates in `applications/my-new-app/templates/`:

```yaml
# applications/my-new-app/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Values.name }}
spec:
  replicas: {{ .Values.replicas }}
  # ... rest of deployment spec
```

### 4. Configure in Factory

Add your app to `apps/values.yaml`:

```yaml
applications:
  my-new-app:
    enabled: true
    namespace: my-new-app
    syncWave: 2
    targetRevision: HEAD
    path: gitops-repo/applications/my-new-app
```

### 5. Environment-Specific Overrides

Add overrides in `environments/*/values.yaml`:

```yaml
applications:
  my-new-app:
    enabled: true  # or false to disable in this environment
    helm:
      values: |
        replicas: 1
        environment: dev
```

## 🔄 Sync Policies

### Automated Sync

All applications use automated sync with:
- **Prune**: Remove resources not in Git
- **Self-heal**: Revert manual changes
- **Retry**: Automatic retry on failures

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
    - PruneLast=true
```

## 🌍 Multi-Environment Management

### Environment Differences

| Environment | Purpose | Resource Allocation | Features |
|-------------|---------|-------------------|----------|
| **Dev** | Development & Testing | Minimal | Core apps only, no TLS |
| **Staging** | Pre-production | Medium | Full feature set, staging data |
| **Prod** | Production | High | Full HA, monitoring, security |

### Promoting Between Environments

1. **Test in Dev**: Deploy and test changes in development
2. **Promote to Staging**: Update staging configuration
3. **Deploy to Production**: Update production configuration

All promotions are done via Git commits - no manual kubectl commands needed!

## 🛠️ Troubleshooting

### Check Root Application

```bash
kubectl describe application app-of-apps-dev -n argocd
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

### Check Child Applications

```bash
# List all applications
kubectl get applications -n argocd

# Check specific application
kubectl describe application guestbook-dev -n argocd

# Force sync if needed
kubectl patch application guestbook-dev -n argocd --type merge --patch '{"operation":{"initiatedBy":{"username":"admin"},"sync":{}}}'
```

### Check Actual Workloads

```bash
# Check pods
kubectl get pods -n guestbook

# Check services
kubectl get svc -n guestbook

# Check ingress
kubectl get ingress -n guestbook
```

## 🎯 Best Practices

### 1. Environment Isolation
- Use separate ArgoCD projects for different environments
- Use different Git branches for environment-specific changes
- Apply RBAC to control who can deploy to production

### 2. Resource Management
- Use resource quotas and limits
- Implement pod security policies
- Monitor resource usage across environments

### 3. Security
- Use sealed secrets or external secrets operators
- Implement network policies
- Regular security scanning of images

### 4. Monitoring
- Monitor ArgoCD application health
- Set up alerts for sync failures
- Track deployment metrics and rollback capabilities

## 📚 References

- [ArgoCD App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [Helm Chart Best Practices](https://helm.sh/docs/chart_best_practices/)
- [GitOps Principles](https://opengitops.dev/)

## 🤝 Contributing

1. Create feature branch
2. Add/modify applications in `applications/`
3. Update configuration in `apps/values.yaml`
4. Test in development environment
5. Submit pull request

---

This App of Apps implementation provides a scalable, maintainable GitOps solution for managing multiple applications across different environments. Happy deploying! 🚀