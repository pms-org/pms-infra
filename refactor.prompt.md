### 📐 PMS Infra → Deployment Architecture (Eraser.io MD Generator)

You are given access to the entire `pms-infra` repository.

Your task is to **scrape and understand the complete repository** and produce a **single Markdown (`.md`) file** that describes the *full runtime deployment architecture* of PMS, suitable for direct use in **Eraser.io** (Diagram-as-Code or manual rendering).

You must:

1. **Traverse the entire repo**

   * `argocd/`
   * `k8s/` (charts, infra, services, pms-platform, environments)
   * `terraform/`
   * `ci/`
   * `docs/`
   * Helper YAMLs and scripts if they affect runtime topology

2. **Infer the real architecture**

   * Clusters (dev, prod)
   * ArgoCD control plane
   * Helm umbrella (`pms-platform`)
   * Infra components:

     * Kafka
     * Postgres
     * Redis (+ Sentinel)
     * RabbitMQ
     * Schema Registry
     * External Secrets
   * Application services:
   * Networking and flow:

     * User → API Gateway
     * Gateway → Services
     * Services → Kafka / Redis / DB / MQ
     * Async pipelines (Kafka, RabbitMQ)
     * Secrets flow (AWS SM → ExternalSecrets → Pods)

3. **Generate a professional Eraser.io-ready Markdown file**
   The output must:

   * Be a *standalone* `.md` document
   * Contain:

     * Title & overview
     * Layered architecture sections:

       * Edge Layer
       * Control Plane (ArgoCD)
       * Platform Layer
       * Infra Layer
       * Services Layer
       * Data & Event Flow Layer
     * Explicit node names for diagram entities
     * Clear arrows describing:

       * Sync REST flows
       * Async event flows
       * Secret propagation
       * Deployment ownership
   * Use precise, deterministic language suitable for:

     * Diagram-as-Code
     * Manual layout in Eraser.io

4. **Reflect the real implementation**

   * Use actual service names from the repo
   * Use actual Helm structure
   * Use actual ArgoCD model
   * Use actual infra components
   * Do not invent components

5. **Model Kubernetes Correctly**

   * Show:

     * Namespace boundaries
     * Stateful vs stateless components
     * Service discovery via DNS
     * Redis + Sentinel topology
     * Kafka + Schema Registry topology
   * Show:

     * How ArgoCD deploys Helm
     * How Helm deploys everything
     * How Terraform provisions the cluster

6. **Output Format**

   * One file: `pms-deployment-architecture.md`
   * Pure Markdown
   * No prose outside the document
   * Must be directly usable in Eraser.io

The result should read like a **production-grade architecture spec** that a staff engineer or SRE would hand to a team for implementation and audit.

This document is the *authoritative deployment diagram reference* for PMS.
