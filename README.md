# Table of Contents
* [Architecture Overview](#architecture-overview)
* [Quick Start](#quick-start)

   * [Prerequisites](#prerequisites)
   * [Running the Application](#running-the-application)
* [Configuration](#configuration)

   * [Environment Variables](#environment-variables)
   * [Port Mapping](#port-mapping)
* [Assignments](#assignments)

   * [Assignment 1](#assignment-1)
   * [Assignment 2 - Kubernetes Infrastructure](#assignment-2---kubernetes-infrastructure)
   * [Assignment 3](#assignment-3)
   * [Assignment 4 - Traffic Management & Continuous Experimentation](#assignment-4---traffic-management--continuous-experimentation)
   * [Final Presentation Slides](#final-presentation-slides)
* [Deployment & Docs](#deployment--docs)
* [Run Everything](#run-everything)

# Operation

This organization contains a machine learning-based SMS spam detection system with a web interface.

# Final Presentation Slides

View our project presentation slides: [Google Slides Presentation](https://docs.google.com/presentation/d/17BU4RHK-nm1WNdFNbpCrFNRYblft-hVfPCv5rCbB-lg/edit?usp=sharing)

# Architecture Overview

This system has four repositories, found at these links:

| Repository | Latest Release | Description |
|------------|----------------|-------------|
| [**app**](https://github.com/doda2025-team17/app/) | [v1.0.1](https://github.com/doda2025-team17/app/releases/tag/v1.0.1) | Spring Boot web application serving as the frontend and API gateway |
| [**model-service**](https://github.com/doda2025-team17/model-service/) | [v1.0.1](https://github.com/doda2025-team17/model-service/releases/tag/v1.0.1) | Python-based machine learning service for spam detection |
| [**lib-version**](https://github.com/doda2025-team17/lib-version/) | [v1.0.2](https://github.com/doda2025-team17/lib-version/releases/tag/v1.0.2) | Version utility library used by the app service |
| [**operation**](https://github.com/doda2025-team17/operation/) | [v3.0.0](https://github.com/doda2025-team17/operation/releases/tag/v3.0.0) | Main deployment and orchestration repository with documentation |

# Quick Start

## Prerequisites

* [Docker and Docker Compose](https://docs.docker.com/compose/install/)
* [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)
* [Vagrant](https://developer.hashicorp.com/vagrant/install)
* [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
* [Minikube](https://minikube.sigs.k8s.io/docs/start/)
* kubectl (1.34+)
* [Helm](https://helm.sh/docs/intro/install/)

## Running the Application

1. **Clone the operation repository**:

```bash
   git clone https://github.com/doda2025-team17/operation.git
   cd operation
```

2. **Start the Services**:

```
   docker-compose up -d
```

3. **Access the Application**:

   * Web Application: [http://localhost:8080](http://localhost:8080)

   **Note:** The model service is only accessible internally through the app service (not directly from localhost). This follows microservices best practices where the frontend acts as an API gateway.

4. **Stop the Services**:

```
   docker-compose down
```

# Configuration

## Environment Variables

The application uses environment variables defined in the `.env` file:

### Port Configuration

* `APP_HOST_PORT`: Port on your machine to access the web application (default: `8080`)
* `APP_CONTAINER_PORT`: Port the app listens on inside its container (default: `8080`)
* `MODEL_CONTAINER_PORT`: Port the model service listens on inside its container (default: `8081`)

## Port Mapping

| Service             | Access URL                                             | Exposed to Host?   |
| ------------------- | ------------------------------------------------------ | ------------------ |
| **Web Application** | [http://localhost:8080](http://localhost:8080)         | Yes                |
| **Model Service**   | [http://model-service:8081](http://model-service:8081) | No (internal only) |

**Architecture:**

* You access the **app** at `localhost:8080`
* The **app** internally communicates with **model-service** at `http://model-service:8081`
* The model service is **not directly accessible** from browser/machine

This design follows the **API Gateway pattern** where the frontend service acts as the single entry point.

# Assignments

## Assignment 1

For Assignment 1, we have extended the application of the SMS spam detection system with multi-architecture Docker images, a Maven library with version-aware utilities, automated CI/CD workflows, and flexible Docker Compose orchestration.
More information on the containerized services can be found at the [app repository](https://github.com/doda2025-team17/app) and [model-service repository](https://github.com/doda2025-team17/model-service), and details about the version-aware Maven library can be found at the [lib-version repository](https://github.com/doda2025-team17/lib-version).

### Important information
- **lib-version**: `VersionUtil` reads the packaged version (not git). The Spring app depends on it to surface build info. Release workflow: SNAPSHOT -> tag -> publish to GHCR Maven -> bump to next SNAPSHOT; branch builds publish timestamped pre-releases with branch suffixes.
- **Containers**: Multi-stage Dockerfiles for both app and model produce slim images; buildx builds amd64+arm64 manifests pushed to GHCR. Env vars (`MODEL_HOST`, `APP_PORT`, `MODEL_PORT`) keep endpoints/ports configurable.
- **Docker Compose**: `operation/docker-compose.yml` wires app <-> model; `.env` controls host ports. Run locally with `docker-compose up -d` / `docker-compose down`.
- **Model delivery**: Model weights are not baked into the image. The model container mounts a volume and, if empty, downloads the released model asset on startup (from the manual “train and release model” GitHub workflow).
- **CI/CD**: App and model-service workflows build/push images on tags; model-service also has the manual training workflow that packages and attaches model artifacts to releases.

## Assignment 2 - Kubernetes Infrastructure

This directory contains the infrastructure code to spin up a Kubernetes cluster using **Vagrant**, **VirtualBox**, and **Ansible**.

### Environment Overview

| Component     | Description                                          |
| ------------- | ---------------------------------------------------- |
| Control-plane | `ctrl` (192.168.56.100)                              |
| Worker nodes  | `node-1` (192.168.56.101), `node-2` (192.168.56.102) |
| Kubernetes    | kubeadm-based cluster (v1.32.4)                      |
| CNI           | Flannel                                              |
| Load Balancer | MetalLB (IP range: 192.168.56.90-99)                 |
| Ingress       | NGINX Ingress Controller (192.168.56.95)             |
| Service Mesh  | Istio (192.168.56.96)                                |
| Dashboard     | Kubernetes Dashboard (dashboard.local)               |

### Prerequisites

- VirtualBox (6.1+)
- Vagrant (2.3+)
- Ansible (2.10+)
- kubectl

#### VirtualBox DHCP Conflict Fix

If you experience networking issues, remove any conflicting DHCP server:

```bash
VBoxManage dhcpserver remove --network=HostInterfaceNetworking-vboxnet0
```

This is automatically handled in the Vagrantfile, but may need manual execution on some systems.

### Quick Start

#### 1. Start the Cluster

```bash
cd vm/
vagrant up
```

This automatically:
- Creates all VMs (ctrl, node-1, node-2)
- Runs all Ansible playbooks (general, ctrl, node, finalization, istio)
- Installs Kubernetes, Flannel, MetalLB, Ingress, Dashboard, and Istio

**Note:** First run takes 5-10 minutes.

#### 2. Re-provisioning (if needed)

If provisioning fails or you need to re-run:

```bash
vagrant provision
```

Or run specific playbooks manually:

```bash
# Only finalization (MetalLB, Ingress, Dashboard)
ansible-playbook -i inventory.cfg ansible/finalization.yaml \
  --private-key=.vagrant/machines/ctrl/virtualbox/private_key -u vagrant

# Only Istio
ansible-playbook -i inventory.cfg ansible/istio.yaml \
  --private-key=.vagrant/machines/ctrl/virtualbox/private_key -u vagrant
```

### Important information
- **Vagrant topology**: `ctrl`, `node-1`, `node-2` (worker count configurable) on Ubuntu 24.04 with host-only IPs `192.168.56.100+`.
- **General playbook**: installs base tools, adds team SSH keys, disables swap (runtime + fstab), sets sysctls (`ip_forward`, bridge settings), loads `overlay`/`br_netfilter`, standardizes `/etc/hosts`, installs containerd 1.7.24 + runc 1.1.12 with systemd cgroups and updated pause image.
- **Control-plane playbook**: kubeadm init (CIDR `10.244.0.0/16`, advertise `192.168.56.100`, hostname `ctrl`), copies kubeconfig to vagrant and host (`vm/kubeconfig`), installs Flannel 0.26.7 patched with `--iface=eth1`, installs Helm via apt repo.
- **Worker playbook**: delegates `kubeadm token create --print-join-command` on ctrl and joins each node.
- **Finalization**: MetalLB v0.14.9 pool `192.168.56.90-99`, NGINX Ingress LB IP `192.168.56.95`, Kubernetes Dashboard with Ingress `dashboard.local`, Istio 1.25.2 ingressgateway LB IP `192.168.56.96`.
- **One-command bring-up**: `cd vm && vagrant up`; re-run safely with `vagrant provision`.

## Assignment 3
For more detailed instructions, please refer to the [Helm chart README](helm/chart/README.md).

### Prerequisites

- VirtualBox (6.1+)
- Vagrant (2.3+)
- Ansible (2.10+)
- kubectl
- Helm

### Installation

#### 1. Start the Cluster

```bash
cd vm
vagrant up
cd ../
```

#### 2. Point to the `kubeconfig` file you plan to use (default or your own)

```bash
export KUBECONFIG=vm/kubeconfig
```

#### 3.a. Using the Helm Chart

```bash
helm install sms-app ./helm/chart \
  --namespace sms-app \
  --create-namespace
```
This deploys the app to the Kubernetes cluster with default configurations, creating:
- A sms-app namespace
- Two replicas of the `app` repository
- One replica of the `model-service` repository
- `ConfigMap` and `Secret` for configuration (placeholders only; no credentials in git)
- `Deployments` for managing the pods
- `Services` for internal communication
- `Ingress` for external access (host: `sms-app.local`)
- Optional Istio resources (Gateway/VirtualService/DestinationRule) and a hostPath volume for `/mnt/shared/models`
- Optional monitoring/alerting stack (kube-prometheus-stack) with ServiceMonitors for the app (`/actuator/prometheus`) and model (`/metrics`), plus a PrometheusRule (>15 req/min for 2 minutes) routed through Alertmanager via SMTP secret
- Two Grafana dashboards auto-imported via ConfigMaps: Operational (throughput/latency/error) and Experiment (version split, p95 latency, cache hit/miss, model call rate, mirror traffic)


#### 3.b. Upgrade with Custom Settings

```bash
helm upgrade sms-app ./helm/chart \
  --namespace sms-app \
  --create-namespace \
  --set secrets.smtpPassword=whatever \
  --set app.image.tag=monitoring \
  --set modelService.image.tag=monitoring \
  --dependency-update \
  -f values.yaml
```

This allows you to update the deployment with custom configurations. You could, for example:
- Change the ingress hostname for grading
- Update the image tags to different versions
- Modify replica counts for scaling
- Customize service ports
- Toggle monitoring, alerting, Istio canary, or shadow launch through values


#### 4. Uninstall

```bash
helm uninstall sms-app --namespace sms-app
```

### Accessing the Application

#### 1. Forward the Port (for ease of use)
```bash
kubectl port-forward svc/sms-app-app -n sms-app 8080:80
```

#### 2. Access the app at [http://localhost:8080/](http://localhost:8080/).

## Assignment 4 - Traffic Management & Continuous Experimentation

- Istio canary routing via Helm values: hosts `sms-app.local`, `stable.sms-app.local`, `canary.sms-app.local`; default 90/10 split between app v1/v2 with sticky cookie `sms-app-version` (TTL 3600s). Weights are live-tunable via `istio.canary.weights.*`.
- Version pairing enforced: app v1 routes only to model v1, app v2 to model v2, avoiding mixed old/new paths; model VirtualService handles this pairing.
- Shadow launch: model VirtualService mirrors a configurable percentage of traffic to subset `v2`; shadow metrics are labeled `source=shadow` for clean separation in Prometheus/Grafana.
- Continuous experimentation (cache in app v2) is documented in `docs/continuous-experimentation.md`, including hypothesis, metrics, decision criteria, and how to hit stable vs canary via hostnames.
- Observability reused from Assignment 3: ServiceMonitors, PrometheusRule/Alertmanager email, Grafana experiment dashboard showing version splits, p95 latency, cache hit/miss, model call rate, and shadow vs stable panels.

## Deployment & Docs

- Full deployment architecture, request flows, load balancer IPs/hostnames, storage, and routing decision points are described with diagrams in `docs/deployment.md`.
- Helm usage details (dependencies, `/etc/hosts` setup, port-forward alternatives, monitoring/full-stack/istio/shadow install commands) are in `helm/chart/README.md`.
- Grafana dashboards are shipped via ConfigMaps in the chart - no manual import required.

# Run Everything

The commands below let you reproduce the whole stack (local Compose, full K8s, monitoring, Istio canary/shadow). Copy/paste in order.

## 1. Local (Docker Compose) quick run
```bash
docker-compose up -d
# open http://localhost:8080
# tear down when done
docker-compose down
```

## 2. Bring up the K8s cluster (Vagrant + Ansible)
```bash
cd vm
vagrant up          # ctrl + node-1 + node-2, installs k8s, Flannel, MetalLB, NGINX Ingress, Dashboard, Istio
cd ..
export KUBECONFIG=vm/kubeconfig
```

## 3. Prepare Helm chart dependencies
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm dependency build helm/chart
```

## 4. Map hostnames to LB IPs
```bash
NGINX_IP=$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
ISTIO_IP=$(kubectl -n istio-system get svc istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
sudo sed -i '/sms-app\.local/d;/stable\.sms-app\.local/d;/canary\.sms-app\.local/d;/grafana\.local/d;/dashboard\.local/d' /etc/hosts
echo "$NGINX_IP grafana.local dashboard.local"        | sudo tee -a /etc/hosts
echo "$ISTIO_IP sms-app.local stable.sms-app.local canary.sms-app.local" | sudo tee -a /etc/hosts
```

## 5. Install via Helm (full stack: app+model+monitoring+alerting+Istio+shadow ready)
```bash
helm upgrade --install sms-app helm/chart -n sms-app --create-namespace \
  --set secrets.smtpPassword=changeme \
  --set monitoring.enabled=true \
  --set alerting.enabled=true \
  --set kube-prometheus-stack.prometheus.enabled=true \
  --set kube-prometheus-stack.alertmanager.enabled=true \
  --set kube-prometheus-stack.grafana.enabled=true \
  --set kube-prometheus-stack.kubeStateMetrics.enabled=true \
  --set kube-prometheus-stack.nodeExporter.enabled=true \
  --set istio.enabled=true \
  --set app.canary.enabled=true \
  --set 'istio.hosts[0]=sms-app.local' \
  --set 'istio.hosts[1]=stable.sms-app.local' \
  --set 'istio.hosts[2]=canary.sms-app.local' \
  --set istio.hostRouting.experiment=sms-app.local \
  --set istio.hostRouting.stable=stable.sms-app.local \
  --set istio.hostRouting.canary=canary.sms-app.local
```

## 6. Change canary weight (example: 20% canary / 80% stable)
```bash
helm upgrade sms-app helm/chart -n sms-app \
  --reuse-values \
  --set istio.canary.weights.stable=80 \
  --set istio.canary.weights.canary=20
```

## 7. Enable shadow launch (mirror model traffic to v2)
```bash
helm upgrade sms-app helm/chart -n sms-app \
  --reuse-values \
  --set modelService.shadow.enabled=true \
  --set modelService.shadow.mirror.percent=25
```

## 8. Access the app
- Stable path (Istio canary routing applied): `http://sms-app.local`
- Force stable only: `http://stable.sms-app.local`
- Force canary: `http://canary.sms-app.local`
- NGINX ingress path (non-Istio): `http://sms-app.local` via NGINX if Istio disabled

## 9. Observability quick access
```bash
# Grafana (if LB/DNS not reachable)
kubectl port-forward -n sms-app svc/sms-app-kube-prometheus-st-grafana 3000:80
# Prometheus
kubectl port-forward -n sms-app svc/sms-app-kube-prometheus-st-prometheus 9090:9090
# Alertmanager
kubectl port-forward -n sms-app svc/sms-app-kube-prometheus-st-alertmanager 9093:9093
```
Grafana dashboards are auto-imported; login default (if unchanged by values) is `admin/prom-operator`.

## 10. Tear down
```bash
helm uninstall sms-app -n sms-app
vagrant destroy -f   # from vm/ if you want to remove VMs
```
