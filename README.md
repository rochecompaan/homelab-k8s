# homelab-k8s

GitOps repository for the homelab Kubernetes cluster.

ArgoCD is the deployment controller. This repo contains:
- ArgoCD `Application` definitions
- cluster-specific manifests and Helm values
- sealed-secret generation workflows in `Justfile`
- a small number of app-local manifests vendored into the repo when needed

## Repository layout

```text
argocd/
├── base/                  # ArgoCD Application definitions
├── homelab/               # Cluster-specific manifests, values, and secrets
└── overlays/testing/      # Ad-hoc test manifests
```

### `argocd/base/`

Each app lives in its own directory and is usually defined by:
- `app.yaml` - the ArgoCD `Application`
- `kustomization.yaml`

These apps either:
- point at external Helm/OCI charts, or
- point back into this repo under `argocd/homelab/...`

Examples:
- `argocd/base/argocd`
- `argocd/base/forgejo`
- `argocd/base/miniziti-operator`
- `argocd/base/infra`

### `argocd/homelab/`

Cluster-specific desired state for the homelab cluster.

Examples:
- `argocd/homelab/apps/` - bootstrap bundle of ArgoCD Applications
- `argocd/homelab/infra/` - shared cluster infrastructure manifests
- `argocd/homelab/forgejo/` - Forgejo bootstrap resources
- `argocd/homelab/miniziti-operator/` - operator install bundle and secrets
- `argocd/homelab/garage/` - local Helm chart and values
- `argocd/homelab/speedtest-exporter/` - local manifests for the exporter

## ArgoCD bootstrap model

The root ArgoCD app should target:

- `argocd/homelab/apps`

That directory registers the rest of the cluster applications.

Sync ordering is handled with `argocd.argoproj.io/sync-wave` annotations on the
individual `Application` manifests.

## Secrets workflow

Secrets are not committed in plaintext.

This repo uses `kubeseal` workflows via the `Justfile` to generate sealed
secrets in-place.

Available recipes include:
- `just seal-forgejo-admin-secret`
- `just seal-openziti-management-secret`
- `just seal-webmutt-secret`
- `just seal-openclaw-mail-secret`
- `just seal-matrix-secret`

Operational helpers:
- `just argocd-login`
- `just argocd-sync app="root"`

## Notable apps

- `argocd` - ArgoCD itself
- `cert-manager` / `trust-manager`
- `traefik`
- `longhorn`
- `cloudnative-pg`
- `forgejo`
- `garage`
- `harbor`
- `matrix`
- `nextcloud`
- `miniziti-operator`
- `ziti-controller` / `ziti-router`

## Working conventions

- GitOps-first: cluster state should come from this repo
- keep secrets sealed or generated, never plaintext
- prefer app-local manifests/values under `argocd/homelab/<app>/`
- keep ArgoCD source repositories small and focused

## Current focus

This repo was split out from a larger monorepo so ArgoCD no longer has to fetch
unrelated host and desktop configuration just to reconcile the cluster.
