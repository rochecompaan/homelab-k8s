# Grafana Postgres Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move Grafana from the unstable SQLite PVC to a fresh dedicated CloudNativePG Postgres database without preserving SQLite data.

**Architecture:** Add a GitOps-managed CloudNativePG cluster in `monitoring`, expose it to Grafana through the CNPG-generated app Secret, and reconfigure the kube-prometheus-stack Grafana subchart to use Postgres environment variables. Disable Grafana persistence so the old SQLite PVC is no longer mounted, and GitOps-manage Grafana admin credentials so the fresh database initializes with the expected login.

**Tech Stack:** ArgoCD Application CRs, Kustomize, CloudNativePG, kube-prometheus-stack Helm chart 79.12.0, Grafana Helm subchart 10.3.0, SealedSecrets, kubectl, helm, yq, pass.

---

## File Structure

- `argocd/base/grafana-postgres/kustomization.yaml` — ArgoCD app wrapper for the new Grafana Postgres child application.
- `argocd/base/grafana-postgres/app.yaml` — Child Application pointing to `argocd/homelab/grafana-postgres` with sync wave `2`.
- `argocd/homelab/grafana-postgres/kustomization.yaml` — Homelab resource list for the Grafana database and admin Secret.
- `argocd/homelab/grafana-postgres/postgres-cluster.yaml` — CNPG `Cluster` manifest for Grafana.
- `argocd/homelab/grafana-postgres/grafana-admin-secret.yaml` — SealedSecret generated from `pass show private/login/grafana.compaan`.
- `argocd/homelab/apps/kustomization.yaml` — Root app-of-apps resource list; add `../../base/grafana-postgres` before `../../base/kube-prometheus-stack`.
- `argocd/base/kube-prometheus-stack/app.yaml` — Grafana Helm values; switch from SQLite persistence to Postgres env vars and the sealed admin Secret.

No new automated test files are required. This is static GitOps/Helm configuration, so verification uses Kustomize builds, Helm render checks, ArgoCD sync status, Kubernetes readiness, and Grafana HTTP/API checks.

---

### Task 1: Add the Grafana Postgres ArgoCD app and CNPG cluster

**Files:**
- Create: `argocd/base/grafana-postgres/kustomization.yaml`
- Create: `argocd/base/grafana-postgres/app.yaml`
- Create: `argocd/homelab/grafana-postgres/kustomization.yaml`
- Create: `argocd/homelab/grafana-postgres/postgres-cluster.yaml`

- [ ] **Step 1: Create the directory structure**

Run:

```bash
mkdir -p argocd/base/grafana-postgres argocd/homelab/grafana-postgres
```

Expected: command exits `0`.

- [ ] **Step 2: Create the base Kustomization**

Write `argocd/base/grafana-postgres/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: argocd
resources:
  - app.yaml
```

- [ ] **Step 3: Create the ArgoCD Application**

Write `argocd/base/grafana-postgres/app.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: grafana-postgres
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: '2'
spec:
  project: default
  source:
    repoURL: git@github.com:rochecompaan/homelab-k8s.git
    targetRevision: main
    path: argocd/homelab/grafana-postgres
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

- [ ] **Step 4: Create the homelab Kustomization**

Write `argocd/homelab/grafana-postgres/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: monitoring
resources:
  - postgres-cluster.yaml
```

- [ ] **Step 5: Create the CNPG Cluster manifest**

Write `argocd/homelab/grafana-postgres/postgres-cluster.yaml`:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: grafana-postgres
spec:
  instances: 3
  storage:
    size: 10Gi
    storageClass: local-path
  bootstrap:
    initdb:
      database: grafana
      owner: grafana
```

- [ ] **Step 6: Verify both Kustomizations build**

Run:

```bash
kubectl kustomize argocd/base/grafana-postgres >/tmp/grafana-postgres-base.yaml
kubectl kustomize argocd/homelab/grafana-postgres >/tmp/grafana-postgres-homelab.yaml
yq -r 'select(.kind == "Application") | .metadata.name + " wave=" + .metadata.annotations["argocd.argoproj.io/sync-wave"]' /tmp/grafana-postgres-base.yaml
yq -r 'select(.kind == "Cluster") | .metadata.name + " instances=" + (.spec.instances|tostring) + " storageClass=" + .spec.storage.storageClass' /tmp/grafana-postgres-homelab.yaml
```

Expected output includes:

```text
grafana-postgres wave=2
grafana-postgres instances=3 storageClass=local-path
```

- [ ] **Step 7: Commit the app and cluster manifests**

Run:

```bash
git add argocd/base/grafana-postgres argocd/homelab/grafana-postgres
git commit -m "feat(grafana): add postgres database app"
```

Expected: one commit containing the new app and CNPG cluster manifests.

---

### Task 2: Generate and add the Grafana admin SealedSecret

**Files:**
- Create: `argocd/homelab/grafana-postgres/grafana-admin-secret.yaml`
- Modify: `argocd/homelab/grafana-postgres/kustomization.yaml`

- [ ] **Step 1: Generate the sealed admin Secret from pass**

Run this from the repo root:

```bash
set -euo pipefail
cred="$(pass show private/login/grafana.compaan)"
admin_user="$(sed -nE 's/^(login|username|user):[[:space:]]*//Ip' <<<"$cred" | head -n1)"
admin_password="$(printf '%s' "$cred" | head -n1 | tr -d '\r')"
: "${admin_user:?missing Grafana admin user in pass entry}"
: "${admin_password:?missing Grafana admin password in pass entry}"
kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" \
  -n monitoring create secret generic grafana-admin \
  --from-literal=admin-user="$admin_user" \
  --from-literal=admin-password="$admin_password" \
  --dry-run=client -o yaml \
  | kubeseal \
      --controller-name sealed-secrets-controller \
      --controller-namespace kube-system \
      --format yaml \
  > argocd/homelab/grafana-postgres/grafana-admin-secret.yaml
unset cred admin_user admin_password
```

Expected:

- The file `argocd/homelab/grafana-postgres/grafana-admin-secret.yaml` exists.
- It has `kind: SealedSecret`.
- It has `metadata.name: grafana-admin` and `metadata.namespace: monitoring`.
- It does not contain plaintext admin credentials.

- [ ] **Step 2: Add the SealedSecret to the homelab Kustomization**

Modify `argocd/homelab/grafana-postgres/kustomization.yaml` to exactly:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: monitoring
resources:
  - postgres-cluster.yaml
  - grafana-admin-secret.yaml
```

- [ ] **Step 3: Verify the sealed Secret renders without plaintext**

Run:

```bash
kubectl kustomize argocd/homelab/grafana-postgres >/tmp/grafana-postgres-with-secret.yaml
yq -r 'select(.kind == "SealedSecret") | .metadata.name + " namespace=" + .metadata.namespace' /tmp/grafana-postgres-with-secret.yaml
if grep -E 'admin-password:|admin-user:|password:' argocd/homelab/grafana-postgres/grafana-admin-secret.yaml; then
  echo "unexpected plaintext-looking Secret data" >&2
  exit 1
fi
```

Expected output includes:

```text
grafana-admin namespace=monitoring
```

The grep check must not print plaintext-looking Secret data.

- [ ] **Step 4: Commit the sealed admin Secret**

Run:

```bash
git add argocd/homelab/grafana-postgres/kustomization.yaml argocd/homelab/grafana-postgres/grafana-admin-secret.yaml
git commit -m "feat(grafana): seal admin credentials"
```

Expected: one commit containing only the SealedSecret and Kustomization update.

---

### Task 3: Wire the new app into root and switch Grafana Helm values to Postgres

**Files:**
- Modify: `argocd/homelab/apps/kustomization.yaml`
- Modify: `argocd/base/kube-prometheus-stack/app.yaml`

- [ ] **Step 1: Add `grafana-postgres` to the root app-of-apps**

In `argocd/homelab/apps/kustomization.yaml`, insert `../../base/grafana-postgres` before `../../base/kube-prometheus-stack`:

```yaml
  - ../../base/jellyfin
  - ../../base/grafana-postgres
  - ../../base/kube-prometheus-stack
  - ../../base/grafana-dashboards
```

- [ ] **Step 2: Add the Grafana admin Secret setting**

In `argocd/base/kube-prometheus-stack/app.yaml`, under `valuesObject.grafana`, add this block before `deploymentStrategy`:

```yaml
          admin:
            existingSecret: grafana-admin
            userKey: admin-user
            passwordKey: admin-password
```

The top of the Grafana values should become:

```yaml
        grafana:
          admin:
            existingSecret: grafana-admin
            userKey: admin-user
            passwordKey: admin-password
          deploymentStrategy:
            type: RollingUpdate
            rollingUpdate:
              maxSurge: 0
              maxUnavailable: 1
```

- [ ] **Step 3: Disable the SQLite PVC**

In `argocd/base/kube-prometheus-stack/app.yaml`, replace the existing Grafana persistence block:

```yaml
          persistence:
            type: pvc
            enabled: true
            accessModes:
              - ReadWriteMany
            storageClassName: longhorn
            size: 10Gi
```

with:

```yaml
          persistence:
            enabled: false
```

- [ ] **Step 4: Remove SQLite WAL config and add Postgres env vars**

In `argocd/base/kube-prometheus-stack/app.yaml`, replace this block:

```yaml
          grafana.ini:
            server:
              domain: grafana.compaan
              root_url: https://%(domain)s
            database:
              wal: true
```

with:

```yaml
          grafana.ini:
            server:
              domain: grafana.compaan
              root_url: https://%(domain)s
          env:
            GF_DATABASE_TYPE: postgres
            GF_DATABASE_HOST: grafana-postgres-rw.monitoring.svc.cluster.local:5432
            GF_DATABASE_NAME: grafana
            GF_DATABASE_USER: grafana
            GF_DATABASE_SSL_MODE: disable
          envValueFrom:
            GF_DATABASE_PASSWORD:
              secretKeyRef:
                name: grafana-postgres-app
                key: password
```

- [ ] **Step 5: Verify root Kustomize build**

Run:

```bash
kubectl kustomize argocd/homelab/apps >/tmp/homelab-apps.yaml
yq -r 'select(.kind == "Application") | .metadata.name + " wave=" + (.metadata.annotations["argocd.argoproj.io/sync-wave"] // "")' /tmp/homelab-apps.yaml | grep -E 'grafana-postgres|kube-prometheus-stack|grafana-dashboards'
```

Expected output includes:

```text
grafana-postgres wave=2
kube-prometheus-stack wave=3
grafana-dashboards wave=4
```

- [ ] **Step 6: Verify Helm renders Postgres env vars and no Grafana PVC**

Run:

```bash
set -euo pipefail
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
yq -y '.spec.source.helm.valuesObject' argocd/base/kube-prometheus-stack/app.yaml > "$tmpdir/values.yaml"
helm template kube-prometheus-stack kube-prometheus-stack \
  --repo https://prometheus-community.github.io/helm-charts \
  --version 79.12.0 \
  -f "$tmpdir/values.yaml" \
  > "$tmpdir/rendered.yaml"

echo '## Grafana database/admin env'
yq -r 'select(.kind == "Deployment" and .metadata.name == "kube-prometheus-stack-grafana") | .spec.template.spec.containers[] | select(.name == "grafana") | .env[]? | select(.name|test("GF_DATABASE_|GF_SECURITY_ADMIN"))' "$tmpdir/rendered.yaml"

echo '## Grafana storage volume'
yq -r 'select(.kind == "Deployment" and .metadata.name == "kube-prometheus-stack-grafana") | .spec.template.spec.volumes[]? | select(.name == "storage")' "$tmpdir/rendered.yaml"

echo '## Grafana PVC resources'
if yq -r 'select(.kind == "PersistentVolumeClaim" and (.metadata.name|test("grafana"))) | .metadata.name' "$tmpdir/rendered.yaml" | grep .; then
  echo "unexpected Grafana PVC rendered" >&2
  exit 1
fi
```

Expected:

- `GF_DATABASE_TYPE` value is `postgres`.
- `GF_DATABASE_HOST` value is `grafana-postgres-rw.monitoring.svc.cluster.local:5432`.
- `GF_DATABASE_PASSWORD` uses Secret `grafana-postgres-app`, key `password`.
- `GF_SECURITY_ADMIN_USER` and `GF_SECURITY_ADMIN_PASSWORD` use Secret `grafana-admin`.
- The storage volume is `emptyDir: {}`.
- No Grafana PersistentVolumeClaim is rendered.

- [ ] **Step 7: Verify existing alert tests still pass**

Run:

```bash
python3 scripts/test-grafana-alerts.py
python3 scripts/test-grafana-matrix-webhook.py
python3 scripts/test-just-targets.py
```

Expected: all scripts print only `PASS ...` lines and exit `0`.

- [ ] **Step 8: Commit the root and Helm value changes**

Run:

```bash
git add argocd/homelab/apps/kustomization.yaml argocd/base/kube-prometheus-stack/app.yaml
git commit -m "feat(grafana): use postgres database"
```

Expected: one commit containing the root app reference and Grafana Helm value changes.

---

### Task 4: Push, sync, and verify the live migration

**Files:**
- No file changes. This task applies the committed GitOps changes through ArgoCD.

- [ ] **Step 1: Confirm the working tree is clean and push**

Run:

```bash
git status --short
git push
```

Expected:

- `git status --short` prints nothing.
- `git push` updates `main` on the remote.

- [ ] **Step 2: Log in to ArgoCD**

Run:

```bash
argocd login argocd.compaan \
  --username admin \
  --password "$(pass show private/login/argocd.compaan-login-admin | head -1)"
```

Expected: ArgoCD login succeeds. A gRPC-web warning is acceptable if commands still work.

- [ ] **Step 3: Sync root so the new child app exists**

Run:

```bash
argocd app sync root --timeout 180
kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n argocd get application grafana-postgres -o json \
  | jq -r '.metadata.name + " sync=" + (.status.sync.status // "") + " health=" + (.status.health.status // "")'
```

Expected output includes:

```text
grafana-postgres sync=
```

The app may not be synced yet; this step only proves the root app registered it.

- [ ] **Step 4: Sync and wait for the Postgres cluster**

Run:

```bash
argocd app sync grafana-postgres --timeout 300
for i in $(seq 1 60); do
  status="$(kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n monitoring get cluster grafana-postgres -o json 2>/dev/null | jq -r '.status.phase // ""')"
  ready="$(kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n monitoring get cluster grafana-postgres -o json 2>/dev/null | jq -r '.status.readyInstances // 0')"
  echo "grafana-postgres phase=$status readyInstances=$ready"
  if [[ "$status" == "Cluster in healthy state" || "$ready" == "3" ]]; then
    break
  fi
  sleep 10
done
kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n monitoring get cluster grafana-postgres
kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n monitoring get secret grafana-postgres-app grafana-admin
```

Expected:

- CNPG reports 3 ready instances or a healthy phase.
- Secrets `grafana-postgres-app` and `grafana-admin` exist.

- [ ] **Step 5: Sync kube-prometheus-stack with prune**

Run:

```bash
argocd app sync kube-prometheus-stack --prune --timeout 420
kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n monitoring rollout status deploy/kube-prometheus-stack-grafana --timeout=300s
```

Expected:

- ArgoCD sync succeeds.
- Grafana deployment rollout succeeds.
- The old Grafana SQLite PVC may be deleted by prune; this is acceptable because SQLite data is intentionally not preserved.

- [ ] **Step 6: Sync dashboard and alert provisioning**

Run:

```bash
argocd app sync grafana-dashboards --timeout 180
just grafana-alerts-reload
```

Expected:

- `grafana-dashboards` sync succeeds.
- `just grafana-alerts-reload` returns a successful reload response from Grafana.

- [ ] **Step 7: Verify Kubernetes readiness and endpoints**

Run:

```bash
kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n monitoring get deploy kube-prometheus-stack-grafana -o json \
  | jq -r '{replicas:.spec.replicas, ready:.status.readyReplicas, available:.status.availableReplicas, updated:.status.updatedReplicas}'
kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n monitoring get pod -l app.kubernetes.io/name=grafana -o wide
kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n monitoring get endpoints kube-prometheus-stack-grafana -o wide
```

Expected:

- Deployment has `ready: 1`, `available: 1`, `updated: 1`.
- Grafana pod is `4/4 Running`.
- Service endpoint includes one `:3000` backend.

- [ ] **Step 8: Verify Grafana is using Postgres and is externally responsive**

Run:

```bash
pod="$(kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n monitoring get pod -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}')"
kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n monitoring exec "$pod" -c grafana -- sh -c 'env | grep ^GF_DATABASE_ | sort'
curl --connect-timeout 5 --max-time 20 -skS https://grafana.compaan/api/health
curl --connect-timeout 5 --max-time 20 -skS -o /tmp/grafana-login.html -w '%{http_code} total=%{time_total} size=%{size_download}\n' https://grafana.compaan/login
```

Expected:

- `GF_DATABASE_TYPE=postgres` appears.
- `GF_DATABASE_HOST=grafana-postgres-rw.monitoring.svc.cluster.local:5432` appears.
- `GF_DATABASE_PASSWORD` is present but do not print or copy its value beyond the env listing command output.
- `/api/health` returns JSON with `"database": "ok"`.
- `/login` returns HTTP `200`.

- [ ] **Step 9: Verify there are no fresh SQLite corruption or lock symptoms**

Run:

```bash
pod="$(kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n monitoring get pod -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}')"
kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n monitoring logs "$pod" -c grafana --since=10m --tail=1500 2>&1 \
  | grep -Ei 'database disk image is malformed|database is locked|sqlite|context deadline|panic|fatal' \
  | tail -80 || true
```

Expected:

- No `database disk image is malformed` lines.
- No SQLite lock loop lines.
- No `panic` or `fatal` lines.
- If `context deadline` appears, inspect the line; it must not be caused by SQLite/database corruption.

- [ ] **Step 10: Verify ArgoCD final status**

Run:

```bash
for app in root grafana-postgres kube-prometheus-stack grafana-dashboards; do
  kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n argocd get application "$app" -o json \
    | jq -r --arg app "$app" '$app + ": sync=" + (.status.sync.status // "") + " health=" + (.status.health.status // "") + " op=" + (.status.operationState.phase // "none")'
done
```

Expected output:

```text
root: sync=Synced health=Healthy op=Succeeded
grafana-postgres: sync=Synced health=Healthy op=Succeeded
kube-prometheus-stack: sync=Synced health=Healthy op=Succeeded
grafana-dashboards: sync=Synced health=Healthy op=Succeeded
```

If any app is `Progressing`, wait and rerun the command before declaring completion.

- [ ] **Step 11: Report the result**

Report:

- Commit hashes pushed.
- CNPG cluster readiness.
- Grafana pod readiness and endpoint.
- `/api/health` result.
- ArgoCD statuses.
- Whether any fresh DB error lines appeared.

Do not claim the migration is complete until the verification commands above have been run and their outputs match the expected results.
