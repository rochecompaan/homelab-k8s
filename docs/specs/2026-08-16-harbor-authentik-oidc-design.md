# Harbor Authentik OIDC Design

## Goal

Enable browser-based Harbor login through the existing Authentik deployment at `https://auth.compaan` while preserving local Harbor administrator recovery and GitOps ownership of Kubernetes resources and application configuration.

## Current State

- Harbor chart `1.18.0` deploys Harbor `2.14.0` at `https://harbor.compaan`.
- Authentik chart `2026.5.3` runs at `https://auth.compaan` and already provides ArgoCD SSO.
- Authentik has `homelab-admins` and `homelab-users` groups.
- Harbor currently uses `db_auth`; its configuration API reports that the authentication mode is editable and that no non-admin local users exist.
- Both services use certificates issued by the private `compaan-ca`.

## Architecture

### Authentik provider

A ConfigMap in the `authentik` namespace contains an Authentik blueprint named `harbor.yaml`. The blueprint declaratively creates or updates:

- an OAuth2/OpenID provider named `Harbor` with client ID `harbor`;
- strict authorization redirect URI `https://harbor.compaan/c/oidc/callback`;
- authorization-code and refresh-token grants;
- the default `openid`, `profile`, `email`, and `offline_access` scope mappings;
- an Authentik application named `Harbor` with slug `harbor` and launch URL `https://harbor.compaan`.

The blueprint resolves the client secret from `AUTHENTIK_HARBOR_CLIENT_SECRET` with Authentik's `!Env` blueprint tag. The Authentik worker receives that variable from a dedicated namespace-bound SealedSecret. The Authentik Helm chart mounts the blueprint ConfigMap through `blueprints.configMaps`.

The existing `infra` ArgoCD application owns the Authentik blueprint ConfigMap and SealedSecret. It syncs at wave `1`, before the Authentik application at wave `2`.

### Harbor configuration

Harbor core receives `CONFIG_OVERWRITE_JSON` from a dedicated `harbor-oidc` SealedSecret through `core.extraEnvVars`. The JSON configures:

- `auth_mode`: `oidc_auth`;
- `primary_auth_mode`: `true`;
- provider name: `authentik`;
- endpoint: `https://auth.compaan/application/o/harbor/`;
- client ID: `harbor`;
- client secret: the same value used by the Authentik provider;
- group claim: `groups`;
- administrator group: `homelab-admins`;
- scopes: `openid,profile,email,offline_access`;
- username claim: `preferred_username`;
- certificate verification and automatic onboarding enabled.

`CONFIG_OVERWRITE_JSON` makes Harbor's user configuration read-only in the UI and reapplies the declared values at every core startup. Changes therefore remain Git-controlled.

### Secret generation

A single password-store entry, `private/login/harbor.compaan-authentik-oidc`, holds the OIDC client secret. A `just seal-harbor-oidc` recipe reads it and atomically produces two strict-scope SealedSecrets:

- `authentik/authentik-harbor-oidc`, containing `AUTHENTIK_HARBOR_CLIENT_SECRET`;
- `harbor/harbor-oidc`, containing `CONFIG_OVERWRITE_JSON`.

No plaintext client secret or OIDC configuration containing the secret is committed.

### Private CA trust

The public `compaan-ca` certificate is stored as a `.crt` file in the Harbor overlay. Kustomize generates the stable `harbor-ca-bundle` Secret with key `ca.crt`. Harbor sets top-level `caBundleSecretName: harbor-ca-bundle`, which injects the CA into the core trust store. OIDC certificate verification remains enabled.

## Rollout and Recovery

- Bump the Authentik worker OIDC revision annotation when its client secret changes.
- Bump Harbor core's existing secrets revision from `5` to `6` for this rollout and on later OIDC secret rotations.
- The local Harbor `admin` account remains available through `https://harbor.compaan/account/sign-in`.
- If Harbor SSO fails, use the local `admin` account and correct the Git-managed OIDC configuration.
- Harbor persists environment-overwritten values in its database. Removing `CONFIG_OVERWRITE_JSON` does not restore `db_auth`.
- Restoring `db_auth` requires a supported Harbor authentication migration or a verified database restore. A Git revert is not sufficient.
- Docker and Helm clients cannot complete browser OIDC. OIDC users must first log into the Harbor UI and then use their Harbor CLI secret.

## Verification

This is static configuration and secret wiring, so the Testing Value Gate excludes new automated tests. Verify directly:

1. Both SealedSecrets validate against the deployed controller.
2. Their encrypted key names are exact and neither manifest contains plaintext secret data.
3. The Authentik chart renders the worker environment variable and blueprint mount.
4. The blueprint YAML structure matches Authentik `2026.5.3` model and redirect URI syntax.
5. Two Harbor chart renders are byte-identical and include the OIDC secret reference and CA bundle mount.
6. The Authentik configuration, Harbor overlay, and full apps bundle render with Kustomize.
7. After ArgoCD reconciliation, Authentik discovery, Harbor OIDC login, `homelab-admins` elevation, local admin recovery, and an OIDC user's Harbor CLI secret are verified live.
