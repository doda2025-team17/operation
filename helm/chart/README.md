# SMS App Helm Chart

This chart deploys the SMS spam detection stack (Spring Boot app and Python model service) into a Kubernetes cluster. It creates the namespace, ConfigMap, Secret, Deployments, Services, and optionally Ingress.

## Install
From the operations repo,

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

Uninstall with:

```bash
helm uninstall sms-app --namespace sms-app
```

## Key Values (see `values.yaml`)

- `namespace.name` / `namespace.create`: target namespace management.
- `app.*`: replicas, image/tag, service port, probes for the web app.
- `modelService.*`: replicas, image/tag, service port, optional hostPath volume for models.
- `config.*`: values injected into the ConfigMap (leave empty to auto-wire internal service/ports).
- `secrets.smtpPassword`: placeholder secret for SMTP credentials.
- `ingress.*`: hostnames, annotations, and TLS for the Ingress.
- `monitoring.*`: ServiceMonitor labels, metrics ports/paths, scrape interval, toggle monitoring with `monitoring.enabled`.
- `kube-prometheus-stack.*`: toggle the bundled Prometheus dependency.

## Notes

### Images
- The chart defaults to images `ghcr.io/doda2025-team17/app:latest` and `ghcr.io/doda2025-team17/model-service:latest`. Override tags for pinned releases.

### Prometheus
- The bundled Prometheus (kube-prometheus-stack) is enabled by default. The Prometheus Service name is `prometheus-stack-kube-prom-prometheus` (port-forward accordingly), adjust namespace/service if you install it elsewhere.

### Ingress
- Ingress is enabled by default with host `sms-app.local` and the NGINX rewrite annotation; adjust for your controller.

  - To change hostname: (need to specify whole path of hostname)
    helm install sms-app ./helm/chart \
    -n sms-app --create-namespace \
    --set 'ingress.hosts[0].host=myapp.example.com' \
    --set 'ingress.hosts[0].paths[0].path=/' \
    --set 'ingress.hosts[0].paths[0].pathType=Prefix' 
  
### Secrets
- SMTP secret: set `secrets.smtpPassword` at install/upgrade time.
  - **Inline:** `helm install sms-app ./helm/chart -n sms-app --create-namespace --set secrets.smtpPassword=your-smtp-password`
  - **Or use a "secret"-values file** (avoids shell history): write `secrets.smtpPassword: "your-smtp-password"` into a file (e.g., `secrets.yaml`) and pass `-f secrets.yaml`.

### HostPath
- The model service mounts a hostPath at `/mnt/shared/models` by default. Disable or change with `modelService.volume.*` to match your cluster.

### Deployment Versions
- To change deployment versions: (change the tags)
    helm install sms-app ./helm/chart \
    -n sms-app --create-namespace \
    --set app.image.tag=v1.0.0 \
    --set modelService.image.tag=v1.0.0 
