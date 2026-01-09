@workspace Refactor this repository into a Helm Umbrella Chart pattern.

**Role:** Senior Kubernetes Architect.
**Goal:** Consolidate the current mix of manifests into a single parent Helm Chart ("Umbrella") without breaking app logic.

**Phase 1: Discovery (Analysis Only)**
1. Scan the `@workspace` folder structure.
2. Identify which folders are "Microservices" vs "Infrastructure" (DB, Kafka, etc.).
3. Detect anti-patterns (hardcoded URLs, duplicated initContainers).
4. List which components are currently Helm, Kustomize, or Raw YAML.

**Phase 2: Strategy (Plan)**
1. Propose a directory structure for a new `pms-eks` chart.
2. Define which local charts will be `file://` dependencies.
3. Define which infra will be public chart dependencies (Bitnami).
4. Design a `values.yaml` schema that uses global toggles (e.g., `kafka.enabled`).

**Phase 3: Implementation (Code)**
1. Generate `pms-eks/Chart.yaml` listing all dependencies.
2. Generate `pms-eks/values.yaml` with the wiring logic.
3. Show a "Before vs After" refactor for the `trade-capture` service's `values.yaml` to make it compatible with this umbrella.

**Constraints:**
* Do not hallucinate files; use the actual file paths from `@workspace`.
* Do not delete files yet.
* Ensure all services can still be toggled off via the parent `values.yaml`.