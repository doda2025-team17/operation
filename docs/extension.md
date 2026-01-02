# Extension Proposal: Automated CI/CD Release Pipeline Across Multiple Repositories

## 1. Identified Shortcoming: Fragmented, Manual Release Process

### 1.1. Current state

The project is divided intro three independent repositories, each serving a distinct purpose. The `app` repository contains the Spring Boot web application that serves as the frontend and API gateway, whereas the `model-service` repository contains the spam detection application itself. Finally, the `operation` repository acts as the deployment hub, containing all infrastructure-as-code components, such as the Vagrant/Ansible provisioning scripts, Helm charts for Kubernetes deployment, Istio configuration files, and Prometheus monitoring setup. For the purposes of this report, we shall ignore the `lib-version` repository.

<figure>
  <img src="images/extension/Current%20Workflow.png" alt="Current State Deployment Workflow">
  <figcaption><b>Figure 1:</b> Current State Deployment Workflow.</figcaption>
</figure>

The current workflow is a mostly manual process, illustrated in **Figure 1**. First, a developer makes a change in the codebase. Then, they manually build the `app` and `model-service` repositories, and they push the resulting images to the GitHub Container Registry (GHCR). 

This manual image building and pushing process follows our established versioning conventions: for stable releases, images are tagged with semantic versions like `v1.0.1`, while for feature branches, we use pre-release tags such as `v1.2.3-feature-x-20251217-123456`. However, there is no automated mechanism to propagate these version tags to the `operation` repository. Instead, a developer must manually navigate to the Helm chart's `values.yaml` file, update both the `app.image.tag` and `modelService.image.tag` fields with the exact versions that have just been pushed to GHCR, commit this change, and then execute `helm upgrade --install` commands against the Kubernetes cluster.

Before any deployment can occur, the infrastructure must be provisioned. A user must manually start the Virtual Machines via `vagrant up`, which triggers the Ansible playbooks to automatically provision the full Kubernetes cluster stack, including the Flannel CNI, MetalLB load balancer, NGINX Ingress Controller, and Istio service mesh. Once provisioned, the user must export the `KUBECONFIG` environment variable pointing to the generated configuration file and manually build Helm dependencies with `helm dependency build`. 

Afterwards, they must complete the multi-stage Helm deployment process: first, install a basic release, then manually create the Kubernetes Secrets (such as SMTP credentials), and finally upgrade the release with additional configurations for monitoring, alerting, or Istio features. In the end, the end user must manually set up port forwarding via `kubectl port-forward` before the application becomes accessible at `http://localhost:8080`.

### 1.2. The Release Engineering Problem

The workflow described in ![Section 1.1](#11-current-state) is highly fragmented and inconvenient. It represents, essentially, a problem regarding coordination and automation, where the separation of concerns that was so useful for developing the three repositories becomes a liability during the actual deployment of the application due to the absence of an integrated release mechanism. This places an excessive cognitive and operational burden on the developer and introduces opportunities for human error.

Furthermore, this can be categorized as a release engineering problem. In Google's Site Reliability Engineering (SRE) model, release engineering is concerned with designing automated, reproducibile, and auditable release processes that minimize manual intervention and operational toil (Beyer et al., 2016). The current workflow violates these principles in several ways.

Firstly, versioning and propagating images across repositories is a manual process prone to human errors. Developers must independently build and push the `app` and `model-service` images, then update the `values.yaml` in the `operation` repository before running Helm commands. This manual step has a high risk of accidentally mismatching the versions of the cluster and the source repositories, which reduces reliability and increases the so-called "operational toil", defined in Google's SRE model as manual, repetitive work that scales linearly with system growth (Beyer et al., 2016).

Secondly, orchestrating the deployment of the application is a fragmented process across repositories. Helm releases, secret management, and Istio configuration all require sequential manual actions. There is no central, automated control plane for coordinating these steps, which increases the "cognitive load" of the developer (Sweller, 1988) and slows down the release process. Each manual intervention is a potential point of failure and contradicts the SRE principle of minimizing operational toil through automation (Beyer et al., 2016).

Finally, the workflow does not provide adequate reproducibility. The DORA research program identifies "change lead time" as an important metric for DevOps performance, requiring clear tracking of when changes move from code to production (DORA, 2024). However, our process lacks this traceability. Currently, it is difficult to determine which versions of `app` and `model-service` are running in a given environment solely from the repository history. Rollbacks or reproducing experiments require a thorough manual inspection and for the tester to coordinate across multiple repositories, which makes the process non-reproducible and audit-unfriendly.

What we have identified is fundamentally a release engineering problem because it affects the systematic building and deploying of software. The issues extend beyond our project to a general pattern in multi-repository microservices architectures, making the solution we will present broadly applicable.


### 1.3. Negative Impacts

The release engineering process in this project has clear negative impacts, the most tangible of which is the time to deployment. Our team tracking shows an average time of 45 minutes necessary from making a code change to accessing the application at `localhost`. This manual "toil" is not only excessive, but also increases the chances of making an error and having to spend even more time debugging it.

Additionally, the manual process introduces some security risks. Kubernetes Secrets and sensitive configurations like SMTP credentials have to be created by hand via `kubectl` commands, which leaves room for human error that could expose credentials. There is no automated validation that security best practices are followed, nor any audit trail of who created which secrets when.

Finally, the process creates bottlenecks that make parallel development difficult to execute. That is, when multiple developers work on features across different repositories, synchronising deployments becomes a sequential blocking task. The developer who completes their work first cannot deploy independently but must wait for others to finish, coordinate image builds, and manually align versions.


## 2. Proposed Extension: Cross-Repository CI/CD Pipeline

### 2.1. Vision

### 2.2. High-Level Design

### 2.3. How it Addresses the Shortcoming


## 3. Implementation Plan

### 3.1. Standardize Image Building

### 3.2. Create a Deployment Control Plane

### 3.3. Integrate the Experiment Configuration into the Project


## 4. Experiment Design

### 4.1. Hypothesis

### 4.2. Metrics

### 4.3. Experiment Methodology

#### Step 1: Establish a Baseline

#### Step 2: Enable the CI/CD Pipeline

#### Step 3: Analysis

### 4.4. Visualizations of the Results


## 5. Discussion

### 5.1. Assumptions

### 5.2. Potential Downsides

### 5.3. Why Benefits Outweigh the Risks


## 6. References
Beyer, B., Jones, C., Petoff, J., & Murphy, N. R. (Eds.). (2016). *Site Reliability Engineering: How Google Runs Production Systems*. O’Reilly Media.

DORA Research Program (2024). *Accelerate State of DevOps*. Google Cloud. Retrieved from [https://dora.dev/research/2024/dora-report/2024-dora-accelerate-state-of-devops-report.pdf](https://dora.dev/research/2024/dora-report/2024-dora-accelerate-state-of-devops-report.pdf).

Sweller, J. (1988). Cognitive load during problem solving: Effects on learning. Cognitive Science, 12(2), 257–285. [https://doi.org/10.1207/s15516709cog1202_4](https://doi.org/10.1207/s15516709cog1202_4).


## 7. Declarative Use of Generative AI
Chatbots (ChatGPT and Claude) were used to rephrase text and improve style, structure, and grammar. They were not used to generate new content, but rather to improve the overall clarity, consistency, and readability of the report. Additionally to LLMs, Grammarly has been used to correct any grammar mistakes.

Examples of prompts used:

- (ChatGPT) “How can this sentence be rephrased to sound more stylistically correct?”

- (ChatGPT) “Please correct the grammar and improve the flow of this paragraph.”

- (Claude) “Make this explanation more concise without changing its meaning.”