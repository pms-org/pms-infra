Service: trade-capture

Image updates (CI contract):

- File to modify: `services/trade-capture/kustomization.yaml`
- What to change: in the `images` section update `newTag` to the immutable image tag (e.g. the image SHA).
- Commit message suggestion: `chore(trade-capture): bump image to <sha>`

Example excerpt (kustomization.yaml):

images:
  - name: niishantdev/pms-trade-capture
    newTag: "<sha>"

Argo CD Applications per environment are defined in `argocd/applications/`.

CI example
- The `pms-trade-capture` repo includes a GitHub Actions workflow that updates `pms-infra` automatically.
- Required token for `pms-infra` updates: `INFRA_REPO_TOKEN` (personal access token with repo permissions for `pms-org/pms-infra`).
