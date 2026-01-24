# SMS App Helm Chart

Deploys the SMS spam detection stack (Spring Boot app + Python model service) to Kubernetes.

## Prerequisites

- Kubernetes cluster (1.24+)
- Helm 3.x
- NGINX Ingress Controller (or specify your ingress class)
- kubectl configured to access your cluster

## Quick Start

```bash
# Setup (once) -> run from operation folder
export KUBECONFIG=vm/kubeconfig
echo "192.168.56.95 sms-app.local grafana.local dashboard.local" | sudo tee -a /etc/hosts
echo "192.168.56.96 sms-istio.local" | sudo tee -a /etc/hosts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm dependency build helm/chart

# Basic deploy (app only, no monitoring)
helm upgrade --install sms-app helm/chart -n sms-app --create-namespace --set secrets.smtpPassword=whatever
```

## Build Docker Images

### App Service (from app repo)

Ensure:
```bash
export GHCR_PAT="your_real_pat_here"
echo "$GHCR_PAT"  # Should print your PAT
```

Your PAT needs `repo`, `write:packages`, and `read:packages` privileges.

```bash
mvn clean package -DskipTests
docker build --platform linux/amd64 --no-cache --build-arg GITHUB_TOKEN="$GHCR_PAT" -t ghcr.io/doda2025-team17/app:latest .
docker push ghcr.io/doda2025-team17/app:latest
```

### Model Service (from model-service repo)

```bash
pip install -r requirements.txt --break-system-packages
docker build --platform linux/amd64 --no-cache -t ghcr.io/doda2025-team17/model-service:latest .
docker push ghcr.io/doda2025-team17/model-service:latest
```

If you get `unauthorized` error:
```bash
docker logout ghcr.io
docker login ghcr.io
# Username: YOUR_GITHUB_USERNAME
# Password: YOUR_PAT
```

## Deploy Configurations

### Basic (App Only)
```bash
helm upgrade --install sms-app helm/chart -n sms-app --create-namespace --set secrets.smtpPassword=whatever
```

### With Monitoring + Alerting + Grafana
```bash
# Create SMTP secret first (for email alerts)
kubectl create namespace sms-app --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic smtp-credentials -n sms-app --from-literal=password='your-smtp-password'

# Deploy with full monitoring stack
helm upgrade --install sms-app helm/chart -n sms-app \
  --set secrets.smtpPassword=whatever \
  --set monitoring.enabled=true \
  --set alerting.enabled=true \
  --set kube-prometheus-stack.prometheus.enabled=true \
  --set kube-prometheus-stack.alertmanager.enabled=true \
  --set kube-prometheus-stack.grafana.enabled=true \
  --set kube-prometheus-stack.kubeStateMetrics.enabled=true \
  --set kube-prometheus-stack.nodeExporter.enabled=true
```

### With Istio Canary

```bash
helm upgrade --install sms-app helm/chart -n sms-app \
  --set secrets.smtpPassword=whatever \
  --set istio.enabled=true \
  --set app.canary.enabled=true \
  --set "istio.hosts[0]=sms-istio.local"

# Enable sidecar injection
kubectl label ns sms-app istio-injection=enabled --overwrite
```

### Full Stack (Everything)
```bash
kubectl create namespace sms-app --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic smtp-credentials -n sms-app --from-literal=password='your-smtp-password'

helm upgrade --install sms-app helm/chart -n sms-app \
  --set secrets.smtpPassword=whatever \
  --set monitoring.enabled=true \
  --set alerting.enabled=true \
  --set kube-prometheus-stack.prometheus.enabled=true \
  --set kube-prometheus-stack.alertmanager.enabled=true \
  --set kube-prometheus-stack.grafana.enabled=true \
  --set kube-prometheus-stack.kubeStateMetrics.enabled=true \
  --set kube-prometheus-stack.nodeExporter.enabled=true \
  --set istio.enabled=true \
  --set app.canary.enabled=true \
  --set "istio.hosts[0]=sms-istio.local"

kubectl label ns sms-app istio-injection=enabled --overwrite
```

### With Istio Shadow Launch (model mirroring)

Mirror a percentage of app requests to a shadow version of the model service (no user impact).

```bash
kubectl label ns sms-app istio-injection=disabled --overwrite #need to disable first

helm upgrade --install sms-app helm/chart -n sms-app --create-namespace \
  --set secrets.smtpPassword=whatever \
  --set istio.enabled=true \
  --set modelService.shadow.enabled=true \
  --set modelService.versionLabel=v1 \
  --set modelService.image.tag=latest \
  --set modelService.shadow.versionLabel=v2 \
  --set modelService.shadow.image.tag=latest \
  --set modelService.shadow.mirror.percent=25 \
  --set "istio.hosts[0]=sms-istio.local"

kubectl label ns sms-app istio-injection=enabled --overwrite
```

Test the mirror (example):
```bash
# Send from a meshed client to the model service DNS name (You can open a new terminal and go to "operation" root)
export KUBECONFIG=vm/kubeconfig
kubectl run curl-test --rm -it -n sms-app --image=curlimages/curl --restart=Never \
  --labels="app.kubernetes.io/name=sms-app-app,version=v1" -- \
  /bin/sh -c 'for i in $(seq 1 5); do
    curl -s -X POST -H "Content-Type: application/json" \
      -d "{\"sms\":\"test $i\"}" http://sms-app-model:8081/predict;
    echo; sleep 1;
  done'


# Logs: both stable (v1) and shadow (v2) should show POST /predict
kubectl logs -n sms-app -l app.kubernetes.io/name=sms-app-model,version=v1 --tail=5
kubectl logs -n sms-app -l app.kubernetes.io/name=sms-app-model,version=v2 --tail=5

# Optional: verify metrics split by version/source in Prometheus
kubectl port-forward -n sms-app svc/sms-app-kube-prometheus-st-prometheus 9090:9090

# Open browser and go to
http://localhost:9090

# Then in the Prometheus UI, paste this query in the search box:
sum by (version,source) (rate(sms_model_predictions_total{namespace="sms-app"}[1m])) 

```

## Uninstall

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

## Key Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `namespace.name` | Target namespace | `sms-app` |
| `namespace.create` | Create namespace | `true` |
| `app.replicaCount` | App replicas | `2` |
| `app.image.repository` | App image | `ghcr.io/doda2025-team17/app` |
| `app.image.tag` | App image tag | `latest` |
| `app.versionLabel` | Version label for stable app pods | `v1` |
| `app.canary.enabled` | Enable canary deployment | `false` |
| `app.canary.versionLabel` | Version label for canary pods | `v2` |
| `modelService.replicaCount` | Model service replicas | `1` |
| `modelService.image.repository` | Model service image | `ghcr.io/doda2025-team17/model-service` |
| `modelService.volume.enabled` | Enable shared volume | `true` |
| `modelService.volume.hostPath` | Host path for models | `/mnt/shared/models` |
| `ingress.enabled` | Enable NGINX ingress | `true` |
| `ingress.className` | Ingress class | `nginx` |
| `ingress.hosts[0].host` | Ingress hostname | `sms-app.local` |
| `secrets.smtpPassword` | SMTP password | `CHANGE_ME_IN_HELM` |
| `monitoring.enabled` | Enable ServiceMonitors | `false` |
| `alerting.enabled` | Enable AlertManager config | `false` |
| `kube-prometheus-stack.enabled` | Deploy Prometheus/Grafana/AlertManager | `false` |
| `istio.enabled` | Enable Istio Gateway/VirtualService | `false` |
| `istio.gateway.selector` | IngressGateway pod selector | `{istio: ingressgateway}` |
| `istio.canary.weights.stable` | Traffic % to stable | `90` |
| `istio.canary.weights.canary` | Traffic % to canary | `10` |
| `istio.canary.stickyCookie.enabled` | Enable sticky sessions | `true` |
| `istio.canary.stickyCookie.name` | Cookie name | `sms-app-version` |

## Access Services

| Service | URL | Notes |
|---------|-----|-------|
| App | http://sms-app.local | Via NGINX Ingress |
| App (Istio) | http://sms-istio.local | Via Istio Gateway |
| Grafana | http://grafana.local | Login: admin/admin |
| Prometheus | http://localhost:9090 | port forward: `kubectl port-forward svc/sms-app-kube-prometheus-st-prometheus 9090:9090 -n sms-app` (run `export KUBECONFIG=vm/kubeconfig` before) | 
| AlertManager | http://localhost:9093 | port forward `kubectl port-forward svc/sms-app-kube-prometheus-st-alertmanager 9093:9093 -n sms-app` (run `export KUBECONFIG=vm/kubeconfig ` before) |

## Grafana Dashboards

### Automatic Installation (Default)

When deployed with `kube-prometheus-stack.grafana.enabled=true`, dashboards are automatically provisioned via ConfigMaps. They appear under **Dashboards → SMS App** folder.

### Manual Import (Alternative)

If dashboards are not auto-provisioned or you want to import them manually:

1. Extract the dashboard JSON from the Helm templates:
```bash
   # App metrics dashboard
   helm template sms-app helm/chart \
     --set monitoring.enabled=true \
     --set kube-prometheus-stack.grafana.enabled=true \
     -s templates/grafana-app-configmap.yaml | \
     grep -A 9999 'sms-app-metrics.json' | tail -n +2 > sms-app-metrics.json

   # Experiment dashboard
   helm template sms-app helm/chart \
     --set monitoring.enabled=true \
     --set kube-prometheus-stack.grafana.enabled=true \
     -s templates/grafana-experiment-configmap.yaml | \
     grep -A 9999 'sms-app-experiment.json' | tail -n +2 > sms-app-experiment.json
```

2. Open Grafana: http://grafana.local (login: admin/admin)

3. Go to **Dashboards → Import**

4. Click **Upload JSON file** and select the extracted JSON file

5. Select **Prometheus** as the datasource when prompted

6. Click **Import**

### Available Dashboards

| Dashboard | Description |
|-----------|-------------|
| SMS App Metrics | Main dashboard with classification metrics, latency, cache stats |
| SMS App Experiment | Canary vs stable comparison for A4 experiment decisions |


## Testing

### Test Alerting

```bash
# Terminal 1: Port-forward app
export KUBECONFIG=vm/kubeconfig

kubectl port-forward svc/sms-app-app 8080:80 -n sms-app

# Terminal 2: Generate traffic (triggers HighRequestRate alert after 2min)
export KUBECONFIG=vm/kubeconfig

end=$((SECONDS+150))
while [ $SECONDS -lt $end ]; do
  for i in {1..40}; do curl -s http://localhost:8080/ >/dev/null & done
  wait
  sleep 1
done
```

Check alerts at http://localhost:9090/alerts (should show Firing after ~2 min).

### Email Alerting Configuration

By default, alerting uses placeholder email values (alerts visible in AlertManager UI but no emails sent).

*For actual email delivery (Gmail):*

1. Create a Gmail App Password: https://myaccount.google.com/apppasswords

2. Create the SMTP secret:
```bash
kubectl create secret generic smtp-credentials -n sms-app \
  --from-literal=password='your-16-char-app-password'
```

3. Deploy with real email settings:
```bash
helm upgrade --install sms-app helm/chart -n sms-app \
  --set alerting.enabled=true \
  --set alerting.email.to="your-email@gmail.com" \
  --set alerting.email.from="alerts@your-domain.com" \
  --set alerting.email.username="your-gmail@gmail.com" \
  --set alerting.email.smarthost="smtp.gmail.com:587" \
  --set kube-prometheus-stack.enabled=true
```

### Test Istio Canary Routing

```bash
# Get Istio IngressGateway IP
INGRESS_IP=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo $INGRESS_IP  # Should be 192.168.56.96

# Test basic access
curl -H "Host: sms-istio.local" http://$INGRESS_IP/

# Test weighted routing (run 10 times, ~90% v1, ~10% v2)
for i in {1..10}; do
  curl -s -H "Host: sms-istio.local" http://$INGRESS_IP/ | grep -o 'version=[^"]*' || echo "response received"
done

# Test header-based routing (force canary)
curl -H "Host: sms-istio.local" -H "x-version: canary" http://$INGRESS_IP/

# Test sticky session
curl -c cookies.txt -H "Host: sms-istio.local" http://$INGRESS_IP/
curl -b cookies.txt -H "Host: sms-istio.local" http://$INGRESS_IP/  # Same version

# Check VirtualService routing config
kubectl get vs -n sms-app -o yaml | grep -A 30 "http:"
```

### Test Grafana

1. Open http://grafana.local
2. Login: admin / admin (skip password change)
3. Go to Dashboards → SMS App
4. Verify metrics are showing

## Notes

### Images

Override image tags for pinned releases:
```bash
helm upgrade --install sms-app helm/chart -n sms-app \
  --set app.image.tag=v1.0.0 \
  --set modelService.image.tag=v1.0.0
```

### Ingress

To change hostname:
```bash
helm upgrade --install sms-app helm/chart -n sms-app \
  --set 'ingress.hosts[0].host=myapp.example.com'
```

### HostPath Volume

```bash
# Disable volume
helm upgrade --install sms-app helm/chart -n sms-app \
  --set modelService.volume.enabled=false

# Change path
helm upgrade --install sms-app helm/chart -n sms-app \
  --set modelService.volume.hostPath=/custom/path
```

### Image Pull Secrets

```bash
kubectl create secret docker-registry ghcr-cred -n sms-app \
  --docker-server=ghcr.io \
  --docker-username=YOUR_GITHUB_USER \
  --docker-password=YOUR_PAT

helm upgrade --install sms-app helm/chart -n sms-app \
  --set "imagePullSecrets[0].name=ghcr-cred"
```

## Troubleshooting

### KVM kernel extension error
Run
```bash
sudo modprobe -r kvm_amd kvm
```
or (if the first one doesn't work)
```bash
echo -e "blacklist kvm\nblacklist kvm_amd" | sudo tee /etc/modprobe.d/blacklist-kvm.conf
```

### Helm upgrade hangs
```bash
kubectl delete jobs -n sms-app -l app.kubernetes.io/component=admission-webhook
helm rollback sms-app <last-working-revision> -n sms-app
```

### Pods not starting
```bash
kubectl get pods -n sms-app
kubectl describe pod <pod-name> -n sms-app
kubectl logs <pod-name> -n sms-app
```

### Namespace ownership error
```bash
kubectl delete namespace sms-app
# Wait for deletion, then redeploy
```

### Grafana crashing
Check logs:
```bash
kubectl logs -n sms-app -l app.kubernetes.io/name=grafana -c grafana
```

Common fix — duplicate datasource error: remove custom datasources from values.yaml (kube-prometheus-stack handles it).
