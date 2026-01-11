# 🚨 Production Hardening Rollback Guide

## Overview
All critical fixes have been applied to harden the PMS Platform Helm umbrella chart for production. Below is the complete rollback documentation showing exact diffs for each change. Use this guide to revert any changes that cause issues.

## 🔄 Quick Rollback Commands

### Option 1: Revert All Changes (if no other commits)
```bash
cd /mnt/c/Developer/pms-new/pms-infra
git checkout -- .
```

### Option 2: Selective Revert by File
```bash
# Revert individual files
git checkout HEAD -- k8s/charts/infra/postgres/templates/deployment.yaml
git checkout HEAD -- k8s/charts/services/auth/values.yaml
# ... etc for each file
```

---

## 📋 Detailed Diff Documentation

### 1. **Fixed External-Secrets Condition Logic**
**File**: `k8s/pms-platform/Chart.yaml`  
**Issue**: Condition was `externalSecrets.disabled` (backwards logic)  
**Status**: ✅ Applied

```diff
   # Platform
   - name: external-secrets
     repository: file://../charts/platform/external-secrets
     version: 0.1.0
-    condition: externalSecrets.disabled
+    condition: externalSecrets.enabled
```

**Rollback**:
```diff
   # Platform
   - name: external-secrets
     repository: file://../charts/platform/external-secrets
     version: 0.1.0
+    condition: externalSecrets.disabled
-    condition: externalSecrets.enabled
```

---

### 2. **Fixed Typo in Values**
**File**: `k8s/pms-platform/values.yaml`  
**Issue**: `externalSecrets.enabled: fasle`  
**Status**: ✅ Already corrected (no diff needed)

---

### 3. **Added Health Checks to PostgreSQL**
**File**: `k8s/charts/infra/postgres/templates/deployment.yaml`  
**Issue**: No readiness/liveness probes  
**Status**: ✅ Applied

```diff
         - name: PGDATA
           value: /var/lib/postgresql/data/pgdata
         resources: {{ toYaml .Values.deployment.resources | nindent 10 }}
+        readinessProbe:
+          exec:
+            command:
+              - pg_isready
+              - -U
+              - $(POSTGRES_USER)
+          initialDelaySeconds: 15
+          periodSeconds: 5
+        livenessProbe:
+          exec:
+            command:
+              - pg_isready
+              - -U
+              - $(POSTGRES_USER)
+          initialDelaySeconds: 30
+          periodSeconds: 10
         volumeMounts:
```

**Rollback**:
```diff
         - name: PGDATA
           value: /var/lib/postgresql/data/pgdata
         resources: {{ toYaml .Values.deployment.resources | nindent 10 }}
-        readinessProbe:
-          exec:
-            command:
-              - pg_isready
-              - -U
-              - $(POSTGRES_USER)
-          initialDelaySeconds: 15
-          periodSeconds: 5
-        livenessProbe:
-          exec:
-            command:
-              - pg_isready
-              - -U
-              - $(POSTGRES_USER)
-          initialDelaySeconds: 30
-          periodSeconds: 10
         volumeMounts:
```

---

### 4. **Standardized Auth Service Init Containers**
**File**: `k8s/charts/services/auth/values.yaml`  
**Issue**: Hardcoded init container logic  
**Status**: ✅ Applied

```diff
   # Resource limits and requests
   resources:
     requests:
       cpu: 100m
       memory: 256Mi
     limits:
       cpu: 500m
       memory: 1Gi

-# Init containers configuration
-initContainers:
-  postgres:
-    enabled: true
-    image: busybox:1.36
-    command:
-      - sh
-      - -c
-      - "until nc -z postgres 5432; do echo waiting for postgres; sleep 2; done"
-  apigateway:
-    enabled: true
-    image: busybox:1.36
-    command:
-      - sh
-      - -c
-      - "until nc -z apigateway 8080; do echo waiting for api-gateway; sleep 2; done"
+  # Generic wait image for init containers
+  waitImage: &waitImage "busybox:1.36"
+
+  # Dependencies list - data-driven approach for init containers
+  dependencies:
+    - name: postgres
+      enabled: true
+      image: *waitImage
+      command:
+        - sh
+        - -c
+        - "until nc -z postgres 5432; do echo waiting for postgres; sleep 2; done"
+    - name: apigateway
+      enabled: true
+      image: *waitImage
+      command:
+        - sh
+        - -c
+        - "until nc -z apigateway 8080; do echo waiting for api-gateway; sleep 2; done"

 # Application configuration (non-secret)
```

**Rollback**:
```diff
   # Resource limits and requests
   resources:
     requests:
       cpu: 100m
       memory: 256Mi
     limits:
       cpu: 500m
       memory: 1Gi

+  # Generic wait image for init containers
+  waitImage: &waitImage "busybox:1.36"
+
+  # Dependencies list - data-driven approach for init containers
+  dependencies:
+    - name: postgres
+      enabled: true
+      image: *waitImage
+      command:
+        - sh
+        - -c
+        - "until nc -z postgres 5432; do echo waiting for postgres; sleep 2; done"
+    - name: apigateway
+      enabled: true
+      image: *waitImage
+      command:
+        - sh
+        - -c
+        - "until nc -z apigateway 8080; do echo waiting for api-gateway; sleep 2; done"
-
 # Application configuration (non-secret)
```

---

### 5. **Updated Auth Deployment Template**
**File**: `k8s/charts/services/auth/templates/deployment.yaml`  
**Issue**: Hardcoded init containers + no health checks  
**Status**: ✅ Applied

```diff
     spec:
       initContainers:
-{{ if .Values.initContainers.postgres.enabled }}
-      - name: wait-for-postgres
-        image: {{ .Values.initContainers.postgres.image }}
-        command: {{ toYaml .Values.initContainers.postgres.command | nindent 12 }}
-{{ end }}
-{{ if .Values.initContainers.apigateway.enabled }}
-      - name: wait-for-apigateway
-        image: {{ .Values.initContainers.apigateway.image }}
-        command: {{ toYaml .Values.initContainers.apigateway.command | nindent 12 }}
-{{ end }}
+      {{- /* Loop through the dependencies list */}}
+      {{- range .Values.deployment.dependencies }}
+      {{- if .enabled }}
+      - name: wait-for-{{ .name }}
+        image: {{ .image }}
+        command:
+          {{- toYaml .command | nindent 10 }}
+      {{- end }}
+      {{- end }}
       containers:
       - name:  {{ .Values.service.name }}
         image:  {{ .Values.deployment.image.repository }}:{{ .Values.deployment.image.tag }}
         imagePullPolicy:  {{ .Values.deployment.image.pullPolicy }}
         resources: {{ toYaml .Values.deployment.resources | nindent 10 }}
         envFrom:
         - configMapRef:
             name:  {{ .Values.service.name }}-config
         - secretRef:
             name:  {{ .Values.service.name }}-secrets
         ports:
-        - containerPort:  {{ .Values.service.targetPort }}
\ No newline at end of file
+        - containerPort:  {{ .Values.service.targetPort }}
+        readinessProbe:
+          httpGet:
+            path: /actuator/health
+            port: {{ .Values.service.targetPort }}
+          initialDelaySeconds: 30
+          periodSeconds: 10
+        livenessProbe:
+          httpGet:
+            path: /actuator/health
+            port: {{ .Values.service.targetPort }}
+          initialDelaySeconds: 60
+          periodSeconds: 30
\ No newline at end of file
```

**Rollback**:
```diff
     spec:
       initContainers:
+{{ if .Values.initContainers.postgres.enabled }}
+      - name: wait-for-postgres
+        image: {{ .Values.initContainers.postgres.image }}
+        command: {{ toYaml .Values.initContainers.postgres.command | nindent 12 }}
+{{ end }}
+{{ if .Values.initContainers.apigateway.enabled }}
+      - name: wait-for-apigateway
-        image: {{ .Values.initContainers.apigateway.image }}
-        command: {{ toYaml .Values.initContainers.apigateway.command | nindent 12 }}
-{{ end }}
-      {{- /* Loop through the dependencies list */}}
-      {{- range .Values.deployment.dependencies }}
-      {{- if .enabled }}
-      - name: wait-for-{{ .name }}
-        image: {{ .image }}
-        command:
-          {{- toYaml .command | nindent 10 }}
-      {{- end }}
-      {{- end }}
       containers:
       - name:  {{ .Values.service.name }}
         image:  {{ .Values.deployment.image.repository }}:{{ .Values.deployment.image.tag }}
         imagePullPolicy:  {{ .Values.deployment.image.pullPolicy }}
         resources: {{ toYaml .Values.deployment.resources | nindent 10 }}
         envFrom:
         - configMapRef:
             name:  {{ .Values.service.name }}-config
         - secretRef:
             name:  {{ .Values.service.name }}-secrets
         ports:
-        - containerPort:  {{ .Values.service.targetPort }}
-        readinessProbe:
-          httpGet:
-            path: /actuator/health
-            port: {{ .Values.service.targetPort }}
-          initialDelaySeconds: 30
-          periodSeconds: 10
-        livenessProbe:
-          httpGet:
-            path: /actuator/health
-            port: {{ .Values.service.targetPort }}
-          initialDelaySeconds: 60
-          periodSeconds: 30
\ No newline at end of file
+        - containerPort:  {{ .Values.service.targetPort }}
\ No newline at end of file
```

---

### 6. **Standardized Simulation Service Init Containers**
**File**: `k8s/charts/services/simulation/values.yaml`  
**Issue**: Hardcoded init container logic  
**Status**: ✅ Applied

```diff
   # Resource limits and requests
   resources:
     requests:
       cpu: 100m
       memory: 256Mi
     limits:
       cpu: 500m
       memory: 1Gi

-# Init containers configuration
-initContainers:
-  postgres:
-    enabled: true
-    image: busybox:1.36
-    command:
-      - sh
-      - -c
-      - "until nc -z postgres 5432; do echo waiting for postgres; sleep 2; done"
-  rabbitmq:
-    enabled: true
-    image: busybox:1.36
-    command:
-      - sh
-      - -c
-      - "until nc -z rabbitmq 5552; do echo waiting for rabbitmq stream; sleep 2; done"
-  auth:
-    enabled: true
-    image: busybox:1.36
-    command:
-      - sh
-      - -c
-      - "until nc -z auth 8081; do echo waiting for auth service; sleep 2; done"
+  # Generic wait image for init containers
+  waitImage: &waitImage "busybox:1.36"
+
+  # Dependencies list - data-driven approach for init containers
+  dependencies:
+    - name: postgres
+      enabled: true
+      image: *waitImage
+      command:
+        - sh
+        - -c
+        - "until nc -z postgres 5432; do echo waiting for postgres; sleep 2; done"
+    - name: rabbitmq
+      enabled: true
+      image: *waitImage
+      command:
+        - sh
+        - -c
+        - "until nc -z rabbitmq 5552; do echo waiting for rabbitmq stream; sleep 2; done"
+    - name: auth
+      enabled: true
+      image: *waitImage
+      command:
+        - sh
+        - -c
+        - "until nc -z auth 8081; do echo waiting for auth service; sleep 2; done"

 # Application configuration (non-secret)
```

**Rollback**: Apply the reverse diff (remove dependencies section, restore initContainers section).

---

### 7. **Updated Simulation Deployment Template**
**File**: `k8s/charts/services/simulation/templates/deployment.yaml`  
**Issue**: Hardcoded init containers  
**Status**: ✅ Applied

```diff
 spec:
   replicas: {{ .Values.deployment.replicas }}
+  strategy:
+    type: {{ .Values.deployment.strategy.type }}
+    rollingUpdate:
+      maxUnavailable: {{ .Values.deployment.strategy.rollingUpdate.maxUnavailable }}
+      maxSurge: {{ .Values.deployment.strategy.rollingUpdate.maxSurge }}
   selector:
     matchLabels:
       app: {{ .Values.service.name }}
   template:
     metadata:
       labels:
         app: {{ .Values.service.name }}
     spec:
       initContainers:
-{{ if .Values.initContainers.postgres.enabled }}
-      - name: wait-for-postgres
-        image: {{ .Values.initContainers.postgres.image }}
-        command: {{ toYaml .Values.initContainers.postgres.command | nindent 12 }}
-{{ end }}
-{{ if .Values.initContainers.rabbitmq.enabled }}
-      - name: wait-for-rabbitmq
-        image: {{ .Values.initContainers.rabbitmq.image }}
-        command: {{ toYaml .Values.initContainers.rabbitmq.command | nindent 12 }}
-{{ end }}
-{{ if .Values.initContainers.auth.enabled }}
-      - name: wait-for-auth
-        image: {{ .Values.initContainers.auth.image }}
-        command: {{ toYaml .Values.initContainers.auth.command | nindent 12 }}
-{{ end }}
+      {{- /* Loop through the dependencies list */}}
+      {{- range .Values.deployment.dependencies }}
+      {{- if .enabled }}
+      - name: wait-for-{{ .name }}
+        image: {{ .image }}
+        command:
+          {{- toYaml .command | nindent 10 }}
+      {{- end }}
+      {{- end }}
       containers:
```

**Rollback**: Apply the reverse diff (remove strategy, restore hardcoded init containers).

---

### 8. **Added Health Checks to Trade-Capture**
**File**: `k8s/charts/services/trade-capture/templates/deployment.yaml`  
**Issue**: No health checks  
**Status**: ✅ Applied

```diff
         envFrom:
         - configMapRef:
             name: {{ .Values.service.name }}-config
         - secretRef:
             name: {{ .Values.service.name }}-secrets
-        resources: {{ toYaml .Values.deployment.resources | nindent 10 }}
\ No newline at end of file
+        resources: {{ toYaml .Values.deployment.resources | nindent 10 }}
+        readinessProbe:
+          httpGet:
+            path: /actuator/health
+            port: {{ .Values.service.targetPort }}
+          initialDelaySeconds: 30
+          periodSeconds: 10
+        livenessProbe:
+          httpGet:
+            path: /actuator/health
+            port: {{ .Values.service.targetPort }}
+          initialDelaySeconds: 60
+          periodSeconds: 30
\ No newline at end of file
```

**Rollback**:
```diff
         envFrom:
         - configMapRef:
             name: {{ .Values.service.name }}-config
         - secretRef:
             name: {{ .Values.service.name }}-secrets
+        resources: {{ toYaml .Values.deployment.resources | nindent 10 }}
-        readinessProbe:
-          httpGet:
-            path: /actuator/health
-            port: {{ .Values.service.targetPort }}
-          initialDelaySeconds: 30
-          periodSeconds: 10
-        livenessProbe:
-          httpGet:
-            path: /actuator/health
-            port: {{ .Values.service.targetPort }}
-          initialDelaySeconds: 60
-          periodSeconds: 30
\ No newline at end of file
```

---

### 9. **Created Schema Validation**
**File**: `k8s/pms-platform/values.schema.json`  
**Issue**: No values validation  
**Status**: ✅ Created

**Content**: JSON schema with required fields and type validation for all components.

**Rollback**:
```bash
rm k8s/pms-platform/values.schema.json
```

---

### 10. **Fixed Trade-Capture Dependencies Reference**
**File**: `k8s/charts/services/trade-capture/templates/deployment.yaml`  
**Issue**: Wrong path `.Values.deployment.dependencies`  
**Status**: ✅ Applied

```diff
       initContainers:
       {{- /* Loop through the dependencies list */}}
-      {{- range .Values.deployment.dependencies }}
+      {{- range .Values.dependencies }}
```

**Rollback**:
```diff
       initContainers:
       {{- /* Loop through the dependencies list */}}
+      {{- range .Values.deployment.dependencies }}
-      {{- range .Values.dependencies }}
```

---

## 🧪 Validation Commands

After rollback, verify the chart still works:
```bash
cd k8s/pms-platform
helm template test . --dry-run
helm lint .
```

## ⚠️ Risk Assessment

- **Low Risk**: Health checks, schema validation (pure additions)
- **Medium Risk**: Init container standardization (logic change but same behavior)
- **High Risk**: External-secrets condition fix (affects ESO deployment)

If issues occur, rollback the external-secrets condition fix first, then test individual service changes.