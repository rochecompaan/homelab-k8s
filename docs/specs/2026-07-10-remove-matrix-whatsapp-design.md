# Remove Matrix WhatsApp Integration Design

## Goal

Remove the active `matrix-whatsapp` integration from the homelab GitOps configuration while preserving historical documentation and benchmark records.

## Scope

Remove live deployment and operational references:

- The `argocd/homelab/matrix-whatsapp/` workload manifests.
- Synapse appservice registration wiring for WhatsApp.
- The sealed appservice secret and registration template used by the bridge.
- The Justfile secret sealing helper for the bridge.
- Emergency scale up/down script entries for the removed workload.
- Grafana backup freshness alert targeting `matrix/matrix-whatsapp-postgres`.

Keep historical docs, specs, plans, and benchmark logs unchanged.

Keep the `matrix-whatsapp` ArgoCD Application temporarily as a decommission controller with an empty desired state. This avoids orphaning live resources because the existing child Application did not have `resources-finalizer.argocd.argoproj.io` before this change.

## Approach

Use GitOps-only changes. The first decommission phase leaves the child Application registered in the root app, adds the ArgoCD resources finalizer, and points it at an empty Kustomize overlay. With automated prune enabled, ArgoCD should delete the former Deployment, Service, ConfigMap, and CloudNativePG cluster from the `matrix` namespace. Removing the appservice registration from the Matrix Helm values prevents Synapse from referencing a secret that will no longer exist. Removing helper scripts and alert rules prevents future operational commands from targeting the retired app or database.

After ArgoCD confirms the `matrix-whatsapp` Application has no managed resources left, a follow-up GitOps change can remove `../../base/matrix-whatsapp`, `argocd/base/matrix-whatsapp/`, and the empty `argocd/homelab/matrix-whatsapp/` directory.

## Verification

Run static verification only; do not mutate the homelab cluster directly.

- `kubectl kustomize argocd/homelab/apps`
- `kubectl kustomize argocd/homelab/infra`
- `kubectl kustomize argocd/base/matrix`
- `kubectl kustomize argocd/homelab/matrix-whatsapp`
- Search active runtime paths for appservice, secret, helper, and workload references, excluding historical docs and the temporary empty decommission Application.
