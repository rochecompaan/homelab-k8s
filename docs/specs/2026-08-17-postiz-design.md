# Postiz Homelab Deployment Design

## Status

Revised and approved for implementation planning on 2026-08-17.

## Purpose

This change adds Postiz to the homelab through ArgoCD. The deployment uses GitOps for all cluster resources.

Postiz provides a private interface at `https://postiz.compaan`. The first release does not configure social-provider credentials.

## Background

Postiz publishes an OCI Helm chart at `ghcr.io/gitroomhq/postiz-helmchart/charts/postiz-app`.

The latest chart release is `1.0.5`. This release declares application version `1.3.0` and does not include Temporal.

Current Postiz releases require Temporal. Temporal replaced the old cron and worker services in Postiz `v2.12.0`.

The chart also pins old Bitnami PostgreSQL and Redis images. Docker Hub no longer provides these image tags in the maintained repositories.

The exact images remain in unsupported `bitnamilegacy` repositories. This deployment will not use those images.

The deployment will use Postiz `v2.23.0`. It will also install the official Temporal Helm chart `1.6.0`.

## Goals

- Deploy Postiz `v2.23.0` through ArgoCD.
- Expose Postiz through the private Traefik ingress controller.
- Store all persistent data on Longhorn volumes.
- Keep all Postiz credentials encrypted in Git.
- Use CloudNativePG for the Postiz and Temporal databases.
- Use one official Redis `7.2` StatefulSet for Postiz.
- Use Temporal with PostgreSQL persistence and SQL visibility.
- Keep Temporal, PostgreSQL, and Redis private to the cluster.
- Make each dependency explicit in the ArgoCD application graph.

## Non-goals

- Configure social-provider credentials.
- Configure email delivery.
- Configure public object storage.
- Expose the Temporal user interface.
- Add database backup automation.
- Add high-availability replicas for Postiz, Redis, Temporal, or CNPG.
- Use the unavailable Bitnami images or unsupported `bitnamilegacy` images.
- Apply or change Kubernetes resources directly from a workstation.

## Application layout

The change adds four ArgoCD applications. All four applications use the `postiz` namespace.

### `postiz-temporal-db`

This application deploys one CloudNativePG cluster. The cluster uses a 10 GiB Longhorn volume.

The cluster contains these logical databases:

- `temporal`
- `temporal_visibility`

The cluster creates an application role for Temporal. CloudNativePG creates the Kubernetes Secret for this role.

The application uses sync wave `4`.

### `postiz-data`

This application deploys the persistent services and Secrets for Postiz.

A single-instance CloudNativePG cluster stores the Postiz database. The cluster uses a 10 GiB Longhorn volume.

A single Redis StatefulSet uses the official `redis:7.2.15-alpine` image. The image uses this multi-platform digest:

`sha256:05a97a479bc73de66f087dc05b569010772880f778cc8671fa6b8aadee32e5c6`

Redis uses append-only persistence on a 2 GiB Longhorn volume. An ACL file supplies the Redis password.

A separate 20 GiB Longhorn PVC stores uploaded media. ArgoCD does not prune this PVC.

Three SealedSecrets supply application, database, and Redis credentials.

The application uses sync wave `4`.

### `postiz-temporal`

This application deploys the official Temporal Helm chart from `https://go.temporal.io/helm-charts/`.

The application pins chart version `1.6.0`. Each required Temporal server component uses one replica.

Temporal uses its CNPG cluster for its default store and visibility store. Both stores use the `postgres12_pgx` plugin.

The Temporal chart manages the required database schemas. It reads the database password from the CNPG application Secret.

The configuration disables Elasticsearch, the Temporal user interface, and the admin-tools deployment.

Temporal has no ingress. Postiz connects to the internal Temporal frontend service on port `7233`.

The application uses sync wave `5`.

### `postiz`

This application deploys a local copy of the Postiz Helm chart. The local chart starts from upstream release `1.0.5`.

The local chart removes the unavailable PostgreSQL and Redis dependencies. ArgoCD deploys those services through `postiz-data`.

The chart pins the Postiz image to `ghcr.io/gitroomhq/postiz-app:v2.23.0`. It does not use the upstream `latest` tag.

The uploaded-media volume mounts at `/uploads`.

The Postiz Deployment uses the `Recreate` strategy. This strategy prevents a rollout from blocking on the single uploads volume.

The application uses sync wave `6`.

## Local chart changes

The local Postiz chart contains four focused changes.

### Remove unavailable dependencies

The local chart removes the PostgreSQL and Redis dependency declarations, lock file, and vendored dependency directories.

The chart renders only the Postiz application resources. The `postiz-data` application owns all data services.

### Existing Secret support

The chart adds an `existingSecret` value. The Deployment loads sensitive environment variables from this Secret.

If `existingSecret` has a value, the chart does not create its default application Secret.

### Deployment strategy

The chart adds a configurable Deployment strategy. The homelab values use `Recreate`.

### Health probes

The chart adds startup, readiness, and liveness probes. Each probe uses the Postiz HTTP service on container port `5000`.

The startup probe allows the application enough time for database migrations and service initialization.

## Secrets

The deployment uses three SealedSecrets. Each decrypted Secret has one clear consumer.

### `postiz-secrets`

The Postiz Deployment loads this Secret through `envFrom`.

The Secret contains these keys:

- `JWT_SECRET`
- `DATABASE_URL`
- `REDIS_URL`

### `postiz-db-app`

CloudNativePG uses this `kubernetes.io/basic-auth` Secret during database bootstrap.

The Secret contains these keys:

- `username`
- `password`

The username is `postiz`. `DATABASE_URL` uses the same generated password.

### `postiz-redis`

The Redis pod mounts this Secret as an ACL file.

The Secret contains the `users.acl` key. `REDIS_URL` uses the same generated password.

The chart configuration contains no plaintext password or connection URI. Social-provider keys are not present in the first release.

A pod annotation contains a manual secret revision. A revision change recreates the Postiz pod after a planned secret change.

Temporal reads its CNPG-generated application Secret. The repository does not store the Temporal database password.

## Postiz configuration

The Postiz ConfigMap sets these core values:

| Variable | Value |
| --- | --- |
| `MAIN_URL` | `https://postiz.compaan` |
| `FRONTEND_URL` | `https://postiz.compaan` |
| `NEXT_PUBLIC_BACKEND_URL` | `https://postiz.compaan/api` |
| `BACKEND_INTERNAL_URL` | `http://localhost:3000` |
| `TEMPORAL_ADDRESS` | `postiz-temporal-frontend.postiz.svc.cluster.local:7233` |
| `IS_GENERAL` | `true` |
| `DISABLE_REGISTRATION` | `false` |
| `RUN_CRON` | `true` |
| `STORAGE_PROVIDER` | `local` |
| `UPLOAD_DIRECTORY` | `/uploads` |
| `NEXT_PUBLIC_UPLOAD_STATIC_DIRECTORY` | `/uploads` |

The configuration can add social-provider keys in a later change.

## Postiz data services

The Postiz CNPG cluster is named `postiz-db`. It creates the `postiz` database with the `postiz` owner.

Postiz connects to `postiz-db-rw.postiz.svc.cluster.local:5432`.

The Redis Service is named `postiz-redis`. It is private and exposes port `6379`.

Redis loads this configuration:

```text
appendonly yes
appendfsync everysec
dir /data
aclfile /run/secrets/users.acl
```

The Redis StatefulSet uses TCP startup, readiness, and liveness probes. The probes do not expose credentials in process arguments.

## Ingress and TLS

The Postiz ingress uses `traefik-private`.

The ingress host is `postiz.compaan`. The ingress uses the `compaan-ca` cert-manager issuer.

The TLS Secret is `postiz-compaan-tls`. Cert-manager creates and renews this Secret.

Temporal, PostgreSQL, and Redis use cluster-only services. These services have no external ingress.

## Data flow

1. A browser connects to `https://postiz.compaan`.
2. The private Traefik controller sends the request to the Postiz service.
3. The Postiz service sends the request to container port `5000`.
4. Postiz stores application data in the `postiz-db` CNPG cluster.
5. Postiz uses `postiz-redis` for cache and session data.
6. Postiz sends workflow requests to the Temporal frontend service.
7. Temporal stores workflow data in its dedicated CNPG cluster.
8. Postiz stores uploaded media on the `/uploads` Longhorn volume.

## Reconciliation and recovery

Each ArgoCD application enables automated sync, prune, self-heal, and retry backoff.

Sync wave `4` creates both data applications. Sync wave `5` creates Temporal. Sync wave `6` creates Postiz.

Temporal schema jobs complete before the Temporal server becomes ready. Postiz probes keep traffic away from an unready pod.

Longhorn keeps the data volumes after a pod or node error. A replacement pod can attach the existing volume.

The stateful services use one instance each. A reschedule causes a short service interruption.

A Git revert is the rollback method for manifest changes. The GitOps workflow does not use direct `kubectl apply` or Helm changes.

## Security

- The repository stores only SealedSecret ciphertext.
- The Postiz and Redis images use fixed versions and digests where available.
- Temporal has no public endpoint.
- PostgreSQL and Redis use password authentication.
- Redis reads its password from a mounted ACL file.
- The private CA protects the Postiz ingress.
- Social-provider credentials stay out of the initial deployment.
- The deployment does not use unsupported Bitnami legacy images.

## Verification

The implementation will use chart behavior tests and direct manifest rendering.

The verification will include these commands and checks:

1. Run the Postiz chart behavior tests.
2. Run `helm lint` for the local Postiz chart.
3. Render the chart without `existingSecret`.
4. Render the chart with `existingSecret`.
5. Make sure that the second render does not create the application Secret.
6. Make sure that the Postiz Deployment references `postiz-secrets`.
7. Make sure that the local chart renders no PostgreSQL or Redis workload.
8. Make sure that all four PVCs use Longhorn and the approved sizes.
9. Make sure that Redis uses the approved image digest and ACL mount.
10. Render Temporal chart `1.6.0` with the CNPG persistence configuration.
11. Build each local Kustomize directory.
12. Build `argocd/homelab/apps` and inspect the complete application set.
13. Search the rendered output for plaintext credentials.
14. Run the existing Python test suite in `scripts/`.

This repository does not track a `flake.nix` file. Therefore, `nix flake check` does not apply to this change.

After Git delivery, ArgoCD must report all four applications as `Synced` and `Healthy`.

The private Postiz page must load with a valid internal certificate. A new account must complete registration.

An uploaded file must remain available after a normal GitOps-driven Postiz pod replacement.

## Known limits and follow-up work

The first release does not add application-level database backups. Longhorn storage protects against a single disk or pod error.

The private Postiz host limits external access to uploaded media. Some social platforms must fetch media through a public HTTPS URL.

Before those providers are enabled, a later change can add Cloudflare R2 or another public object store.

The vendored Postiz chart requires manual upstream updates. Each update must review the local Secret, strategy, probe, and dependency changes.

## Acceptance criteria

- ArgoCD manages all Postiz and Temporal resources from this repository.
- Postiz runs image `v2.23.0`.
- Redis runs `7.2.15-alpine` with the approved digest.
- Temporal runs from chart `1.6.0` with CNPG SQL persistence.
- Postiz is available only at `https://postiz.compaan`.
- PostgreSQL, Redis, Temporal data, and uploads use Longhorn storage.
- No plaintext credential exists in Git or rendered ArgoCD application values.
- The local Postiz chart renders no Bitnami workload or image.
- The Postiz pod becomes ready only after its HTTP service responds.
- All rendering and repository checks pass.
