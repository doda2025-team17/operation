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

- Docker
- Docker Compose

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

### Assignment 2

This directory contains the infrastructure code to spin up a small Kubernetes lab using **Vagrant**, **VirtualBox**, and **Ansible**.  
The environment includes:

- **Control-plane node**: `ctrl`
- **Worker node(s)**: e.g. `node-1`
- A **kubeadm**-based Kubernetes cluster
- **Flannel** CNI
- **MetalLB** as a bare‑metal LoadBalancer
- **NGINX Ingress Controller** (note: ingress is not fully working on all machines yet)
  - To test the ingress controller go to branch Feat 21: https://github.com/doda2025-team17/operation.git

All of this is orchestrated via the Vagrantfile and the Ansible playbooks in `ansible/`.

### 1. How to Run the Environment

From your **host machine**, in this directory:

```bash
cd operation/vm
```

#### Step 1 – Bring up the VMs

```bash
vagrant up
```

This creates and boots `ctrl` and `node-1`.

#### Step 2 – Provision the VMs

```bash
vagrant provision
```

This runs the Ansible playbooks that:

- Configure OS and Kubernetes prerequisites.
- Initialize the control-plane.
- Join workers.
- Install Flannel and MetalLB.

---

### 2. Troubleshooting Flow

If provisioning fails (for example on MetalLB or due to SSH issues between nodes), a sequence that often fixes things is:

```bash
cd operation/vm

# 1) SSH into the worker VM
vagrant ssh node-1

# 2) From node-1, confirm you can SSH into ctrl by hostname
ssh ctrl

# 3) Exit twice back to the host
exit    # back to node-1
exit    # back to host

# 4) Re-run targeted provisioning on ctrl and node-1
vagrant provision ctrl node-1
```

This sequence:

- Confirms inter-node SSH connectivity.
- Re-runs the control-plane and worker Ansible roles until the cluster converges.

---
