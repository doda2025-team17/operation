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

# Add NGINX Ingress hostnames
NGINX_IP=$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
sudo sed -i '/sms-nginx\.local/d;/grafana\.local/d;/dashboard\.local/d' /etc/hosts
echo "$NGINX_IP sms-nginx.local grafana.local dashboard.local" | sudo tee -a /etc/hosts

# Add Istio Gateway hostnames
ISTIO_IP=$(kubectl -n istio-system get svc istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
sudo sed -i '/sms-app\.local/d;/stable\.sms-app\.local/d;/canary\.sms-app\.local/d' /etc/hosts
echo "$ISTIO_IP sms-app.local stable.sms-app.local canary.sms-app.local" | sudo tee -a /etc/hosts

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm dependency build helm/chart

# Basic deploy (app only, no monitoring)
helm upgrade --install sms-app helm/chart -n sms-app --create-namespace
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

### Force Kubernetes to pull new images

```bash
cd ~/Desktop/DODA/operation
export KUBECONFIG=vm/kubeconfig
kubectl rollout restart deployment -n sms-app
```

## Deploy Configurations

### Basic (App Only)

```bash
helm upgrade --install sms-app helm/chart -n sms-app --create-namespace
```

### With Monitoring + Alerting + Grafana

```bash
# Create SMTP secret first (for email alerts)
kubectl create namespace sms-app --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic smtp-credentials -n sms-app --from-literal=password='your-smtp-password'

# Deploy with full monitoring stack
helm upgrade --install sms-app helm/chart -n sms-app \
  --set monitoring.enabled=true \
  --set alerting.enabled=true \
  --set kube-prometheus-stack.prometheus.enabled=true \
  --set kube-prometheus-stack.alertmanager.enabled=true \
  --set kube-prometheus-stack.grafana.enabled=true \
  --set kube-prometheus-stack.kubeStateMetrics.enabled=true \
  --set kube-prometheus-stack.nodeExporter.enabled=true
```

### With Istio Canary (Paired Routing)

Enables canary deployments for both app and model with paired routing (app v2 → model v2).

```bash
helm upgrade --install sms-app helm/chart -n sms-app \
  --set istio.enabled=true \
  --set app.canary.enabled=true \
  --set modelService.canary.enabled=true

# Enable sidecar injection
kubectl label ns sms-app istio-injection=enabled --overwrite
```

### Full Stack (Everything Besides Shadow)

```bash
kubectl create namespace sms-app --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic smtp-credentials -n sms-app --from-literal=password='your-smtp-password'

helm upgrade --install sms-app helm/chart -n sms-app \
  --set monitoring.enabled=true \
  --set alerting.enabled=true \
  --set kube-prometheus-stack.prometheus.enabled=true \
  --set kube-prometheus-stack.alertmanager.enabled=true \
  --set kube-prometheus-stack.grafana.enabled=true \

# *   --set kube-prometheus-stack.kubeStateMetrics.enabled=true \

  --set kube-prometheus-stack.nodeExporter.enabled=true \
  --set istio.enabled=true \
  --set app.canary.enabled=true \
  --set modelService.canary.enabled=true

kubectl label ns sms-app istio-injection=enabled --overwrite
```

### With Istio Shadow Launch (Model Mirroring)

Mirror a percentage of model requests to a shadow version (no user impact). **Note:** Shadow mode and canary mode are mutually exclusive for the model service.

```bash
kubectl label ns sms-app istio-injection=disabled --overwrite  # Disable first if enabled

helm upgrade --install sms-app helm/chart -n sms-app --create-namespace \
  --set istio.enabled=true \
  --set modelService.shadow.enabled=true \
  --set modelService.shadow.mirror.enabled=true \
  --set modelService.shadow.mirror.percent=25

kubectl label ns sms-app istio-injection=enabled --overwrite
```

Test the mirror:

```bash
# Send requests from a meshed client to the model service
export KUBECONFIG=vm/kubeconfig
kubectl run curl-test --rm -it -n sms-app --image=curlimages/curl --restart=Never \
  --labels="app.kubernetes.io/name=sms-app-app,version=v1" -- \
  /bin/sh -c 'for i in $(seq 1 5); do
    curl -s -X POST -H "Content-Type: application/json" \
      -d "{\"sms\":\"test $i\"}" http://sms-app-model:8081/predict;
    echo; sleep 1;
  done'

# Logs: both stable (v1) and shadow should show POST /predict
kubectl logs -n sms-app -l app.kubernetes.io/name=sms-app-model,version=v1 --tail=5
kubectl logs -n sms-app -l app.kubernetes.io/name=sms-app-model,version=shadow --tail=5

# Verify metrics split by version in Prometheus
kubectl port-forward -n sms-app svc/sms-app-kube-prometheus-st-prometheus 9090:9090
# Open browser and go to
http://localhost:9090

# Then in the Prometheus UI, paste this query in the search box:
sum by (version,source) (rate(sms_model_predictions_total{namespace="sms-app"}[1m]))
```

### Experiment - Canary Deployment + Traffic Generation
This experiment demonstrates:

- App v1 (stable) and App v2 (canary) running simultaneously
- Istio weighted routing (90% → v1, 10% → v2)
- Metrics collection in Grafana / Prometheus
- Load generation for validating behavior

#### Step 1 – Start the Cluster

From the `operation/vm` directory:

```bash
vagrant up
```

#### Step 2 – Configure kubectl and Secrets
From the operation root folder:
```bash
export KUBECONFIG=$PWD/vm/kubeconfig

kubectl create ns sms-app --dry-run=client -o yaml | kubectl apply -f -

kubectl -n sms-app create secret generic smtp-credentials \
  --from-literal=SMTP_PASSWORD=dummy \
  --dry-run=client -o yaml | kubectl apply -f -
```

#### Step 3 – Deploy Helm (Canary + Monitoring + Istio)
```bash
kubectl label ns sms-app istio-injection=disabled --overwrite

helm upgrade --install sms-app helm/chart -n sms-app --create-namespace \
  --set istio.enabled=true \
  --set monitoring.enabled=true \
  --set alerting.enabled=true \
  --set kube-prometheus-stack.prometheus.enabled=true \
  --set kube-prometheus-stack.alertmanager.enabled=true \
  --set kube-prometheus-stack.grafana.enabled=true \
  --set kube-prometheus-stack.kubeStateMetrics.enabled=true \
  --set kube-prometheus-stack.nodeExporter.enabled=true \
  --set app.canary.enabled=true \
  --set modelService.canary.enabled=true \
  --set app.image.tag=1.0.5 \
  --set app.canary.image.tag=1.0.6 \
  --set modelService.image.tag=1.0.2 \
  --set modelService.canary.image.tag=1.0.3 \
  --set istio.canary.weights.stable=90 \
  --set istio.canary.weights.canary=10 \
  --wait --timeout 15m

kubectl label ns sms-app istio-injection=enabled --overwrite
```

#### Step 4 – Verify Pods Are Running
```bash
kubectl -n sms-app get pods -w
```

#### Step 5 – Port Forward Services
Terminal 1 – App v1
```bash
kubectl -n sms-app port-forward deploy/sms-app-app 8081:8080
```

Terminal 2 – App v2
```bash
kubectl -n sms-app port-forward deploy/sms-app-app-canary 8082:8080
```

Terminal 3 – Grafana
```bash
Terminal 3 – Grafana
```

#### Step 6 – Generate Traffic
Terminal 4 - Hit App v1
```bash
for i in {1..200}; do
  curl -s -X POST http://localhost:8081/sms \
    -H "Content-Type: application/json" \
    -d '{"sms":"repeat-this-sms"}' > /dev/null &
done
wait
```

Terminal 5 - Hit App v2
```bash
for i in {1..200}; do
  curl -s -X POST http://localhost:8082/sms \
    -H "Content-Type: application/json" \
    -d '{"sms":"repeat-this-sms"}' > /dev/null &
done
wait
```

#### Step 7 – Observe Metrics in Grafana
Open Grafana UI:
http://localhost:3000

Navigate to:
```bash
Dashboards → SMS App → Continuous Experimentation (App v1 vs v2)
```

You should observe:
- Cache Hits / Misses 
- Model Calls per version 
- Latency comparison 
- Request volume per version 
- Cache hit ratio differences

This confirms:
- v2 cache logic is active
- Metrics are labeled correctly by version
- Canary behavior is observable

## Uninstall

```bash
helm uninstall sms-app --namespace sms-app
```

#### Notes
If you get a connection error in a new terminal, run this in that terminal:
```bash
export KUBECONFIG=$PWD/vm/kubeconfig
```

## Delete Secret

```bash
kubectl delete secret smtp-credentials -n sms-app
```

## Verify Installation

```bash
# Check all resources
kubectl get all -n sms-app

# Check pods are running
kubectl get pods -n sms-app

# Check ingress
kubectl get ingress -n sms-app

# Test NGINX Ingress access
curl http://sms-nginx.local

# Test Istio access (experiment traffic)
curl http://sms-app.local
```

## Key Values

| Parameter                            | Description                                          | Default                                                       |
| ------------------------------------ | ---------------------------------------------------- | ------------------------------------------------------------- |
| `namespace.name`                     | Target namespace                                     | `sms-app`                                                     |
| `namespace.create`                   | Create namespace                                     | `false`                                                       |
| `app.replicaCount`                   | App replicas                                         | `2`                                                           |
| `app.image.repository`               | App image                                            | `ghcr.io/doda2025-team17/app`                                 |
| `app.image.tag`                      | App image tag                                        | `latest`                                                      |
| `app.versionLabel`                   | Version label for stable app pods                    | `v1`                                                          |
| `app.canary.enabled`                 | Enable app canary deployment                         | `true`                                                        |
| `app.canary.versionLabel`            | Version label for canary pods                        | `v2`                                                          |
| `modelService.replicaCount`          | Model service replicas                               | `1`                                                           |
| `modelService.image.repository`      | Model service image                                  | `ghcr.io/doda2025-team17/model-service`                       |
| `modelService.versionLabel`          | Version label for stable model pods                  | `v1`                                                          |
| `modelService.canary.enabled`        | Enable model canary deployment                       | `true`                                                        |
| `modelService.canary.versionLabel`   | Version label for canary model pods                  | `v2`                                                          |
| `modelService.shadow.enabled`        | Enable shadow model (mutually exclusive with canary) | `false`                                                       |
| `modelService.shadow.mirror.percent` | Percentage of traffic to mirror to shadow            | `10`                                                          |
| `modelService.volume.enabled`        | Enable shared volume                                 | `true`                                                        |
| `modelService.volume.hostPath`       | Host path for models                                 | `/mnt/shared/models`                                          |
| `ingress.enabled`                    | Enable NGINX ingress                                 | `true`                                                        |
| `ingress.className`                  | Ingress class                                        | `nginx`                                                       |
| `ingress.hosts[0].host`              | NGINX Ingress hostname                               | `sms-nginx.local`                                             |
| `istio.enabled`                      | Enable Istio Gateway/VirtualService                  | `true`                                                        |
| `istio.hosts`                        | Istio Gateway hosts                                  | `[sms-app.local, stable.sms-app.local, canary.sms-app.local]` |
| `istio.hostRouting.experiment`       | Host for weighted experiment traffic                 | `sms-app.local`                                               |
| `istio.hostRouting.stable`           | Host forced to stable (v1)                           | `stable.sms-app.local`                                        |
| `istio.hostRouting.canary`           | Host forced to canary (v2)                           | `canary.sms-app.local`                                        |
| `istio.gateway.selector`             | IngressGateway pod selector                          | `{istio: ingressgateway}`                                     |
| `istio.canary.weights.stable`        | Traffic % to stable                                  | `90`                                                          |
| `istio.canary.weights.canary`        | Traffic % to canary                                  | `10`                                                          |
| `istio.canary.stickyCookie.enabled`  | Enable sticky sessions                               | `true`                                                        |
| `istio.canary.stickyCookie.name`     | Cookie name                                          | `sms-app-version`                                             |
| `istio.canary.stickyCookie.ttl`      | Cookie TTL                                           | `3600s`                                                       |
| `monitoring.enabled`                 | Enable ServiceMonitors                               | `false`                                                       |
| `alerting.enabled`                   | Enable AlertManager config                           | `false`                                                       |
| `kube-prometheus-stack.enabled`      | Deploy Prometheus/Grafana/AlertManager               | `true`                                                        |

## Access Services

| Service                  | URL                         | Notes                                                                                                                                                |
| ------------------------ | --------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| App (NGINX)              | http://sms-nginx.local      | Direct to stable v1                                                                                                                                  |
| App (Istio - Experiment) | http://sms-app.local        | 90% v1 / 10% v2 weighted                                                                                                                             |
| App (Istio - Stable)     | http://stable.sms-app.local | Always v1                                                                                                                                            |
| App (Istio - Canary)     | http://canary.sms-app.local | Always v2                                                                                                                                            |
| Grafana                  | http://grafana.local        | Login: admin/admin                                                                                                                                   |
| Prometheus               | http://localhost:9090       | Port forward: `kubectl port-forward svc/sms-app-kube-prometheus-st-prometheus 9090:9090 -n sms-app` (run `export KUBECONFIG=vm/kubeconfig` before)   |
| AlertManager             | http://localhost:9093       | Port forward: `kubectl port-forward svc/sms-app-kube-prometheus-st-alertmanager 9093:9093 -n sms-app` (run `export KUBECONFIG=vm/kubeconfig` before) |

## Grafana Dashboards

### Automatic Installation (Default)

When deployed with `kube-prometheus-stack.grafana.enabled=true` and `monitoring.enabled=true`, dashboards are automatically provisioned via ConfigMaps. They appear under **Dashboards → SMS App** folder.

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
7. Search for your Dashboard.

### Available Dashboards

| Dashboard                                 | Description                                                                   |
| ----------------------------------------- | ----------------------------------------------------------------------------- |
| SMS App Metrics                           | Main dashboard with classification metrics, latency, cache stats              |
| Continuous Experimentation (App v1 vs v2) | Canary vs stable comparison: cache hit ratio, model calls, latency by version |

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

- `sms_messages_classified_total` (Counter with labels: result, version)
- `sms_active_requests` (Gauge with labels: version)
- `sms_request_latency_seconds_bucket` (Histogram with labels: version)
- `sms_cache_hits_total`, `sms_cache_misses_total`, `sms_model_calls_total` (Counters with version label)

### Test SMS Classification (Generate Metrics Data)

The metrics are only recorded when making classification requests to `POST /sms`.

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

# 20 requests to populate metrics:
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

### Test Alerting

The `HighRequestRate` alert fires when the app receives more than 15 requests/minute for 2+ minutes.

**Important:** You must send requests to `POST /sms` (not `/`) for metrics to be recorded!

```bash
# Terminal 1: Port-forward to app service
export KUBECONFIG=vm/kubeconfig
kubectl port-forward svc/sms-app-app 8080:80 -n sms-app
```

```bash
# Terminal 2: Generate sustained traffic for 2.5 minutes

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

### Email Alerting Configuration

By default, alerting uses placeholder email values (alerts visible in AlertManager UI but no emails sent).

_For actual email delivery (Gmail):_

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
  --set kube-prometheus-stack.alertmanager.enabled=true
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
- Click the refresh button in the top right
- Verify Prometheus datasource is working: **Connections → Data sources → Prometheus → Test**

To test queries directly in Grafana:

1. Click **Explore** (compass icon)
2. Select **Prometheus** datasource
3. Try: `sms_messages_classified_total{namespace="sms-app"}`

### Test Istio Host-Based Routing

```bash
# Get Istio IngressGateway IP
INGRESS_IP=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo $INGRESS_IP

# Force stable (v1 only)
curl -H "Host: stable.sms-app.local" http://$INGRESS_IP/

# Force canary (v2 only)
curl -H "Host: canary.sms-app.local" http://$INGRESS_IP/

# Experiment traffic (90% v1, 10% v2 weighted)
curl -H "Host: sms-app.local" http://$INGRESS_IP/

# Test weighted routing distribution (run 20 times)
for i in {1..20}; do
  curl -s -H "Host: sms-app.local" http://$INGRESS_IP/ | grep -o 'v[12]' || echo "response"
done

# Test sticky session (same version on subsequent requests)
curl -c cookies.txt -H "Host: sms-app.local" http://$INGRESS_IP/
curl -b cookies.txt -H "Host: sms-app.local" http://$INGRESS_IP/  # Should be same version

# Check VirtualService routing config
kubectl get vs -n sms-app -o yaml | grep -A 30 "http:"
```

### Test Canary Metrics Comparison

To verify canary (v2) vs stable (v1) metrics are being recorded separately:

```bash
# Generate traffic through Istio (distributes to both v1 and v2)
INGRESS_IP=$(kubectl -n istio-system get svc istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

for i in {1..30}; do
  curl -s -X POST -H "Host: sms-app.local" http://$INGRESS_IP/sms \
    -H "Content-Type: application/json" \
    -d '{"sms": "Test message"}' > /dev/null &
done
wait
```

Then in Prometheus (http://localhost:9090), query:

```promql
sum by (version) (sms_messages_classified_total{namespace="sms-app"})
```

You should see separate counts for `v1` and `v2`.

### Test Paired Routing (App v2 → Model v2)

Verify that app canary pods call the model canary:

```bash
# Check model v1 logs (should receive calls from app v1)
kubectl logs -n sms-app -l app.kubernetes.io/name=sms-app-model,version=v1 --tail=10

# Check model v2 logs (should receive calls from app v2)
kubectl logs -n sms-app -l app.kubernetes.io/name=sms-app-model,version=v2 --tail=10

# Generate traffic and compare
INGRESS_IP=$(kubectl -n istio-system get svc istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Force canary path (app v2 → model v2)
curl -X POST -H "Host: canary.sms-app.local" http://$INGRESS_IP/sms \
  -H "Content-Type: application/json" \
  -d '{"sms": "Test canary path"}'

# Force stable path (app v1 → model v1)
curl -X POST -H "Host: stable.sms-app.local" http://$INGRESS_IP/sms \
  -H "Content-Type: application/json" \
  -d '{"sms": "Test stable path"}'
```
