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

### **Force Kubernetes to pull new images:**
```bash
   cd ~/Desktop/DODA/operation
   export KUBECONFIG=vm/kubeconfig
   kubectl rollout restart deployment -n sms-app
```

### **Verify:**
```bash
   # Watch pods restart
   kubectl get pods -n sms-app -w

   # Check logs for new version
   kubectl logs -n sms-app -l app.kubernetes.io/name=sms-app-app --tail=10

   # Test endpoint
   kubectl port-forward -n sms-app svc/sms-app-app 8080:80
   curl http://localhost:8080/metrics
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

### Test Metrics Endpoint

Verify that the custom Prometheus metrics are being exposed correctly:

```bash
# Terminal 1: Port-forward to app service
export KUBECONFIG=vm/kubeconfig
kubectl port-forward svc/sms-app-app 8080:80 -n sms-app
```

```bash
# Terminal 2: Test metrics endpoint
curl http://localhost:8080/metrics
```

Expected output should include:
- `sms_messages_classified_total` (Counter with labels: result, source, dashboard_version)
- `sms_active_requests` (Gauge with labels: endpoint, dashboard_version)
- `sms_request_latency_seconds_bucket` (Histogram with labels: endpoint, dashboard_version)
- `sms_cache_hits_total`, `sms_cache_misses_total`, `sms_model_calls_total` (Counters)

### Test SMS Classification (Generate Metrics Data)

The metrics are only recorded when making classification requests to `POST /sms`. 
Requests to `/` (root) do NOT generate metrics.

```bash
# Terminal 1: Port-forward to app service (if not already running)
export KUBECONFIG=vm/kubeconfig
kubectl port-forward svc/sms-app-app 8080:80 -n sms-app
```

```bash
# Terminal 2: Generate classification requests
# Single request:
curl -X POST http://localhost:8080/sms \
  -H "Content-Type: application/json" \
  -d '{"sms": "Congratulations! You won a FREE iPhone! Call now!"}'

# Multiple requests to populate metrics:
for i in {1..20}; do
  curl -s -X POST http://localhost:8080/sms \
    -H "Content-Type: application/json" \
    -d '{"sms": "FREE PRIZE! Call now to claim your reward!"}' &
done
wait
echo "Done generating traffic!"

# Verify metrics increased:
curl -s http://localhost:8080/metrics | grep -E "classified_total|latency_seconds_count"
```

Expected output after traffic:
```
sms_messages_classified_total{result="spam",source="web",dashboard_version="v1"} 20
sms_request_latency_seconds_count{endpoint="/sms",dashboard_version="v1"} 20
```

### Test Alerting

The `HighRequestRate` alert fires when the app receives more than 15 requests/minute for 2+ minutes.

**Important:** You must send requests to `POST /sms` (not `/`) for metrics to be recorded!

```bash
# Terminal 1: Port-forward to app service
export KUBECONFIG=vm/kubeconfig
kubectl port-forward svc/sms-app-app 8080:80 -n sms-app
```

```bash
# Terminal 2: Generate sustained traffic for 2.5 minutes (triggers HighRequestRate alert)
export KUBECONFIG=vm/kubeconfig

echo "Generating traffic to trigger alert (2.5 minutes)..."
end=$((SECONDS+150))
while [ $SECONDS -lt $end ]; do
  for i in {1..20}; do
    curl -s -X POST http://localhost:8080/sms \
      -H "Content-Type: application/json" \
      -d '{"sms": "Test message '$i'"}' > /dev/null &
  done
  wait
  echo "Requests sent at $(date +%H:%M:%S)..."
  sleep 2
done
echo "Traffic generation complete!"
```

```bash
# Terminal 3: Monitor alert status in Prometheus
export KUBECONFIG=vm/kubeconfig
kubectl port-forward svc/sms-app-kube-prometheus-st-prometheus 9090:9090 -n sms-app
```

Then open http://localhost:9090/alerts in your browser. The `HighRequestRate` alert should:
1. Show as **Pending** after ~1 minute of traffic
2. Show as **Firing** after 2 minutes of sustained traffic

You can also query the metric directly in Prometheus:
```promql
sum(rate(sms_messages_classified_total{namespace="sms-app"}[1m])) * 60
```
This should show a value > 15 while traffic is being generated.

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

### Test Prometheus Scraping

Verify Prometheus is collecting metrics from your services:

```bash
# Port-forward to Prometheus
export KUBECONFIG=vm/kubeconfig
kubectl port-forward svc/sms-app-kube-prometheus-st-prometheus 9090:9090 -n sms-app
```

1. Open http://localhost:9090
2. Go to **Status → Targets**
3. Look for `serviceMonitor/sms-app/sms-app-app` - should show **UP**
4. Try these queries in the query box:
   - `sms_messages_classified_total` - classification counter
   - `sms_active_requests` - current active requests gauge
   - `rate(sms_request_latency_seconds_count[5m])` - request rate
   - `histogram_quantile(0.95, rate(sms_request_latency_seconds_bucket[5m]))` - p95 latency

### Test Grafana Dashboards

1. Open http://grafana.local
2. Login: admin / admin (skip password change)
3. Go to **Dashboards** → Look for **SMS App** folder
4. Open **SMS App Metrics** dashboard

If dashboards are empty:
- Make sure you've generated traffic using `POST /sms` (see above)
- Check time range is set to "Last 15 minutes" or "Last 1 hour"
- Click the refresh button (🔄) in the top right
- Verify Prometheus datasource is working: **Connections → Data sources → Prometheus → Test**

To test queries directly in Grafana:
1. Click **Explore** (compass icon)
2. Select **Prometheus** datasource
3. Try: `sms_messages_classified_total{namespace="sms-app"}`

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

### Test Canary Metrics Comparison

To verify canary (v2) vs stable (v1) metrics are being recorded separately:

```bash
# Generate traffic through Istio (this distributes to both v1 and v2)
INGRESS_IP=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

for i in {1..30}; do
  curl -s -X POST -H "Host: sms-istio.local" http://$INGRESS_IP/sms \
    -H "Content-Type: application/json" \
    -d '{"sms": "Test message"}' > /dev/null &
done
wait
```

Then in Prometheus (http://localhost:9090), query:
```promql
sum by (version, dashboard_version) (sms_messages_classified_total{namespace="sms-app"})
```

You should see separate counts for `v1` and `v2`.