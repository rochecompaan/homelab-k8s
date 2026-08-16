# Harbor Authentik OIDC Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable GitOps-managed Harbor browser login through Authentik without committing the OIDC client secret or removing local administrator recovery.

**Architecture:** Mount a declarative Authentik OAuth2 provider blueprint into the Authentik worker and provide its client secret through a namespace-bound SealedSecret. Supply Harbor's complete OIDC configuration through `CONFIG_OVERWRITE_JSON` from a second SealedSecret and inject the private `compaan-ca` through Harbor's supported CA bundle Secret.

**Tech Stack:** ArgoCD, Helm, Kustomize, Authentik blueprints, Harbor 2.14 OIDC, Sealed Secrets, OpenSSL, `jq`, `just`

## Global Constraints

- Make all Kubernetes changes in Git; do not run direct-write `kubectl` or Helm commands against the homelab cluster.
- Keep `https://harbor.compaan/account/sign-in` available for local Harbor administrator recovery.
- Use Authentik client ID `harbor`, application slug `harbor`, and redirect URI `https://harbor.compaan/c/oidc/callback`.
- Map Authentik group `homelab-admins` to Harbor system administrator privileges.
- Keep OIDC certificate verification enabled and trust the private `compaan-ca`.
- Never commit the OIDC client secret or plaintext `CONFIG_OVERWRITE_JSON` containing it.
- Static configuration does not need a new automated test; use direct chart, Kustomize, secret, and live verification.

---

### Task 1: Declare the Authentik Harbor provider

**Files:**
- Modify: `Justfile`
- Modify: `argocd/base/authentik/app.yaml`
- Create: `argocd/homelab/infra/authentik-harbor-blueprint.yaml`
- Create: `argocd/homelab/infra/authentik-harbor-oidc-secret.yaml`
- Modify: `argocd/homelab/infra/kustomization.yaml`

**Interfaces:**
- Consumes: password-store entry `private/login/harbor.compaan-authentik-oidc`.
- Produces: Authentik issuer `https://auth.compaan/application/o/harbor/`, client ID `harbor`, and a provider that reads `AUTHENTIK_HARBOR_CLIENT_SECRET`.

- [ ] **Step 1: Create the client secret in password-store**

Run only if the entry is absent:

```bash
pass generate private/login/harbor.compaan-authentik-oidc 64
```

Expected: the entry exists and its first line is non-empty. Do not print the value.

- [ ] **Step 2: Add the Authentik blueprint ConfigMap**

Create `argocd/homelab/infra/authentik-harbor-blueprint.yaml` with a `harbor.yaml` data key. Its blueprint must use these entries:

```yaml
version: 1
metadata:
  name: Harbor OIDC
entries:
  - model: authentik_providers_oauth2.oauth2provider
    id: harbor-provider
    identifiers:
      name: Harbor
    attrs:
      authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
      invalidation_flow: !Find [authentik_flows.flow, [slug, default-provider-invalidation-flow]]
      client_type: confidential
      client_id: harbor
      client_secret: !Env AUTHENTIK_HARBOR_CLIENT_SECRET
      redirect_uris:
        - matching_mode: strict
          url: https://harbor.compaan/c/oidc/callback
          redirect_uri_type: authorization
      grant_types:
        - authorization_code
        - refresh_token
      property_mappings:
        - !Find [authentik_providers_oauth2.scopemapping, [managed, goauthentik.io/providers/oauth2/scope-openid]]
        - !Find [authentik_providers_oauth2.scopemapping, [managed, goauthentik.io/providers/oauth2/scope-profile]]
        - !Find [authentik_providers_oauth2.scopemapping, [managed, goauthentik.io/providers/oauth2/scope-email]]
        - !Find [authentik_providers_oauth2.scopemapping, [managed, goauthentik.io/providers/oauth2/scope-offline_access]]
      signing_key: !Find [authentik_crypto.certificatekeypair, [name, authentik Self-signed Certificate]]
  - model: authentik_core.application
    identifiers:
      slug: harbor
    attrs:
      provider: !KeyOf harbor-provider
      name: Harbor
      meta_launch_url: https://harbor.compaan
```

Wrap this blueprint in a ConfigMap named `authentik-harbor-blueprint` in namespace `authentik`.

- [ ] **Step 3: Add atomic two-namespace secret sealing**

Add constants for client ID, password-store entry, and both output paths to `Justfile`. Add `seal-harbor-oidc`, which:

1. reads the secret's first line and rejects an empty value;
2. uses `jq -nc` to build Harbor's JSON without printing it;
3. creates `authentik-harbor-oidc` in namespace `authentik` with key `AUTHENTIK_HARBOR_CLIENT_SECRET` using `kubectl create secret --dry-run=client`;
4. creates `harbor-oidc` in namespace `harbor` with key `CONFIG_OVERWRITE_JSON` using `kubectl create secret --dry-run=client`;
5. seals both with the configured Sealed Secrets controller into temporary files;
6. atomically moves both files to their repository paths.

The JSON must contain:

```json
{
  "auth_mode": "oidc_auth",
  "primary_auth_mode": true,
  "oidc_name": "authentik",
  "oidc_endpoint": "https://auth.compaan/application/o/harbor/",
  "oidc_client_id": "harbor",
  "oidc_client_secret": "value from password-store",
  "oidc_groups_claim": "groups",
  "oidc_admin_group": "homelab-admins",
  "oidc_scope": "openid,profile,email,offline_access",
  "oidc_user_claim": "preferred_username",
  "oidc_verify_cert": true,
  "oidc_auto_onboard": true
}
```

- [ ] **Step 4: Mount the blueprint and client secret in Authentik**

In `argocd/base/authentik/app.yaml`, add:

```yaml
blueprints:
  configMaps:
    - authentik-harbor-blueprint
worker:
  podAnnotations:
    homelab.compaan.cloud/harbor-oidc-revision: "1"
  env:
    - name: AUTHENTIK_HARBOR_CLIENT_SECRET
      valueFrom:
        secretKeyRef:
          name: authentik-harbor-oidc
          key: AUTHENTIK_HARBOR_CLIENT_SECRET
```

Add both new infra resources to `argocd/homelab/infra/kustomization.yaml`.

- [ ] **Step 5: Render and inspect Authentik configuration**

Run:

```bash
yq -y '.spec.source.helm.valuesObject' argocd/base/authentik/app.yaml > /tmp/authentik-harbor-values.yaml
helm template authentik /tmp/authentik-chart/authentik -n authentik -f /tmp/authentik-harbor-values.yaml > /tmp/authentik-harbor-render.yaml
kubectl kustomize argocd/homelab/infra > /tmp/infra-harbor-oidc.yaml
```

Expected: the worker Deployment references `authentik-harbor-oidc`, mounts `authentik-harbor-blueprint`, and the infra render contains both resources.

- [ ] **Step 6: Commit the Authentik side**

```bash
git add Justfile argocd/base/authentik/app.yaml argocd/homelab/infra/authentik-harbor-blueprint.yaml argocd/homelab/infra/authentik-harbor-oidc-secret.yaml argocd/homelab/infra/kustomization.yaml
git commit -m "feat(authentik): add Harbor OIDC provider"
```

### Task 2: Configure Harbor OIDC and private CA trust

**Files:**
- Modify: `argocd/base/harbor/app.yaml`
- Create: `argocd/homelab/harbor/harbor-oidc.yaml`
- Create: `argocd/homelab/harbor/compaan-ca.crt`
- Modify: `argocd/homelab/harbor/kustomization.yaml`

**Interfaces:**
- Consumes: issuer and client from Task 1, plus the existing public `compaan-ca` certificate.
- Produces: Harbor core configured for OIDC with verified TLS and local DB recovery retained.

- [ ] **Step 1: Add the public private-CA certificate**

Extract the existing `compaan-ca` PEM block from `argocd/base/argocd/app.yaml` into `argocd/homelab/harbor/compaan-ca.crt`. The file must contain exactly one certificate and no private key.

- [ ] **Step 2: Generate the two SealedSecrets**

Run:

```bash
just seal-harbor-oidc
```

Expected: both output files exist, `kubeseal --validate` accepts them, and their encrypted keys are exactly `AUTHENTIK_HARBOR_CLIENT_SECRET` and `CONFIG_OVERWRITE_JSON` respectively.

- [ ] **Step 3: Wire Harbor values**

Set top-level:

```yaml
caBundleSecretName: harbor-ca-bundle
```

Under `core`, bump `homelab.compaan.cloud/secrets-revision` from `'5'` to `'6'` and add:

```yaml
extraEnvVars:
  - name: CONFIG_OVERWRITE_JSON
    valueFrom:
      secretKeyRef:
        name: harbor-oidc
        key: CONFIG_OVERWRITE_JSON
```

- [ ] **Step 4: Add Harbor resources and CA generator**

Add `harbor-oidc.yaml` to `argocd/homelab/harbor/kustomization.yaml`, then add:

```yaml
secretGenerator:
  - name: harbor-ca-bundle
    files:
      - ca.crt=compaan-ca.crt
generatorOptions:
  disableNameSuffixHash: true
```

- [ ] **Step 5: Verify deterministic Harbor and Kustomize renders**

Render the Harbor chart twice from `argocd/base/harbor/app.yaml` and compare the complete outputs with `cmp`. Verify:

- `CONFIG_OVERWRITE_JSON` comes from `harbor-oidc`;
- `harbor-ca-bundle` is mounted into Harbor core;
- the token key still comes from `harbor-token`;
- the two core checksum annotations match;
- `kubectl kustomize argocd/homelab/harbor` contains `harbor-oidc`, `harbor-token`, and `harbor-ca-bundle`;
- `kubectl kustomize argocd/homelab/apps` succeeds.

- [ ] **Step 6: Commit the Harbor side**

```bash
git add argocd/base/harbor/app.yaml argocd/homelab/harbor/harbor-oidc.yaml argocd/homelab/harbor/compaan-ca.crt argocd/homelab/harbor/kustomization.yaml
git commit -m "feat(harbor): enable Authentik OIDC"
```

### Task 3: Document, review, and integrate

**Files:**
- Modify: `docs/runbooks/authentik-sso.md`
- Create: `docs/specs/2026-08-16-harbor-authentik-oidc-design.md`
- Create: `docs/plans/2026-08-16-harbor-authentik-oidc.md`

**Interfaces:**
- Consumes: completed Authentik and Harbor configuration.
- Produces: recovery, rotation, and live verification guidance.

- [ ] **Step 1: Extend the SSO runbook**

Document:

- the Harbor Authentik issuer and redirect URI;
- `homelab-admins` administrator mapping;
- password-store entry and `just seal-harbor-oidc` rotation flow;
- Harbor local DB recovery URL;
- first browser login and Harbor CLI secret use for Docker/Helm;
- live verification of OIDC discovery, login, group elevation, local admin recovery, and Docker login.

- [ ] **Step 2: Run final static verification**

Run `git diff --check`, `just --summary`, both `kubeseal --validate` commands, Authentik Helm render, two Harbor Helm renders, and Kustomize builds for infra, Harbor, and the full apps bundle. Scan changed files for plaintext client secrets and PEM private keys.

- [ ] **Step 3: Request independent review**

Ask the canonical fresh-context `reviewer` to inspect the diff against this plan, Harbor 2.14 OIDC behavior, Authentik 2026.5.3 blueprint behavior, secret handling, private CA trust, rollout ordering, and recovery requirements. Resolve every Critical and Important finding.

- [ ] **Step 4: Commit documentation and review fixes**

```bash
git add docs/specs/2026-08-16-harbor-authentik-oidc-design.md docs/plans/2026-08-16-harbor-authentik-oidc.md docs/runbooks/authentik-sso.md
git commit -m "docs(authentik): document Harbor SSO"
```

- [ ] **Step 5: Squash-merge locally**

After post-commit verification, squash the feature branch into local `main` as one signed Conventional Commit, verify the merged tree again, and remove only this task's worktree and feature branch.
