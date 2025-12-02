# Spam Detector Helm Chart

Helm chart to deploy the SMS spam detector application and the model-service into any Kubernetes cluster. Requires a cluster with either an ingress controller or Gateway API (e.g., Istio) if you want HTTP entrypoints.

## Prerequisites
- Helm 3
- Access to a Kubernetes cluster (kubeconfig context set)
- Ingress controller or Gateway API controller if you enable `ingress` or `httpRoute`

## Install
```bash
cd operation/helm
helm install spam ./chart -n spam --create-namespace \
  --set app.image.tag=v1.0.0 \
  --set model.image.tag=v1.0.0 \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host=<your-hostname>
```

## Values to override
- `app.image.repository`, `app.image.tag`, `app.service.type/port`, `app.env.MODEL_HOST`
- `model.image.repository`, `model.image.tag`, `model.env.MODEL_URL`, `model.service.port`
- `ingress.*` or `httpRoute.*` for exposure
- `app.autoscaling.*` to enable HPA on the app

## Upgrade / Rollback
```bash
helm upgrade spam ./chart -n spam
helm rollback spam <revision> -n spam
```

## Notes
- App is exposed; model-service stays internal (`ClusterIP`).
- Defaults assume app listens on 8080 and model-service on 8081.
- Chart is cluster-agnostic; Vagrant/Ansible only set up a lab cluster, Helm handles app deployment.  
