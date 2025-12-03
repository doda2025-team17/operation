# Spam Detector Helm Chart

Helm chart to deploy the SMS spam detector application and the model-service into any Kubernetes cluster. Requires a cluster with either an ingress controller or Gateway API (e.g., Istio) if you want HTTP entrypoints.

## Prerequisites
- Helm 3
- Access to a Kubernetes cluster (kubeconfig context set)
- Ingress controller or Gateway API controller if you enable `ingress` or `httpRoute`

## Install (recommended values)
```bash
cd operation/helm
helm install spam ./chart -n spam --create-namespace \
  --set app.image.tag=latest \
  --set model.image.tag=latest \
  --set model.env.MODEL_URL="https://github.com/doda2025-team17/model-service/releases/download/v1.0.0/model-artifacts.tar.gz" \
  --set model.livenessProbe.httpGet.path=/apidocs \
  --set model.readinessProbe.httpGet.path=/apidocs
```
- `MODEL_URL` pulls the model artifacts into `/models` at startup; alternatively mount `model.joblib` and `preprocessor.joblib` via `model.volumes`/`model.volumeMounts`.
- Ingress is enabled by default (`spam.example.local`); override `ingress.hosts[0].host` for your domain or disable it.
- ConfigMap/Secret are enabled by default and injected into the app via `envFrom` (`config.*`, `secret.*`).
```bash
# Quick verification after install
kubectl get pods -n spam
kubectl get deploy,svc -n spam
kubectl port-forward deploy/spam-spam-detector-app -n spam 8080:8080  # visit http://127.0.0.1:8080
```

## Common overrides
- `app.image.repository`, `app.image.tag`, `app.service.type/port`, `app.env.MODEL_HOST`
- `model.image.repository`, `model.image.tag`, `model.env.MODEL_URL`, `model.service.port`
- `ingress.*` or `httpRoute.*` for exposure; `app.autoscaling.*` to enable HPA
- `config.*`, `secret.*` to tweak injected ConfigMap/Secret data

## Operations
- Upgrade: `helm upgrade spam ./chart -n spam --reuse-values [--set key=val ...]`
- Roll back: `helm rollback spam <revision> -n spam`
- Uninstall: `helm uninstall spam -n spam`

## Notes
- App is exposed; model-service stays internal (`ClusterIP` by default).
- Defaults assume app on 8080 and model-service on 8081.
- Chart is cluster-agnostic; Vagrant/Ansible only create a lab cluster, Helm handles deployment.

## Bumping the chart
- When templates or default values change, bump `version` in `Chart.yaml`. `appVersion` is informational and should track your app/model release as desired.
- Tag or package the chart if others consume it so they can `helm upgrade` safely. 
