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

## Forgejo Actions runner

Forgejo Actions are enabled in the Forgejo Helm values. Generate the sealed
runner registration Secret with:

```sh
just seal-forgejo-action-runner-secret
```

The recipe reads the registration token from:

- `pass show FORGEJO_ACTION_RUNNER_TOKEN`

The recipe writes:

- `argocd/homelab/forgejo/bootstrap/runner-init-secret.yaml`

This app also bootstraps ArgoCD OCI Helm repository secrets for:

- `code.forgejo.org/forgejo-helm`
- `codeberg.org/wrenix/helm-charts`

## Hostname

Forgejo is exposed at:

- `https://git.compaan.cloud`
