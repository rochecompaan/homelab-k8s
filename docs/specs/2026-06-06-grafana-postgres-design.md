# Grafana Postgres Design

## Goal

Move Grafana off its SQLite-backed PVC and onto a dedicated CloudNativePG Postgres database. The existing SQLite data does not need to be preserved.

## Decisions

- Use a dedicated CloudNativePG `Cluster` named `grafana-postgres` in the `monitoring` namespace.
- Use `local-path` storage with 3 instances and 10Gi per instance.
- Initialize database `grafana` owned by user `grafana`.
- Let CloudNativePG generate the application Secret `grafana-postgres-app`.
- Configure Grafana through Helm values to use Postgres via `GF_DATABASE_*` environment variables.
- Load `GF_DATABASE_PASSWORD` from `grafana-postgres-app` instead of writing it into manifests.
- Disable Grafana SQLite PVC persistence so Grafana starts with a clean Postgres-backed database.
- Create a GitOps-managed SealedSecret for Grafana admin credentials, generated from `pass show private/login/grafana.compaan`, so a fresh database initializes with the expected login.
- Do not migrate dashboards, users, alert state, or other data from SQLite.

## GitOps Layout

Add a new ArgoCD child app:

- `argocd/base/grafana-postgres/app.yaml`
  - Application name: `grafana-postgres`
  - Destination namespace: `monitoring`
  - Source path: `argocd/homelab/grafana-postgres`
  - Sync wave: `2`, before `kube-prometheus-stack` at wave `3`

Add the app to:

- `argocd/homelab/apps/kustomization.yaml`

Add the homelab manifests:

- `argocd/homelab/grafana-postgres/kustomization.yaml`
- `argocd/homelab/grafana-postgres/postgres-cluster.yaml`
- `argocd/homelab/grafana-postgres/grafana-admin-secret.yaml`

## Grafana Helm Changes

Update `argocd/base/kube-prometheus-stack/app.yaml` under `valuesObject.grafana`:

- Set `persistence.enabled: false`.
- Remove the SQLite `database.wal` setting.
- Keep ingress, alert sidecar, plugins, and VictoriaLogs datasource configuration.
- Set database connection values with environment variables:
  - `GF_DATABASE_TYPE=postgres`
  - `GF_DATABASE_HOST=grafana-postgres-rw.monitoring.svc.cluster.local:5432`
  - `GF_DATABASE_NAME=grafana`
  - `GF_DATABASE_USER=grafana`
  - `GF_DATABASE_SSL_MODE=disable`
  - `GF_DATABASE_PASSWORD` from Secret `grafana-postgres-app`, key `password`
- Set `admin.existingSecret` to the sealed admin credentials Secret.

## Sync and Rollout Flow

1. Commit and push the GitOps changes.
2. Sync `root` so the new child app is registered.
3. Sync `grafana-postgres` and wait for the CNPG cluster and `grafana-postgres-app` Secret.
4. Sync `kube-prometheus-stack` so Grafana restarts with Postgres configuration.
5. Sync `grafana-dashboards` to reprovision alert rules and notification config.

## Verification

- `kubectl kustomize argocd/homelab/grafana-postgres`
- `kubectl kustomize argocd/homelab/apps`
- Helm render for `kube-prometheus-stack` showing Grafana `GF_DATABASE_*` env vars and no SQLite PVC mount.
- CNPG cluster reports ready.
- Secret `monitoring/grafana-postgres-app` exists.
- Grafana pod is `4/4 Running` and Service has endpoints.
- `https://grafana.compaan/api/health` returns `200` and `database: ok`.
- Grafana logs do not show fresh SQLite corruption or lock errors.
- Matrix alert contact point and alert provisioning are present after `grafana-dashboards` sync.

## Risks and Mitigations

- Fresh database resets Grafana state. This is accepted for this migration.
- Grafana plugins will reinstall on pod startup because persistence is disabled. If plugin installation is unreliable, follow up by packaging the plugin in the image or adding a separate non-database plugin cache strategy.
- ArgoCD app sync waves register apps in order but child app reconciliation can still race. During migration, sync `grafana-postgres` manually and wait for the generated Secret before syncing `kube-prometheus-stack`.
- The old Grafana PVC may be pruned or left unused depending on Helm/ArgoCD resource tracking. Its data is not required after migration.
