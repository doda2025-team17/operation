# SMS App Helm Chart

This chart deploys the SMS spam detection stack (Spring Boot app and Python model service) into a Kubernetes cluster. It creates the namespace, ConfigMap, Secret, Deployments, Services, and optionally Ingress.

## Prerequisites

- Kubernetes cluster (1.24+)
- Helm 3.x
- NGINX Ingress Controller (or specify your ingress class)
- kubectl configured to access your cluster

## First-Time Setup

From the operations repo:
```bash
# Point to the kubeconfig file you plan to use (your own, or the one generated when provisioning)
export KUBECONFIG=vm/kubeconfig
```

Add required Helm repositories (once per machine):
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

Build chart dependencies:
```bash
helm dependency build ./helm/chart
```

Then install:
```bash
helm install sms-app ./helm/chart -n sms-app --create-namespace
```

## Install
From the operations repo:

```bash
# Point to the kubeconfig file you plan to use (your own, or the one generated when provisioning)
export KUBECONFIG=vm/kubeconfig

helm install sms-app ./helm/chart \
  --namespace sms-app \
  --create-namespace
```

Upgrade with custom settings:

```bash
helm upgrade sms-app ./helm/chart \
  --namespace sms-app \
  --create-namespace \
  --set secrets.smtpPassword=whatever \
  --set app.image.tag=monitoring \
  --set modelService.image.tag=monitoring \
  --dependency-update
```

Uninstall:
```bash
helm uninstall sms-app --namespace sms-app
```

## Verify Installation
```bash
# Check all resources
kubectl get all -n sms-app

# Check pods are running
kubectl get pods -n sms-app

# Check ingress
kubectl get ingress -n sms-app

# Test access (after adding to /etc/hosts)
curl http://sms-app.local
```

## Key Values (see `values.yaml`)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `namespace.name` | Target namespace | `sms-app` |
| `namespace.create` | Create namespace | `true` |
| `app.replicaCount` | App replicas | `2` |
| `app.image.repository` | App image | `ghcr.io/doda2025-team17/app` |
| `app.image.tag` | App image tag | `latest` |
| `modelService.replicaCount` | Model service replicas | `1` |
| `modelService.image.repository` | Model service image | `ghcr.io/doda2025-team17/model-service` |
| `modelService.volume.enabled` | Enable shared volume | `true` |
| `modelService.volume.hostPath` | Host path for models | `/mnt/shared/models` |
| `ingress.enabled` | Enable ingress | `true` |
| `ingress.className` | Ingress class | `nginx` |
| `ingress.hosts[0].host` | Ingress hostname | `sms-app.local` |
| `secrets.smtpPassword` | SMTP password | `CHANGE_ME_IN_HELM` |
| `config.*` | ConfigMap values (auto-wired if empty) | - |
| `monitoring.*` | ServiceMonitor labels, metrics ports/paths, scrape interval, toggle monitoring with `monitoring enabled`. |
| `kube-prometheus-stack.*` | toggle the bundled Prometheus dependency |

## Notes

### Images

The chart defaults to images `ghcr.io/doda2025-team17/app:latest` and `ghcr.io/doda2025-team17/model-service:latest`. Override tags for pinned releases:
```bash
helm install sms-app ./helm/chart \
  -n sms-app --create-namespace \
  --set app.image.tag=v1.0.0 \
  --set modelService.image.tag=v1.0.0
```

### Ingress

Ingress is enabled by default with host `sms-app.local` and the NGINX rewrite annotation. Adjust for your controller.

To change hostname:
```bash
helm install sms-app ./helm/chart \
  -n sms-app --create-namespace \
  --set 'ingress.hosts[0].host=myapp.example.com' \
  --set 'ingress.hosts[0].paths[0].path=/' \
  --set 'ingress.hosts[0].paths[0].pathType=Prefix'
```

Don't forget to add the hostname to `/etc/hosts`:
```bash
echo "192.168.56.95 sms-app.local" | sudo tee -a /etc/hosts
```

### Secrets

SMTP secret: set `secrets.smtpPassword` at install/upgrade time.

**Inline:**
```bash
helm install sms-app ./helm/chart \
  -n sms-app --create-namespace \
  --set secrets.smtpPassword=your-smtp-password
```

**Or use a secrets values file** (avoids shell history):
```yaml
# secrets.yaml
secrets:
  smtpPassword: "your-smtp-password"
```
```bash
helm install sms-app ./helm/chart \
  -n sms-app --create-namespace \
  -f secrets.yaml
```

### HostPath Volume

The model service mounts a hostPath at `/mnt/shared/models` by default. Disable or change with `modelService.volume.*` to match your cluster:
```bash
# Disable volume
helm install sms-app ./helm/chart \
  -n sms-app --create-namespace \
  --set modelService.volume.enabled=false

# Change path
helm install sms-app ./helm/chart \
  -n sms-app --create-namespace \
  --set modelService.volume.hostPath=/custom/path
```

### Minikube

For Minikube clusters:
```bash
# Enable ingress addon
minikube addons enable ingress

# Install chart
helm install sms-app ./helm/chart -n sms-app --create-namespace

# Add to /etc/hosts
echo "$(minikube ip) sms-app.local" | sudo tee -a /etc/hosts
```

## Troubleshooting

### Pods not starting
```bash
kubectl describe pod -n sms-app <pod-name>
kubectl logs -n sms-app <pod-name>
```

### Ingress not working
```bash
# Check ingress controller is running
kubectl get pods -n ingress-nginx

# Check ingress configuration
kubectl describe ingress -n sms-app
```

### Image pull errors

Ensure you have access to the GitHub Container Registry or set `imagePullSecrets` in values.yaml.

## Monitoring

The chart includes Prometheus monitoring via kube-prometheus-stack dependency.

### Metrics Endpoints

- App service: `/actuator/prometheus` (Spring Boot Actuator)
- Model service: `/metrics` (Python Prometheus client)

### Disable Monitoring
```bash
helm install sms-app ./helm/chart -n sms-app --create-namespace \
  --set monitoring.enabled=false \
  --set kube-prometheus-stack.enabled=false
```

### Access Prometheus
```bash
kubectl port-forward -n sms-app svc/sms-app-kube-prometheus-prometheus 9090:9090
```

Then open http://localhost:9090