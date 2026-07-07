# Authentik SSO Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy Authentik as the self-hosted OIDC identity provider for the homelab and integrate ArgoCD as the first SSO client.

**Architecture:** Add a CloudNativePG-backed Authentik deployment managed by ArgoCD. Store Authentik configuration in a sealed secret, expose Authentik privately at `auth.compaan`, then configure ArgoCD to use Authentik OIDC with `homelab-admins` mapped to ArgoCD admin.

**Tech Stack:** ArgoCD Application CRs, Kustomize, official Authentik Helm chart `2026.5.3`, CloudNativePG, Traefik ingress, cert-manager `compaan-ca`, sealed-secrets, Justfile secret helpers.

## Global Constraints

- Make all homelab Kubernetes changes through this Git repo; do not run `kubectl apply`, `kubectl patch`, `kubectl delete`, or `helm upgrade` against the homelab cluster.
- Use `kubectl create secret --dry-run=client -o yaml | kubeseal` only to generate sealed secret manifests; that does not mutate the cluster.
- Do not commit plaintext secrets.
- Authentik is fully self-hosted with local users, groups, credentials, and MFA.
- OIDC only for phase 1; SAML is out of scope.
- Authentik hostname is `auth.compaan` and must remain private/Ziti-overlay only.
- ArgoCD is the only phase 1 SSO client.
- Keep ArgoCD local admin available during rollout.
- Use direct ArgoCD `oidc.config`, not ArgoCD bundled Dex.
- The current official Authentik chart `2026.5.3` has no Redis dependency or Redis values; do not add Redis unless the selected chart version changes and explicitly requires it.
- Do not add automated tests for static GitOps YAML; verify with render/dry-run commands and live ArgoCD/Auth flow checks.

---

## File Structure

Create or modify these files:

- `Justfile`
  - Add thin `seal-authentik-config-secret` and `seal-argocd-authentik-oidc-secret` recipes that call `scripts/seal-authentik-secrets.sh`.
- `scripts/seal-authentik-secrets.sh`
  - Contains fixed Authentik/ArgoCD secret names, namespaces, pass entries, output paths, bootstrap email, and kubeseal controller values.
  - Generates sealed secrets for Authentik config and the ArgoCD OIDC client secret.
- `argocd/base/authentik-db/app.yaml`
  - ArgoCD Application that applies Authentik prerequisites from this repo.
- `argocd/base/authentik-db/kustomization.yaml`
  - Includes the Authentik DB/prereq Application.
- `argocd/homelab/authentik-db/kustomization.yaml`
  - Includes the CloudNativePG cluster and sealed Authentik config secret.
- `argocd/homelab/authentik-db/postgres-cluster.yaml`
  - CloudNativePG cluster for the Authentik database.
- `argocd/homelab/authentik-db/authentik-config-secret.yaml`
  - Generated sealed secret; not handwritten.
- `argocd/base/authentik/app.yaml`
  - ArgoCD Application for the official Authentik Helm chart.
- `argocd/base/authentik/kustomization.yaml`
  - Includes the Authentik Application.
- `argocd/homelab/apps/kustomization.yaml`
  - Registers `authentik-db` and `authentik` in the root app bundle.
- `argocd/homelab/infra/kustomization.yaml`
  - Includes the ArgoCD OIDC client secret sealed manifest.
- `argocd/homelab/infra/argocd-authentik-oidc-secret.yaml`
  - Generated sealed secret containing the ArgoCD OIDC client secret from Authentik.
- `argocd/base/argocd/app.yaml`
  - Adds Authentik OIDC config and RBAC mapping.
- `docs/runbooks/authentik-sso.md`
  - Operator runbook for bootstrap, Authentik UI setup, ArgoCD OIDC setup, verification, and recovery.

---

### Task 1: Add Authentik database prerequisites and sealed config helper

**Files:**
- Modify: `Justfile`
- Create: `scripts/seal-authentik-secrets.sh`
- Create: `argocd/base/authentik-db/app.yaml`
- Create: `argocd/base/authentik-db/kustomization.yaml`
- Create: `argocd/homelab/authentik-db/kustomization.yaml`
- Create: `argocd/homelab/authentik-db/postgres-cluster.yaml`
- Generate: `argocd/homelab/authentik-db/authentik-config-secret.yaml`

**Interfaces:**
- Consumes: `kubectl`, `kubeseal`, `pass`, existing sealed-secrets controller `sealed-secrets-controller` in namespace `kube-system`, and existing CloudNativePG operator from `argocd/base/cloudnative-pg`.
- Produces: namespace `authentik`, CloudNativePG cluster `authentik-postgres`, generated CNPG app secret `authentik-postgres-app`, service `authentik-postgres-rw.authentik.svc.cluster.local`, and secret `authentik-config` containing only Authentik bootstrap/config values.

- [ ] **Step 1: Create `scripts/seal-authentik-secrets.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

sealed_secrets_controller_name="sealed-secrets-controller"
sealed_secrets_controller_namespace="kube-system"

authentik_namespace="authentik"
authentik_config_secret_name="authentik-config"
authentik_config_secret_path="argocd/homelab/authentik-db/authentik-config-secret.yaml"
authentik_secret_key_entry="private/login/auth.compaan-secret-key"
authentik_bootstrap_password_entry="private/login/auth.compaan-akadmin"
authentik_bootstrap_token_entry="private/login/auth.compaan-bootstrap-token"
authentik_bootstrap_email="akadmin@auth.compaan"

argocd_authentik_oidc_secret_name="argocd-authentik-oidc"
argocd_authentik_oidc_secret_path="argocd/homelab/infra/argocd-authentik-oidc-secret.yaml"
argocd_authentik_oidc_client_secret_entry="private/login/argocd.compaan-authentik-oidc"

tmpfile_to_cleanup=""

cleanup_tmpfile() {
  if [[ -n "$tmpfile_to_cleanup" ]]; then
    rm -f "$tmpfile_to_cleanup"
  fi
}
trap cleanup_tmpfile EXIT

usage() {
  printf 'Usage: %s {authentik-config|argocd-oidc}\n' "$(basename "$0")" >&2
}

read_pass_first_line() {
  local entry="$1"
  local label="$2"
  local value

  value="$(pass show "$entry" 2>/dev/null | head -n1 | tr -d '[:space:]' || true)"
  if [[ -z "$value" ]]; then
    printf 'Missing %s in pass entry %s\n' "$label" "$entry" >&2
    exit 1
  fi

  printf '%s' "$value"
}

seal_secret() {
  kubeseal \
    --kubeconfig "${KUBECONFIG:-./.kubeconfig}" \
    --controller-name "$sealed_secrets_controller_name" \
    --controller-namespace "$sealed_secrets_controller_namespace" \
    --format=yaml
}

seal_authentik_config() {
  local secret_key bootstrap_password bootstrap_token

  mkdir -p "$(dirname "$authentik_config_secret_path")"
  tmpfile_to_cleanup="$(mktemp)"

  secret_key="$(read_pass_first_line "$authentik_secret_key_entry" "Authentik secret key")"
  bootstrap_password="$(read_pass_first_line "$authentik_bootstrap_password_entry" "Authentik bootstrap password")"
  bootstrap_token="$(read_pass_first_line "$authentik_bootstrap_token_entry" "Authentik bootstrap token")"

  kubectl create secret generic "$authentik_config_secret_name" \
    --namespace "$authentik_namespace" \
    --from-literal=AUTHENTIK_SECRET_KEY="$secret_key" \
    --from-literal=AUTHENTIK_BOOTSTRAP_EMAIL="$authentik_bootstrap_email" \
    --from-literal=AUTHENTIK_BOOTSTRAP_PASSWORD="$bootstrap_password" \
    --from-literal=AUTHENTIK_BOOTSTRAP_TOKEN="$bootstrap_token" \
    --dry-run=client \
    -o yaml \
    | seal_secret \
    > "$tmpfile_to_cleanup"

  mv "$tmpfile_to_cleanup" "$authentik_config_secret_path"
  tmpfile_to_cleanup=""
}

seal_argocd_oidc() {
  local client_secret

  mkdir -p "$(dirname "$argocd_authentik_oidc_secret_path")"
  tmpfile_to_cleanup="$(mktemp)"

  client_secret="$(read_pass_first_line "$argocd_authentik_oidc_client_secret_entry" "ArgoCD Authentik OIDC client secret")"

  kubectl create secret generic "$argocd_authentik_oidc_secret_name" \
    --namespace argocd \
    --from-literal=clientSecret="$client_secret" \
    --dry-run=client \
    -o yaml \
    | seal_secret \
    > "$tmpfile_to_cleanup"

  mv "$tmpfile_to_cleanup" "$argocd_authentik_oidc_secret_path"
  tmpfile_to_cleanup=""
}

case "${1:-}" in
  authentik-config)
    seal_authentik_config
    ;;
  argocd-oidc)
    seal_argocd_oidc
    ;;
  *)
    usage
    exit 2
    ;;
esac
```

- [ ] **Step 2: Make the sealing script executable**

Run:

```bash
chmod +x scripts/seal-authentik-secrets.sh
```

- [ ] **Step 3: Add thin sealing targets to `Justfile`**

Add these recipes near the other `seal-*` recipes:

```make
seal-authentik-config-secret:
  scripts/seal-authentik-secrets.sh authentik-config

seal-argocd-authentik-oidc-secret:
  scripts/seal-authentik-secrets.sh argocd-oidc
```

- [ ] **Step 4: Create pass entries for sealing**

Use existing pass entries if they already exist. Otherwise create them with these commands before running the sealing target:

```bash
pass generate private/login/auth.compaan-secret-key 64
pass generate private/login/auth.compaan-bootstrap-token 64
pass generate private/login/auth.compaan-akadmin 48
```

The generated `private/login/auth.compaan-akadmin` value is the initial `akadmin` password for first login at `https://auth.compaan`.

- [ ] **Step 5: Create `argocd/base/authentik-db/app.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: authentik-db
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: '1'
spec:
  project: default
  source:
    repoURL: git@github.com:rochecompaan/homelab-k8s.git
    targetRevision: main
    path: argocd/homelab/authentik-db
  destination:
    server: https://kubernetes.default.svc
    namespace: authentik
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
```

- [ ] **Step 6: Create `argocd/base/authentik-db/kustomization.yaml`**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
namespace: argocd
resources:
  - app.yaml
kind: Kustomization
```

- [ ] **Step 7: Create `argocd/homelab/authentik-db/postgres-cluster.yaml`**

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: authentik-postgres
spec:
  instances: 3
  storage:
    size: 10Gi
    storageClass: local-path
  bootstrap:
    initdb:
      database: authentik
      owner: authentik
```

- [ ] **Step 8: Create `argocd/homelab/authentik-db/kustomization.yaml`**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
resources:
  - authentik-config-secret.yaml
  - postgres-cluster.yaml
kind: Kustomization
```

- [ ] **Step 9: Generate the sealed Authentik config secret**

Run:

```bash
just seal-authentik-config-secret
```

Expected result:

```text
argocd/homelab/authentik-db/authentik-config-secret.yaml is created as a SealedSecret
```

- [ ] **Step 10: Verify prerequisite manifests render**

Run:

```bash
kubectl kustomize argocd/base/authentik-db >/tmp/authentik-db-app.yaml
kubectl kustomize argocd/homelab/authentik-db >/tmp/authentik-db-resources.yaml
grep -q 'kind: Application' /tmp/authentik-db-app.yaml
grep -q 'name: authentik-db' /tmp/authentik-db-app.yaml
grep -q 'kind: Cluster' /tmp/authentik-db-resources.yaml
grep -q 'name: authentik-postgres' /tmp/authentik-db-resources.yaml
grep -q 'kind: SealedSecret' /tmp/authentik-db-resources.yaml
```

Expected: all commands exit `0`.

- [ ] **Step 11: Commit prerequisites**

```bash
git add Justfile scripts/seal-authentik-secrets.sh argocd/base/authentik-db argocd/homelab/authentik-db
git commit -m "feat(sso): add Authentik database prerequisites"
```

---

### Task 2: Add the Authentik Helm Application

**Files:**
- Create: `argocd/base/authentik/app.yaml`
- Create: `argocd/base/authentik/kustomization.yaml`
- Modify: `argocd/homelab/apps/kustomization.yaml`

**Interfaces:**
- Consumes: secret `authentik-config`, generated CNPG app secret `authentik-postgres-app`, and service `authentik-postgres-rw.authentik.svc.cluster.local` from Task 1.
- Produces: Authentik server and worker deployments in namespace `authentik`, service `authentik-server`, and Traefik ingress for `auth.compaan`.

- [ ] **Step 1: Create `argocd/base/authentik/app.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: authentik
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: '2'
spec:
  project: default
  source:
    chart: authentik
    repoURL: https://charts.goauthentik.io
    targetRevision: 2026.5.3
    helm:
      releaseName: authentik
      valuesObject:
        global:
          env:
            - name: AUTHENTIK_POSTGRESQL__HOST
              value: authentik-postgres-rw.authentik.svc.cluster.local
            - name: AUTHENTIK_POSTGRESQL__NAME
              value: authentik
            - name: AUTHENTIK_POSTGRESQL__USER
              valueFrom:
                secretKeyRef:
                  name: authentik-postgres-app
                  key: username
            - name: AUTHENTIK_POSTGRESQL__PASSWORD
              valueFrom:
                secretKeyRef:
                  name: authentik-postgres-app
                  key: password
            - name: AUTHENTIK_POSTGRESQL__PORT
              value: "5432"
        authentik:
          existingSecret:
            secretName: authentik-config
        postgresql:
          enabled: false
        server:
          ingress:
            enabled: true
            annotations:
              cert-manager.io/cluster-issuer: compaan-ca
            ingressClassName: traefik
            hosts:
              - auth.compaan
            tls:
              - secretName: authentik-compaan-tls
                hosts:
                  - auth.compaan
  destination:
    server: https://kubernetes.default.svc
    namespace: authentik
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
```

- [ ] **Step 2: Create `argocd/base/authentik/kustomization.yaml`**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
namespace: argocd
resources:
  - app.yaml
kind: Kustomization
```

- [ ] **Step 3: Register Authentik apps in `argocd/homelab/apps/kustomization.yaml`**

Add the two resources after `../../base/cloudnative-pg` and before workload apps that may later consume SSO:

```yaml
  - ../../base/authentik-db
  - ../../base/authentik
```

The beginning of the file should look like this after the edit:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
namespace: argocd
resources:
  - ../../base/argocd
  - ../../base/cert-manager
  - ../../base/cloudnative-pg
  - ../../base/authentik-db
  - ../../base/authentik
  - ../../base/csi-snapshot-crds
```

- [ ] **Step 4: Verify the Authentik chart renders with the intended values**

Run:

```bash
cat >/tmp/authentik-values.yaml <<'YAML'
global:
  env:
    - name: AUTHENTIK_POSTGRESQL__HOST
      value: authentik-postgres-rw.authentik.svc.cluster.local
    - name: AUTHENTIK_POSTGRESQL__NAME
      value: authentik
    - name: AUTHENTIK_POSTGRESQL__USER
      valueFrom:
        secretKeyRef:
          name: authentik-postgres-app
          key: username
    - name: AUTHENTIK_POSTGRESQL__PASSWORD
      valueFrom:
        secretKeyRef:
          name: authentik-postgres-app
          key: password
    - name: AUTHENTIK_POSTGRESQL__PORT
      value: "5432"
authentik:
  existingSecret:
    secretName: authentik-config
postgresql:
  enabled: false
server:
  ingress:
    enabled: true
    ingressClassName: traefik
    hosts:
      - auth.compaan
    tls:
      - secretName: authentik-compaan-tls
        hosts:
          - auth.compaan
YAML
helm template authentik authentik \
  --repo https://charts.goauthentik.io \
  --version 2026.5.3 \
  --namespace authentik \
  -f /tmp/authentik-values.yaml \
  >/tmp/authentik-render.yaml
grep -q 'name: authentik-server' /tmp/authentik-render.yaml
grep -q 'name: authentik-worker' /tmp/authentik-render.yaml
grep -q 'name: authentik-config' /tmp/authentik-render.yaml
grep -q 'name: authentik-postgres-app' /tmp/authentik-render.yaml
grep -q 'host: "auth.compaan"' /tmp/authentik-render.yaml
```

Expected: all commands exit `0`.

- [ ] **Step 5: Verify root app registration renders**

Run:

```bash
kubectl kustomize argocd/base/authentik >/tmp/authentik-app.yaml
kubectl kustomize argocd/homelab/apps >/tmp/root-apps.yaml
grep -q 'name: authentik' /tmp/authentik-app.yaml
grep -q '../../base/authentik-db' argocd/homelab/apps/kustomization.yaml
grep -q '../../base/authentik' argocd/homelab/apps/kustomization.yaml
```

Expected: all commands exit `0`.

- [ ] **Step 6: Commit Authentik app registration**

```bash
git add argocd/base/authentik argocd/homelab/apps/kustomization.yaml
git commit -m "feat(sso): add Authentik application"
```

---

### Task 3: Add the Authentik and ArgoCD SSO runbook

**Files:**
- Create: `docs/runbooks/authentik-sso.md`

**Interfaces:**
- Consumes: `auth.compaan`, Authentik bootstrap credentials from Task 1, and the future ArgoCD OIDC settings from Task 4.
- Produces: operator instructions for first login, YubiKey/WebAuthn enrollment, ArgoCD OIDC provider setup, rollout checks, and recovery.

- [ ] **Step 1: Create `docs/runbooks/authentik-sso.md`**

```markdown
# Authentik SSO Runbook

## Scope

Authentik is the private homelab identity provider at `https://auth.compaan`. Phase 1 integrates ArgoCD only. Authentik is reachable over the Ziti overlay and is not intended for public internet exposure.

## Initial Access

1. Connect to the Ziti overlay that exposes `auth.compaan`.
2. Open `https://auth.compaan`.
3. Sign in as `akadmin` using the password stored in `private/login/auth.compaan-akadmin`.
4. Confirm the Authentik admin interface loads.

## Required Authentik Objects

Create these objects in Authentik for phase 1:

- Group: `homelab-admins`
- Group: `homelab-users`
- User: the primary homelab admin user
- OIDC provider/application for ArgoCD

## YubiKey/WebAuthn Enrollment

1. In Authentik, open the primary admin user's MFA/authenticator settings.
2. Enroll a YubiKey or passkey using WebAuthn.
3. Test a logout/login cycle before changing ArgoCD.
4. Keep a recovery method available until at least two successful ArgoCD SSO logins have been verified.

## ArgoCD OIDC Provider Settings

Create an Authentik OAuth2/OpenID provider and application with these values:

- Provider type: OAuth2/OpenID
- Provider/application name: `ArgoCD`
- Slug: `argocd`
- Client type: Confidential
- Client ID: `argocd`
- Redirect URI: `https://argocd.compaan/auth/callback`
- Signing key: Authentik default signing key
- Scopes: `openid`, `profile`, `email`, `groups`
- Subject mode: Authentik default unless a later app requires a different subject claim

Use the pre-generated client secret stored in `private/login/argocd.compaan-authentik-oidc` as the Authentik provider client secret. If the provider secret is rotated in Authentik, update the pass entry and regenerate the sealed ArgoCD OIDC secret:

```bash
pass generate -i private/login/argocd.compaan-authentik-oidc 64
just seal-argocd-authentik-oidc-secret
```

## ArgoCD RBAC Mapping

ArgoCD maps Authentik group `homelab-admins` to `role:admin` using `configs.rbac.policy.csv` in `argocd/base/argocd/app.yaml`.

Users not in `homelab-admins` should either have no ArgoCD access or only the default permissions explicitly configured in ArgoCD. Phase 1 uses an empty default policy.

## Verification Checklist

Run these checks after ArgoCD syncs the Authentik and ArgoCD changes:

```bash
kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n authentik get pods
kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n authentik get ingress authentik-server
kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n authentik get cluster authentik-postgres
curl -kI https://auth.compaan
```

Expected outcomes:

- Authentik server and worker pods are ready.
- CloudNativePG reports the `authentik-postgres` cluster.
- The `authentik-server` ingress lists `auth.compaan`.
- `curl -kI https://auth.compaan` returns an HTTP response from Authentik while connected to Ziti.
- ArgoCD local admin login still works.
- ArgoCD SSO login works for a user in `homelab-admins`.
- A user outside `homelab-admins` does not receive admin privileges.

## Recovery

If Authentik is unavailable, use the ArgoCD local admin account to inspect and roll back GitOps changes.

If ArgoCD SSO is broken but local admin works:

1. Sign in to ArgoCD with the local admin account.
2. Check `argocd/base/argocd/app.yaml` for `configs.cm.oidc.config` and `configs.rbac` changes.
3. Revert the Git commit that introduced the broken OIDC config.
4. Let ArgoCD reconcile from Git.

If Authentik database recovery is needed, restore the CloudNativePG data for `authentik-postgres` before adding more OIDC clients beyond ArgoCD.
```

- [ ] **Step 2: Verify the runbook has no placeholders**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
text = Path('docs/runbooks/authentik-sso.md').read_text()
terms = ['T' + 'BD', 'TO' + 'DO', 'FIX' + 'ME', '?' * 3]
for term in terms:
    if term.lower() in text.lower():
        raise SystemExit(f'placeholder found: {term}')
print('runbook placeholder scan passed')
PY
```

Expected output:

```text
runbook placeholder scan passed
```

- [ ] **Step 3: Commit the runbook**

```bash
git add docs/runbooks/authentik-sso.md
git commit -m "docs(sso): add Authentik runbook"
```

---

### Task 4: Add ArgoCD OIDC secret helper, secret manifest, OIDC config, and RBAC

**Files:**
- Modify: `argocd/homelab/infra/kustomization.yaml`
- Generate: `argocd/homelab/infra/argocd-authentik-oidc-secret.yaml`
- Modify: `argocd/base/argocd/app.yaml`

**Interfaces:**
- Consumes: planned Authentik OIDC provider with slug `argocd`, issuer `https://auth.compaan/application/o/argocd/`, client ID `argocd`, and pre-generated client secret stored in `private/login/argocd.compaan-authentik-oidc`.
- Produces: Kubernetes secret `argocd-authentik-oidc` in namespace `argocd`, ArgoCD `oidc.config`, and RBAC group mapping `homelab-admins -> role:admin`.

- [ ] **Step 1: Confirm the ArgoCD OIDC sealing wrapper is available**

Run:

```bash
grep -q '^seal-argocd-authentik-oidc-secret:' Justfile
grep -q 'scripts/seal-authentik-secrets.sh argocd-oidc' Justfile
grep -q 'argocd_authentik_oidc_secret_path="argocd/homelab/infra/argocd-authentik-oidc-secret.yaml"' scripts/seal-authentik-secrets.sh
grep -q 'argocd-oidc)' scripts/seal-authentik-secrets.sh
```

Expected: all commands exit `0`. The Justfile must only call the external script; do not add inline secret-generation shell to the Justfile.

- [ ] **Step 2: Generate the ArgoCD OIDC client sealed secret**

After generating `private/login/argocd.compaan-authentik-oidc` with `pass generate`, run:

```bash
just seal-argocd-authentik-oidc-secret
```

Expected result:

```text
argocd/homelab/infra/argocd-authentik-oidc-secret.yaml is created as a SealedSecret
```

- [ ] **Step 3: Include the OIDC sealed secret in `argocd/homelab/infra/kustomization.yaml`**

Add this resource near the other secret resources:

```yaml
  - argocd-authentik-oidc-secret.yaml
```

The top of the resource list should include this entry:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
resources:
  - matrix-namespace.yaml
  - openclaw-secret.yaml
  - matrix-postgresql-secret.yaml
  - matrix-secret.yaml
  - matrix-whatsapp-secret.yaml
  - argocd-authentik-oidc-secret.yaml
  - cert-manager-issuer.yaml
```

- [ ] **Step 4: Add OIDC and RBAC values to `argocd/base/argocd/app.yaml`**

In `spec.source.helm.valuesObject.configs.cm`, add `url` and `oidc.config`. Keep the existing `kustomize.buildOptions` and `resource.customizations` entries.

```yaml
        configs:
          cm:
            url: https://argocd.compaan
            oidc.config: |
              name: Authentik
              issuer: https://auth.compaan/application/o/argocd/
              clientID: argocd
              clientSecret: $argocd-authentik-oidc:clientSecret
              requestedScopes:
                - openid
                - profile
                - email
                - groups
            kustomize.buildOptions: --enable-helm
            resource.customizations: |
              networking.k8s.io/Ingress:
                health.lua: |
                  hs = {}
                  hs.status = "Healthy"
                  hs.message = "Skip health check for Ingress"
                  return hs
```

In `spec.source.helm.valuesObject.configs`, add `rbac` alongside `cm` and `params`:

```yaml
          rbac:
            policy.default: ""
            policy.csv: |
              g, homelab-admins, role:admin
            scopes: "[groups]"
```

The resulting `configs` section should contain `cm`, `params`, and `rbac`.

- [ ] **Step 5: Verify ArgoCD config references the sealed secret and group mapping**

Run:

```bash
grep -q 'issuer: https://auth.compaan/application/o/argocd/' argocd/base/argocd/app.yaml
grep -q 'clientSecret: $argocd-authentik-oidc:clientSecret' argocd/base/argocd/app.yaml
grep -q 'g, homelab-admins, role:admin' argocd/base/argocd/app.yaml
kubectl kustomize argocd/homelab/infra >/tmp/infra-render.yaml
grep -q 'name: argocd-authentik-oidc' /tmp/infra-render.yaml
grep -q 'namespace: argocd' /tmp/infra-render.yaml
```

Expected: all commands exit `0`.

- [ ] **Step 6: Commit ArgoCD SSO config**

```bash
git add argocd/homelab/infra/kustomization.yaml argocd/homelab/infra/argocd-authentik-oidc-secret.yaml argocd/base/argocd/app.yaml
git commit -m "feat(sso): configure ArgoCD Authentik OIDC"
```

---

### Task 5: Roll out through ArgoCD and verify login/recovery

**Files:**
- No repo files unless verification reveals a defect in earlier tasks.

**Interfaces:**
- Consumes: committed GitOps changes from Tasks 1-4.
- Produces: verified Authentik deployment, verified ArgoCD local admin fallback, and verified ArgoCD SSO login for `homelab-admins`.

- [ ] **Step 1: Push the implementation branch after all commits are present**

Run from the implementation worktree:

```bash
git status --short
git log --oneline -5
```

Expected:

```text
git status --short prints no tracked or untracked implementation changes
git log --oneline -5 includes the Authentik prerequisite, app, runbook, and ArgoCD OIDC commits
```

Then push with the normal signed-commit-preserving workflow:

```bash
git push -u origin HEAD
```

- [ ] **Step 2: Let ArgoCD reconcile from Git**

Use ArgoCD rather than direct `kubectl apply`:

```bash
just argocd-sync root
```

Expected: ArgoCD starts reconciling the root app from Git.

- [ ] **Step 3: Verify Authentik DB prerequisites**

Run:

```bash
kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n authentik get sealedsecret authentik-config
kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n authentik get secret authentik-config
kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n authentik get cluster authentik-postgres
kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n authentik get pods -l cnpg.io/cluster=authentik-postgres
```

Expected:

```text
sealedsecret.bitnami.com/authentik-config is present
secret/authentik-config is present
cluster.postgresql.cnpg.io/authentik-postgres is present
three CloudNativePG pods for authentik-postgres become Running/Ready
```

- [ ] **Step 4: Verify Authentik runtime**

Run:

```bash
kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n authentik get pods
kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n authentik get svc authentik-server
kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n authentik get ingress authentik-server
curl -kI https://auth.compaan
```

Expected:

```text
authentik-server and authentik-worker pods become Running/Ready
service/authentik-server exposes ports 80 and 443 inside the cluster
ingress/authentik-server lists host auth.compaan
curl returns an HTTP response from Authentik while connected to Ziti
```

- [ ] **Step 5: Perform Authentik UI setup**

Use the runbook at `docs/runbooks/authentik-sso.md`:

1. Log into `https://auth.compaan` as `akadmin`.
2. Enroll YubiKey/WebAuthn for the primary admin user.
3. Create group `homelab-admins`.
4. Create group `homelab-users`.
5. Add the primary admin user to `homelab-admins`.
6. Create the ArgoCD OIDC provider/application with slug `argocd`, client ID `argocd`, redirect URI `https://argocd.compaan/auth/callback`, and the client secret stored in `private/login/argocd.compaan-authentik-oidc`.
7. Run `just seal-argocd-authentik-oidc-secret` again if the Authentik provider client secret was changed during UI setup.

Expected: Authentik has an ArgoCD OIDC provider whose issuer is `https://auth.compaan/application/o/argocd/`.

- [ ] **Step 6: Verify ArgoCD local admin fallback still works**

Run:

```bash
just argocd-login
argocd account get-user-info
```

Expected: the local ArgoCD admin login succeeds.

- [ ] **Step 7: Verify ArgoCD SSO in a browser**

Manual browser check:

1. Connect to Ziti.
2. Open `https://argocd.compaan`.
3. Click the Authentik/SSO login option.
4. Authenticate with the primary admin user and YubiKey/WebAuthn.
5. Confirm ArgoCD opens and shows administrative access.

Expected: the user in `homelab-admins` can administer ArgoCD.

- [ ] **Step 8: Verify non-admin behavior**

Manual browser check:

1. Create or use a user that is not a member of `homelab-admins`.
2. Sign out of ArgoCD.
3. Sign in through Authentik as that non-admin user.
4. Check ArgoCD access.

Expected: the user does not receive ArgoCD admin permissions.

- [ ] **Step 9: Verify recovery path**

Run:

```bash
just argocd-login
argocd app get argocd
argocd app get authentik
argocd app get authentik-db
```

Expected: local admin can inspect ArgoCD, Authentik, and Authentik DB apps even if SSO is not used.

- [ ] **Step 10: Record rollout result**

Append a short dated note to `docs/runbooks/authentik-sso.md` under a new `## Rollout Notes` heading:

```markdown
## Rollout Notes

- 2026-07-06: Authentik deployed at `auth.compaan`; ArgoCD local admin fallback verified; ArgoCD SSO verified for `homelab-admins`; non-admin user did not receive admin permissions.
```

Then commit the note:

```bash
git add docs/runbooks/authentik-sso.md
git commit -m "docs(sso): record Authentik rollout verification"
```
