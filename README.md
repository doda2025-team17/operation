# Operation

This organization contains a machine learning-based SMS spam detection system with a web interface.

## Architecture Overview

This system has four repositories, found at these links:

- **app** (https://github.com/doda2025-team17/app/releases/tag/v1.0.0): Spring Boot web application as the frontend and acting as an API gateway
- **model-service** (https://github.com/doda2025-team17/model-service/releases/tag/v1.0.0): Python-based machine learning service for spam detection
- **lib-version** (https://github.com/doda2025-team17/lib-version/releases/tag/v1.0.0): Version utility library (used by app)
- **operation** (https://github.com/doda2025-team17/operation/releases/tag/v2.0.0): Main deployment and orchestration repository with documentation

## Quick Start

### Prerequisites

- [Docker and Docker Compose](https://docs.docker.com/compose/install/)
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)
- [Vagrant](https://developer.hashicorp.com/vagrant/install)
- [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
- [Minikube](https://minikube.sigs.k8s.io/docs/start/)
- kubectl (1.34+)
- [Helm](https://helm.sh/docs/intro/install/)

### Running the Application

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

   - Web Application: http://localhost:8080

   **Note:** The model service is only accessible internally through the app service (not directly from localhost). This follows microservices best practices where the frontend acts as an API gateway.

4. **Stop the Services**:

```
   docker-compose down
```

## Configuration

### Environment Variables

The application uses environment variables defined in the `.env` file:

#### Port Configuration

- `APP_HOST_PORT`: Port on your machine to access the web application (default: `8080`)
- `APP_CONTAINER_PORT`: Port the app listens on inside its container (default: `8080`)
- `MODEL_CONTAINER_PORT`: Port the model service listens on inside its container (default: `8081`)

### Port Mapping

| Service             | Access URL                | Exposed to Host?   |
| ------------------- | ------------------------- | ------------------ |
| **Web Application** | http://localhost:8080     | Yes                |
| **Model Service**   | http://model-service:8081 | No (internal only) |

**Architecture:**

- You access the **app** at `localhost:8080`
- The **app** internally communicates with **model-service** at `http://model-service:8081`
- The model service is **not directly accessible** from browser/machine

This design follows the **API Gateway pattern** where the frontend service acts as the single entry point.

## Assignments

### Assignment 1

For Assignment 1, we have extended the application of the SMS spam detection system with multi-architecture Docker images, a Maven library with version-aware utilities, automated CI/CD workflows, and flexible Docker Compose orchestration.
More information on the containerized services can be found at the [app repository](https://github.com/doda2025-team17/app) and [model-service repository](https://github.com/doda2025-team17/model-service), and details about the version-aware Maven library can be found at the [lib-version repository](https://github.com/doda2025-team17/lib-version).

# Assignment 2 - Kubernetes Infrastructure

This directory contains the infrastructure code to spin up a Kubernetes cluster using **Vagrant**, **VirtualBox**, and **Ansible**.

## Environment Overview

| Component | Description |
|-----------|-------------|
| Control-plane | `ctrl` (192.168.56.100) |
| Worker nodes | `node-1` (192.168.56.101), `node-2` (192.168.56.102) |
| Kubernetes | kubeadm-based cluster (v1.32.4) |
| CNI | Flannel |
| Load Balancer | MetalLB (IP range: 192.168.56.90-99) |
| Ingress | NGINX Ingress Controller (192.168.56.95) |
| Service Mesh | Istio (192.168.56.96) |
| Dashboard | Kubernetes Dashboard (dashboard.local) |

## Prerequisites

- VirtualBox (6.1+)
- Vagrant (2.3+)
- Ansible (2.10+)
- kubectl

### VirtualBox DHCP Conflict Fix

If you experience networking issues, remove any conflicting DHCP server:
```bash
VBoxManage dhcpserver remove --network=HostInterfaceNetworking-vboxnet0
```

This is automatically handled in the Vagrantfile, but may need manual execution on some systems.

## Quick Start

### 1. Start the Cluster
```bash
cd vm/
vagrant up
```

This automatically:
- Creates all VMs (ctrl, node-1, node-2)
- Runs all Ansible playbooks (general, ctrl, node, finalization, istio)
- Installs Kubernetes, Flannel, MetalLB, Ingress, Dashboard, and Istio

**Note:** First run takes 15-20 minutes.

### Re-provisioning (if needed)

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
