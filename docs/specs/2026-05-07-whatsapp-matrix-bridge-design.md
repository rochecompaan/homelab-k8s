# WhatsApp Matrix Bridge Design

Date: 2026-05-07

## Goal

Add a WhatsApp bridge to the homelab Matrix server using `mautrix-whatsapp`, deployed through GitOps and reconciled by ArgoCD. The first version is single-user only for `@roche:matrix.compaan`, uses encrypted bridged rooms, stores bridge state in PostgreSQL managed by CloudNativePG, and exposes no public bridge ingress.

## Current context

The existing Matrix deployment is managed by the `matrix` ArgoCD Application in `argocd/base/matrix/app.yaml`. It deploys Synapse from the `remram44/matrix` Helm chart into the `matrix` namespace. Matrix secrets and namespace resources live under `argocd/homelab/infra/`, and secret generation is handled through `Justfile` plus Sealed Secrets.

Cluster changes must remain GitOps-only. No direct workstation writes to homelab Kubernetes resources should be used for deployment.

## Chosen approach

Use a dedicated ArgoCD app with plain Kubernetes manifests:

- Add a new `matrix-whatsapp` ArgoCD Application under `argocd/base/matrix-whatsapp/`.
- Point that app at `argocd/homelab/matrix-whatsapp/`.
- Deploy bridge runtime and database resources into the existing `matrix` namespace.
- Store the shared appservice registration SealedSecret in `argocd/homelab/infra/` so it is created by the existing early `infra` app before Synapse tries to mount it.
- Keep Synapse in the existing `matrix` Helm app, but update its values to load the mautrix appservice registration file.

This keeps bridge ownership clear, avoids adding an external bridge Helm chart dependency, and matches the repository's current app-local manifest pattern.

## Architecture

The bridge runs as an internal Kubernetes workload in the `matrix` namespace. Synapse reads a mounted appservice registration file from a Secret created by the early `infra` app and communicates with the bridge over a ClusterIP service. The bridge communicates with Synapse through the in-cluster Matrix service URL. There is no public ingress or DNS entry for the bridge.

The bridge is configured for single-user operation:

- Admin and allowed Matrix user: `@roche:matrix.compaan`
- Bridge implementation: `mautrix-whatsapp`
- Room encryption: enabled by default for bridged rooms
- Database: dedicated CloudNativePG PostgreSQL cluster in the `matrix` namespace

## Components and files

Planned files:

- `argocd/base/matrix-whatsapp/app.yaml`
  - ArgoCD `Application` for the bridge resources.
  - Destination namespace: `matrix`.
  - Automated sync with prune/self-heal.
  - Sync wave after the existing `matrix` app; the shared registration Secret is handled separately by `infra`.

- `argocd/base/matrix-whatsapp/kustomization.yaml`
  - Registers the ArgoCD Application manifest.

- `argocd/homelab/apps/kustomization.yaml`
  - Adds `../../base/matrix-whatsapp` to the root app bundle.

- `argocd/homelab/matrix-whatsapp/kustomization.yaml`
  - Renders bridge runtime and database resources in the `matrix` namespace.

- `argocd/homelab/matrix-whatsapp/postgres-cluster.yaml`
  - CloudNativePG `Cluster` for bridge state.
  - Dedicated cluster name: `matrix-whatsapp-postgres`, to avoid conflicts in the shared `matrix` namespace.
  - Initial database and owner: `mautrix_whatsapp`.
  - Initial sizing: 3 instances, `local-path` storage class, 10Gi per instance.

- `argocd/homelab/matrix-whatsapp/configmap.yaml`
  - Non-secret mautrix-whatsapp configuration.

- `argocd/homelab/infra/matrix-whatsapp-secret.yaml`
  - SealedSecret containing appservice registration material and generated sensitive values.
  - Included from `argocd/homelab/infra/kustomization.yaml` so Synapse can mount it before the bridge app is reconciled.

- `argocd/homelab/matrix-whatsapp/deployment.yaml`
  - mautrix-whatsapp deployment.
  - Mounts config and secret material.
  - Reads database connection information from CNPG-generated secrets/services.

- `argocd/homelab/matrix-whatsapp/service.yaml`
  - Internal ClusterIP service for Synapse-to-bridge callbacks.

- `Justfile`
  - Adds `seal-matrix-whatsapp-secret` to generate and seal appservice tokens/registration.

- `argocd/base/matrix/app.yaml`
  - Adds Synapse appservice registration config and secret volume mount.

## Data and secrets flow

Startup and reconciliation flow:

1. ArgoCD reconciles the root app bundle.
2. The existing `infra` app creates the shared appservice registration Secret from `argocd/homelab/infra/matrix-whatsapp-secret.yaml`.
3. Synapse loads the appservice registration file from that mounted Secret when the `matrix` app reconciles.
4. ArgoCD creates or updates the `matrix-whatsapp` app.
5. CloudNativePG creates the bridge PostgreSQL cluster in the `matrix` namespace.
6. mautrix-whatsapp starts with configuration from a ConfigMap, sensitive material from the shared Secret, and database access to the CNPG app database.
7. `@roche:matrix.compaan` controls the bridge from Matrix and pairs WhatsApp through the bridge's QR/login flow.

Secret handling requirements:

- Do not commit plaintext bridge secrets.
- Generate `as_token`, `hs_token`, and registration YAML through a `Justfile` helper.
- Seal the generated Kubernetes Secret before committing it.
- Use one shared registration secret for both Synapse and the bridge to avoid token drift.
- Store WhatsApp session, bridge mapping, and crypto state in PostgreSQL, not in repository files.

## Operations and failure modes

Expected operational behavior:

- The bridge has no external ingress.
- Restarting the bridge should preserve WhatsApp and crypto state through PostgreSQL persistence.
- Synapse may need a rollout when the appservice registration mount/config changes.
- Future multi-user support can be added by relaxing mautrix-whatsapp permissions, but the first deployment stays single-user.

Expected failure modes:

- Database unavailable: bridge pod remains unhealthy or restarts until CNPG is ready.
- Appservice token mismatch: Synapse and bridge appservice authentication fails. Regenerate and seal one shared registration secret.
- Incorrect internal service URL: Synapse cannot call the bridge. Verify the ClusterIP service name and port.
- Encryption state loss: encrypted bridged rooms may fail. Avoid by keeping crypto state in the persistent database.

## Testing and verification

Static validation:

- `kustomize build argocd/homelab/apps`
- `kustomize build argocd/homelab/matrix-whatsapp`

Deployment verification through ArgoCD only:

- Sync the root app or `matrix-whatsapp` app through ArgoCD.
- Verify the CNPG cluster is healthy.
- Verify the bridge deployment is ready.
- Verify Synapse has loaded the appservice registration file.
- Verify the bridge bot responds to `@roche:matrix.compaan` in Matrix.
- Pair WhatsApp using the bridge QR/login flow.
- Send one inbound and one outbound WhatsApp message through an encrypted Matrix room.

## Out of scope for first version

- Multi-user bridge access.
- Public bridge ingress.
- Additional Matrix bridges.
- Direct cluster mutation from a workstation.
