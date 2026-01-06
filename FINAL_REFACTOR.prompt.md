# FINAL REFACTOR EXECUTION PROMPT

## ✅ FINAL REFACTOR EXECUTION PROMPT (COPY–PASTE)

### **Role**

You are a **Principal Platform Engineer / Cloud Architect** responsible for refactoring a live **AWS EKS + Kustomize + Terraform** infrastructure repository (`pms-infra`) used in production.

You must think carefully, reason step-by-step, and **avoid any breaking change**.

---

### **Context**

I have provided you with a detailed refactor analysis document that:

* Identifies mixed concerns between applications and infrastructure
* Highlights environment divergence (dev vs prod)
* Proposes separation into `apps/`, `platform/`, and `environments/`
* Introduces service-owned, atomic secret management using External Secrets + AWS Secrets Manager

The repository is **already working**, so stability is critical.

---

### **Critical Guarantees (NON-NEGOTIABLE)**

You **MUST ensure**:

1. **Zero runtime breakage**
   * Preserve existing:
     * Kubernetes resource names
     * Service names and DNS
     * Labels and selectors
     * Namespace usage
2. **No application code changes**
3. **No Helm**
4. **No runtime conditionals**
5. **No secrets in Git**
6. **All environment differences handled structurally**
7. **Terraform remains the source of truth for prod infra**

---

### **Primary Objectives**

You must refactor the repository so that:

1. **Applications**
   * Are environment-agnostic
   * Never directly reference infra manifests
   * Consume config only via ConfigMaps and Secrets

2. **Platform infrastructure**
   * Kafka, Redis, RabbitMQ, Postgres are isolated from app bases
   * In-cluster infra exists only where explicitly composed (e.g., dev)
   * Prod uses managed services (RDS, MSK, Elasticache) provisioned by Terraform

3. **Environments**
   * Decide *what exists* via composition, not patches
   * Dev includes in-cluster infra
   * Prod excludes infra and uses managed endpoints

4. **Secrets**
   * Are **atomic and service-owned**
   * Grouped by **domain**, not by environment YAML
   * Environment differences come from **secret store paths**, not duplicated manifests

---

### **What You Must Do (STRICT ORDER)**

#### **1️⃣ Analyze before changing**

* Identify all current couplings that could cause breakage
* Explicitly list what must remain unchanged to preserve compatibility

---

#### **2️⃣ Propose the FINAL target structure**

You MUST:

* Separate into `apps/`, `platform/`, `environments/`, `terraform/`
* Explain what is allowed and forbidden in each folder
* Present the structure as a tree

---

#### **3️⃣ Design atomic, service-owned secrets (CRITICAL)**

You MUST define:

* A **domain-based secret hierarchy** in AWS Secrets Manager
  Example:

  ```
  pms/
    database/
      dev
      prod
    kafka/
      dev
      prod
    auth/
      dev
      prod
  ```

* One ExternalSecret per **service + domain**
* Clear mapping to Spring Boot environment variables
* Guarantee that services only access secrets they own

---

#### **4️⃣ Environment divergence handling**

Explain explicitly:

* How dev runs in-cluster Postgres/Kafka/Redis
* How prod uses RDS/MSK/Elasticache
* Why apps remain unchanged
* How ConfigMaps vs Secrets differ per env

---

#### **5️⃣ Non-breaking migration plan**

Provide a **phased migration** that:

* Copies before moving
* Validates with `kustomize build`
* Allows rollback at every phase
* Keeps old paths working until final cutover

You MUST include:

* Validation commands
* Diff strategy (old vs new manifests)
* Rollback plan

---

#### **6️⃣ Explicit responsibility boundaries**

You MUST clearly state:

* What Terraform owns
* What Kubernetes owns
* What must NEVER be deployed in Kubernetes in prod

---

### **Output Format (MANDATORY)**

Your response must be structured exactly as:

1. **Compatibility guarantees**
2. **Current risks**
3. **Target architecture**
4. **Final folder structure**
5. **Secrets architecture**
6. **Environment composition model**
7. **Step-by-step migration plan**
8. **Validation & rollback checklist**
9. **Final hard rules (do / don't)**

Be decisive.
Be opinionated.
Assume this will be reviewed by a **Principal Engineer and Security Architect**.

---

### **Quality Bar**

Shallow answers are unacceptable.
Every decision must be justified with real-world production reasoning.

---

## 📋 **REPOSITORY CONTEXT FOR EXECUTION**

### **Current Structure Analysis**
```
pms-infra/
├── k8s/
│   ├── base/                    # MIXED: apps + infra
│   │   ├── apps/               # ✅ Good separation attempt
│   │   └── infra/              # ❌ Should be conditional
│   └── overlays-pms/           # Environment patches
│       ├── dev/                # Patches for dev
│       └── prod/               # Patches for prod
├── terraform/
│   └── envs/dev/               # ✅ Infrastructure as code
└── secrets/                    # ❌ Not organized by domain
```

### **Critical Issues Identified**
1. **Base includes everything** - Prod deploys in-cluster Postgres unnecessarily
2. **Environment patches** - Dev uses emptyDir, prod tries to use RDS
3. **Secret scattering** - Secrets managed in overlay patches, not service-owned
4. **No clear boundaries** - Apps reference infra directly in base

### **Required Fixes**
1. **Separate platform from apps** - Platform services only in dev
2. **Service-owned secrets** - Each service declares its secret dependencies
3. **Environment composition** - Environments compose services, not patch them
4. **Domain-based secrets** - Secrets grouped by domain (database, kafka, auth)

---

## 🎯 **EXECUTION REQUIREMENTS**

When you execute this refactor, you MUST:

1. **Read the current repository structure** using available tools
2. **Create the new directory structure** safely
3. **Move files systematically** with validation at each step
4. **Update all references** to maintain compatibility
5. **Test builds** at every phase
6. **Provide rollback commands** for each step

### **Tools Available**
- `run_in_terminal` - Execute shell commands
- `read_file` - Read file contents
- `create_file` - Create new files
- `list_dir` - List directory contents
- `grep_search` - Search for patterns
- `replace_string_in_file` - Edit files safely

### **Safety First**
- Always copy before moving
- Validate with `kustomize build` after each change
- Keep old structure until new is proven working
- Use git commits for rollback points

---

## 🚀 **READY TO EXECUTE**

This prompt is designed to be given to an LLM that will:
1. Analyze your current repository
2. Execute the refactor step-by-step
3. Guarantee zero breaking changes
4. Provide validation at every step
5. Enable rollback if needed

The result will be a production-ready, scalable infrastructure repository that separates concerns cleanly while maintaining all existing functionality.</content>
<parameter name="filePath">/mnt/c/Developer/pms-new/pms-infra/FINAL_REFACTOR_PROMPT.md