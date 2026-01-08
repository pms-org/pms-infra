# PMS Services - Placeholder Structure

This directory contains placeholders for all PMS microservices. Teams should add their Kubernetes manifests to their respective service directories.

## Service Directory Structure

Each service directory should contain:

```
<service-name>/
├── deployment.yaml           # Kubernetes Deployment manifest
├── service.yaml             # Kubernetes Service manifest
├── <service-name>.properties # Non-sensitive configuration
└── <service-name>.env       # Sensitive secrets
```

## Available Service Placeholders

### Currently Implemented ✅
- **simulation** - Trade simulation service
- **trade-capture** - Trade capture and processing
- **validation** - Trade validation service

### Ready for Implementation 📋

| Service | Description | Owner Team |
|---------|-------------|------------|
| **pms-transactional** | Transaction processing service | TBD |
| **pms-analytics** | Analytics and reporting service | TBD |
| **pms-auth** | Authentication and authorization | TBD |
| **pms-rttm** | Real-Time Trade Matching | TBD |
| **pms-leaderboard** | Performance leaderboard service | TBD |
| **pms-apigateway** | API Gateway and routing | TBD |
| **pms-portfolio** | Portfolio management service | TBD |

## Adding a New Service

1. **Navigate to your service directory:**
   ```bash
   cd k8s/base/apps/<your-service-name>
   ```

2. **Remove the .gitkeep file:**
   ```bash
   rm .gitkeep
   ```

3. **Create deployment.yaml:**
   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: <service-name>
     namespace: pms
   spec:
     replicas: 1
     selector:
       matchLabels:
         app: <service-name>
     template:
       metadata:
         labels:
           app: <service-name>
       spec:
         containers:
         - name: <service-name>
           image: <your-image>:<tag>
           ports:
           - containerPort: <port>
           envFrom:
           - configMapRef:
               name: <service-name>-config
           - secretRef:
               name: <service-name>-secrets
   ```

4. **Create service.yaml:**
   ```yaml
   apiVersion: v1
   kind: Service
   metadata:
     name: <service-name>
     namespace: pms
   spec:
     selector:
       app: <service-name>
     ports:
     - port: <port>
       targetPort: <port>
     type: ClusterIP
   ```

5. **Create <service-name>.properties:**
   ```properties
   # Non-sensitive configuration
   SERVICE_NAME=<service-name>
   PORT=<port>
   # Add your config here
   ```

6. **Create <service-name>.env:**
   ```env
   # Sensitive secrets
   API_KEY=CHANGEME
   DATABASE_PASSWORD=CHANGEME
   ```

7. **Update base kustomization.yaml:**
   Add your service resources to `k8s/base/kustomization.yaml`:
   ```yaml
   resources:
     - apps/<service-name>/deployment.yaml
     - apps/<service-name>/service.yaml
   ```

8. **Update overlay kustomization.yaml:**
   Add generators to `k8s/overlays/dev/kustomization.yaml` and `k8s/overlays/prod/kustomization.yaml`:
   ```yaml
   configMapGenerator:
     - name: <service-name>-config
       envs:
         - <service-name>.properties
   
   secretGenerator:
     - name: <service-name>-secrets
       envs:
         - <service-name>.env
   ```

9. **Copy config files to overlays:**
   ```bash
   cp k8s/base/apps/<service-name>/<service-name>.properties k8s/overlays/dev/
   cp k8s/base/apps/<service-name>/<service-name>.env k8s/overlays/dev/
   ```

10. **Test your deployment:**
    ```bash
    kubectl kustomize k8s/overlays/dev
    kubectl apply -k k8s/overlays/dev
    ```

## Best Practices

- ✅ Use `envFrom` instead of inline `env` variables
- ✅ Separate sensitive (secrets) from non-sensitive (configmaps) config
- ✅ Add init containers for service dependencies
- ✅ Define resource requests and limits
- ✅ Use meaningful labels
- ✅ Follow the naming convention: `<service-name>-config` and `<service-name>-secrets`

## Questions?

Refer to existing services (simulation, trade-capture, validation) as examples.
See the main `k8s/README.md` for complete documentation.
