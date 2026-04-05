# Forgejo

This directory contains bootstrap manifests for the Forgejo ArgoCD app.

## Admin secret

Generate the sealed admin Secret with:

```sh
just seal-forgejo-admin-secret
```

Environment variables:

- `FORGEJO_ADMIN_USERNAME` (default: `roche`)
- `FORGEJO_ADMIN_PASSWORD` (optional, generated if unset)

The recipe writes:

- `argocd/homelab/forgejo/bootstrap/admin-secret.yaml`
- `argocd/homelab/forgejo/bootstrap/kustomization.yaml`

This app also bootstraps an ArgoCD OCI Helm repository secret for:

- `code.forgejo.org/forgejo-helm`

## Hostname

Forgejo is exposed at:

- `https://git.compaan`
