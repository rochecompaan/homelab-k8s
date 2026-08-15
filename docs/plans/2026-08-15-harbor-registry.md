# Harbor Container Registry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy Harbor as the homelab container registry at `https://harbor.compaan` (private), wired to CloudNativePG, redis-ha, and Longhorn, delivered entirely through GitOps.

**Architecture:** Three ArgoCD apps in namespace `harbor`: `container-registry` (umbrella, wave 3) deploys supporting resources from `argocd/homelab/harbor/`; `redis-harbor` (wave 3) unchanged; `harbor` (wave 4) runs the Harbor Helm chart 1.18.0 with corrected, GitOps-stable values. Traefik (`traefik-private`) terminates TLS with a `compaan-ca` certificate.

**Tech Stack:** ArgoCD Application CRs, Kustomize, Harbor Helm chart 1.18.0, CloudNativePG, Bitnami SealedSecrets (kubeseal), Traefik ingress.

## Global Constraints

- **GitOps only:** never run `kubectl apply/patch/delete` or `helm upgrade` against the cluster. Read-only cluster access (`kubeseal` cert fetch) is allowed. All changes land via git.
- Work in the worktree `/home/roche/homelab-k8s/.worktrees/harbor-registry` on branch `feat/harbor-registry`.
- Conventional Commits; never bypass commit signing or hooks.
- Exact values: host `harbor.compaan`, ingress class `traefik-private`, issuer `compaan-ca`, storage class `longhorn`, namespace `harbor`, chart `harbor` v1.18.0 from `https://helm.goharbor.io`.
- Static configuration: no new automated tests (repo Testing Value Gate). Verification is render-based: `kubectl kustomize` / `helm template`.
- Spec: `docs/specs/2026-08-15-harbor-registry-design.md` (same worktree).

## Notes on spec refinements (validated by `helm template` during planning)

- SealedSecret is named `harbor-secrets` (not `harbor-admin`) and carries 8 keys. Harbor's chart generates several secrets randomly per render by default (`core.secret`, `jobservice.secret`, registry htpasswd, XSRF key, and the insecure default `secretKey: "not-a-secure-key"`). Pinning them in one sealed secret keeps ArgoCD renders stable (no perpetual OutOfSync) and replaces the insecure default.
- Ingress backend is Service `harbor` port 80 (the chart's nginx gateway that routes UI + `/api/` + `/v2/`), not `harbor-portal`.
- `updateStrategy.type: Recreate` is required: the chart default `RollingUpdate` deadlocks with RWO Longhorn volumes.

---

### Task 1: Harbor support overlay

**Files:**
- Create: `argocd/homelab/harbor/kustomization.yaml`
- Create: `argocd/homelab/harbor/harbor-cluster.yaml`
- Create: `argocd/homelab/harbor/harbor-registry-pvc.yaml`
- Create: `argocd/homelab/harbor/harbor-ingress.yaml`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: CNPG `Cluster/harbor` → Service `harbor-rw` + generated Secret `harbor-app` (key `password`); PVC `harbor-registry`; Ingress for `harbor.compaan` → Service `harbor:80`, TLS secret `harbor-compaan-tls`. Tasks 3–5 rely on these names.

- [ ] **Step 1: Create `argocd/homelab/harbor/harbor-cluster.yaml`**

Resources omit `metadata.namespace` on purpose; ArgoCD applies the app's destination namespace (`harbor`), matching the `nextcloud-db` pattern.

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: harbor
spec:
  instances: 1
  storage:
    size: 5Gi
    storageClass: longhorn
  bootstrap:
    initdb:
      database: harbor
      owner: harbor
```

- [ ] **Step 2: Create `argocd/homelab/harbor/harbor-registry-pvc.yaml`**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: harbor-registry
spec:
  storageClassName: longhorn
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
```

- [ ] **Step 3: Create `argocd/homelab/harbor/harbor-ingress.yaml`**

Backend is Service `harbor` (the chart's nginx gateway), port 80 — verified via `helm template`.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: harbor
  annotations:
    cert-manager.io/cluster-issuer: compaan-ca
spec:
  ingressClassName: traefik-private
  tls:
    - hosts:
        - harbor.compaan
      secretName: harbor-compaan-tls
  rules:
    - host: harbor.compaan
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: harbor
                port:
                  number: 80
```

- [ ] **Step 4: Create `argocd/homelab/harbor/kustomization.yaml`**

`harbor-secrets.yaml` is added to this list in Task 2.

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
resources:
  - harbor-cluster.yaml
  - harbor-registry-pvc.yaml
  - harbor-ingress.yaml
kind: Kustomization
```

- [ ] **Step 5: Verify render**

Run: `kubectl kustomize argocd/homelab/harbor`
Expected: renders 3 documents — `Cluster/harbor`, `PersistentVolumeClaim/harbor-registry`, `Ingress/harbor` — with no errors.

- [ ] **Step 6: Commit**

```bash
git add argocd/homelab/harbor
git commit -m "feat(harbor): add support overlay (cnpg cluster, registry pvc, ingress)"
```

---

### Task 2: Sealed `harbor-secrets` via Justfile recipe

**Files:**
- Modify: `Justfile` (add variable near the other `pass` entries, recipe near the other `seal-*` recipes)
- Create: `argocd/homelab/harbor/harbor-secrets.yaml` (generated by kubeseal)
- Modify: `argocd/homelab/harbor/kustomization.yaml` (add the generated file)

**Interfaces:**
- Consumes: overlay dir from Task 1; sealed-secrets controller `sealed-secrets-controller` in `kube-system` (kubeseal defaults); `pass` password store.
- Produces: SealedSecret `harbor-secrets` (namespace `harbor`) with encryptedData keys consumed by Task 3's Helm values: `HARBOR_ADMIN_PASSWORD`, `secretKey` (exactly 16 chars), `secret`, `CSRF_KEY` (32 chars), `JOBSERVICE_SECRET`, `REGISTRY_HTTP_SECRET`, `REGISTRY_PASSWD`, `REGISTRY_HTPASSWD`.

- [ ] **Step 1: Ensure the admin password exists in `pass`**

```bash
pass show private/login/harbor.compaan-admin >/dev/null 2>&1 \
  || pass generate -n private/login/harbor.compaan-admin 32
```

Expected: entry exists (`-n` = alphanumeric only, avoids shell/URL quoting issues).

- [ ] **Step 2: Add the variable to `Justfile`**

Next to the other entry variables (after the `forgejo_smtp_password_entry` line region, alphabetical-ish with existing vars):

```just
harbor_admin_password_entry := "private/login/harbor.compaan-admin"
```

- [ ] **Step 3: Add the recipe to `Justfile`**

Modeled on `seal-webmutt-secret`. One shell invocation via `\` continuations so `reg_pass` and `reg_htpasswd` stay consistent (the htpasswd line must hash the same password as `REGISTRY_PASSWD`). `@` suppresses echo.

```just
seal-harbor-secrets:
  @reg_pass="$$(openssl rand -hex 16)"; \
  reg_htpasswd="harbor_registry_user:$$(openssl passwd -apr1 "$$reg_pass")"; \
  kubectl create secret generic harbor-secrets \
    --namespace harbor \
    --from-literal=HARBOR_ADMIN_PASSWORD="$$(pass show {{harbor_admin_password_entry}} | head -n1 | tr -d '[:space:]')" \
    --from-literal=secretKey="$$(openssl rand -hex 8)" \
    --from-literal=secret="$$(openssl rand -hex 16)" \
    --from-literal=CSRF_KEY="$$(openssl rand -hex 16)" \
    --from-literal=JOBSERVICE_SECRET="$$(openssl rand -hex 16)" \
    --from-literal=REGISTRY_HTTP_SECRET="$$(openssl rand -hex 16)" \
    --from-literal=REGISTRY_PASSWD="$$reg_pass" \
    --from-literal=REGISTRY_HTPASSWD="$$reg_htpasswd" \
    --dry-run=client \
    -o yaml \
  | kubeseal --format=yaml \
  > argocd/homelab/harbor/harbor-secrets.yaml
```

- [ ] **Step 4: Run the recipe**

Run: `just seal-harbor-secrets`
Expected: `argocd/homelab/harbor/harbor-secrets.yaml` created; `kind: SealedSecret`, `metadata.name: harbor-secrets`, `metadata.namespace: harbor`. Requires read-only cluster access for kubeseal to fetch the controller cert.

- [ ] **Step 5: Verify all 8 keys are sealed**

Run: `yq '.spec.encryptedData | keys' argocd/homelab/harbor/harbor-secrets.yaml`
Expected: `CSRF_KEY`, `HARBOR_ADMIN_PASSWORD`, `JOBSERVICE_SECRET`, `REGISTRY_HTPASSWD`, `REGISTRY_HTTP_SECRET`, `REGISTRY_PASSWD`, `secret`, `secretKey` (order may differ).

- [ ] **Step 6: Register the file in the kustomization**

Edit `argocd/homelab/harbor/kustomization.yaml` so resources read:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
resources:
  - harbor-cluster.yaml
  - harbor-registry-pvc.yaml
  - harbor-ingress.yaml
  - harbor-secrets.yaml
kind: Kustomization
```

- [ ] **Step 7: Verify render still works**

Run: `kubectl kustomize argocd/homelab/harbor`
Expected: 4 documents, including `SealedSecret/harbor-secrets`, no errors.

- [ ] **Step 8: Commit**

```bash
git add Justfile argocd/homelab/harbor
git commit -m "feat(harbor): add sealed harbor-secrets (admin password + chart secrets)"
```

---

### Task 3: Fix Harbor Helm values

**Files:**
- Modify: `argocd/base/harbor/app.yaml` (replace `spec.source.helm.valuesObject`)

**Interfaces:**
- Consumes: `harbor-app` secret + `harbor-rw` service (Task 1); `harbor-registry` PVC (Task 1); `harbor-secrets` keys (Task 2); redis-ha announce services `harbor-redis-redis-ha-announce-{0,1}:26379` (existing `redis-harbor` app, unchanged).
- Produces: the final values block that Task 6 re-validates.

- [ ] **Step 1: Replace the `valuesObject` in `argocd/base/harbor/app.yaml`**

Keep `metadata`, `sync-wave: '4'`, `chart`, `repoURL`, `targetRevision`, `releaseName`, `destination`, and `syncPolicy` exactly as they are. Replace only the `helm.valuesObject` mapping with:

```yaml
        externalURL: https://harbor.compaan
        expose:
          type: clusterIP
          tls:
            enabled: false
          ingress: {}
        portal:
          replicas: 1
        core:
          replicas: 1
          existingSecret: harbor-secrets
          existingXsrfSecret: harbor-secrets
          existingXsrfSecretKey: CSRF_KEY
        jobservice:
          replicas: 1
          existingSecret: harbor-secrets
          existingSecretKey: JOBSERVICE_SECRET
        registry:
          replicas: 1
          existingSecret: harbor-secrets
          existingSecretKey: REGISTRY_HTTP_SECRET
          credentials:
            existingSecret: harbor-secrets
        trivy:
          enabled: true
          replicas: 1
        existingSecretAdminPassword: harbor-secrets
        existingSecretAdminPasswordKey: HARBOR_ADMIN_PASSWORD
        existingSecretSecretKey: harbor-secrets
        updateStrategy:
          type: Recreate
        persistence:
          enabled: true
          persistentVolumeClaim:
            registry:
              existingClaim: harbor-registry
            jobservice:
              jobLog:
                storageClass: longhorn
                size: 1Gi
            trivy:
              storageClass: longhorn
              size: 5Gi
        redis:
          type: external
          external:
            addr: harbor-redis-redis-ha-announce-0:26379,harbor-redis-redis-ha-announce-1:26379
            sentinelMasterSet: mymaster
            tlsOptions:
              enable: false
            coreDatabaseIndex: '0'
            jobserviceDatabaseIndex: '1'
            registryDatabaseIndex: '2'
            trivyAdapterIndex: '5'
            username: ''
            password: ''
            existingSecret: ''
        database:
          type: external
          external:
            host: harbor-rw
            port: '5432'
            username: harbor
            coreDatabase: harbor
            existingSecret: harbor-app
            sslmode: disable
        notary:
          enabled: false
```

This fixes the truncated `externalURL`, deletes the mangled `secret=[REDACTED] harbor-tls` line, drops TLS to traefik, pins all chart secrets against ArgoCD render churn, and sets `updateStrategy: Recreate` for the RWO volumes.

- [ ] **Step 2: Validate YAML and extract values**

Run: `yq '.spec.source.helm.valuesObject' argocd/base/harbor/app.yaml > /tmp/harbor-values-check.yaml && head -3 /tmp/harbor-values-check.yaml`
Expected: valid YAML, starts with `externalURL: https://harbor.compaan`.

- [ ] **Step 3: Render the chart with the exact values**

Run:
```bash
helm template harbor harbor --repo https://helm.goharbor.io --version 1.18.0 \
  --namespace harbor -f /tmp/harbor-values-check.yaml > /tmp/harbor-rendered.yaml
```
Expected: exits 0, no template errors.

- [ ] **Step 4: Assert key render properties**

Run:
```bash
grep -c 'kind: Ingress' /tmp/harbor-rendered.yaml
grep -A2 'name: harbor$' /tmp/harbor-rendered.yaml | head -5
grep 'storageClassName: longhorn' /tmp/harbor-rendered.yaml | wc -l
grep 'harbor-app' /tmp/harbor-rendered.yaml | head -2
```
Expected:
1. `0` Ingress documents (our overlay owns the Ingress).
2. A Service named `harbor` exists (nginx gateway, port 80).
3. At least 2 `storageClassName: longhorn` hits (jobservice PVC + trivy volumeClaimTemplate).
4. The core deployment references secret `harbor-app` key `password` (CNPG) — confirming DB wiring.

- [ ] **Step 5: Commit**

```bash
git add argocd/base/harbor/app.yaml
git commit -m "fix(harbor): correct helm values for private harbor.compaan deployment"
```

---

### Task 4: Fix umbrella app path

**Files:**
- Modify: `argocd/base/container-registry/app.yaml:19` (`spec.source.path`)

**Interfaces:**
- Consumes: `argocd/homelab/harbor/` overlay from Tasks 1–2 (the new path target).
- Produces: umbrella app that actually resolves.

- [ ] **Step 1: Fix the path**

In `argocd/base/container-registry/app.yaml`, change:

```yaml
    path: argocd/harbor
```

to:

```yaml
    path: argocd/homelab/harbor
```

Leave everything else (sync-wave `3`, destination namespace `harbor`, syncPolicy) unchanged.

- [ ] **Step 2: Verify the target exists and renders**

Run: `test -d argocd/homelab/harbor && kubectl kustomize argocd/homelab/harbor >/dev/null && echo OK`
Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add argocd/base/container-registry/app.yaml
git commit -m "fix(harbor): point container-registry umbrella app at homelab/harbor overlay"
```

---

### Task 5: Register the three apps

**Files:**
- Modify: `argocd/homelab/apps/kustomization.yaml`

**Interfaces:**
- Consumes: all three base apps (`container-registry`, `harbor`, `redis-harbor`).
- Produces: the bundle ArgoCD's root app deploys; Harbor stack becomes managed.

- [ ] **Step 1: Add the three resources**

In `argocd/homelab/apps/kustomization.yaml`, insert (following the list's rough alphabetical order):

- `  - ../../base/container-registry` immediately before `  - ../../base/coturn`
- `  - ../../base/harbor` immediately before `  - ../../base/local-path-provisioner`
- `  - ../../base/redis-harbor` immediately before `  - ../../base/reflector`

- [ ] **Step 2: Verify the bundle renders all three**

Run:
```bash
kubectl kustomize argocd/homelab/apps | yq '.metadata.name' | grep -E '^(container-registry|harbor|redis-harbor)$'
```
Expected: three lines — `container-registry`, `harbor`, `redis-harbor`.

- [ ] **Step 3: Commit**

```bash
git add argocd/homelab/apps/kustomization.yaml
git commit -m "feat(harbor): register container-registry, harbor and redis-harbor apps"
```

---

### Task 6: Final end-to-end verification

**Files:** none (verification only).

**Interfaces:**
- Consumes: everything from Tasks 1–5.

- [ ] **Step 1: Full bundle render**

Run: `kubectl kustomize argocd/homelab/apps >/dev/null && echo BUNDLE-OK`
Expected: `BUNDLE-OK` (entire root app still renders).

- [ ] **Step 2: Re-run the exact-values chart render**

Run:
```bash
yq '.spec.source.helm.valuesObject' argocd/base/harbor/app.yaml > /tmp/harbor-values-final.yaml
helm template harbor harbor --repo https://helm.goharbor.io --version 1.18.0 \
  --namespace harbor -f /tmp/harbor-values-final.yaml >/dev/null && echo HELM-OK
```
Expected: `HELM-OK`.

- [ ] **Step 3: Sanity-check git state**

Run: `git status --short && git log --oneline main..HEAD`
Expected: clean tree; commits for Tasks 1–5 listed.

- [ ] **Step 4: Hand off to GitOps**

Merge per the repo's branch-completion convention (offer squash merge into `main` locally), push, then let ArgoCD reconcile. Post-sync checks (reported back, not done via direct mutation):

- `argocd` shows `container-registry`, `redis-harbor`, `harbor` all Healthy/Synced.
- `curl -s -o /dev/null -w '%{http_code}' https://harbor.compaan` returns `200`.
- `docker login harbor.compaan` with `admin` + the `pass` entry, then a push/pull smoke test of a small image (e.g. `hello-world` re-tag).
