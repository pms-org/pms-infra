Environments

This folder is optional and can be used to collect environment-level resources (e.g., namespace-wide settings, network policies, team-config).

Promotion strategy
- Promotion is performed via Git: update the image tag in `services/<service>/kustomization.yaml` in `dev`, then open a PR that cherry-picks or merges the same change into `stage` and `prod` branches or overlays.
- Rollback is performed by reverting the commit that changed the image tag.
