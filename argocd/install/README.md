Install Argo CD

Apply the official Argo CD install manifest with kustomize (this kustomization references the official upstream manifest):

kubectl apply -k argocd/install

Notes:
- This keeps the install declarative and uses the official manifest as the source of truth.
- After Argo CD is installed, create `argocd/projects/*` and `argocd/applications/*` resources inside the `argocd` namespace.
