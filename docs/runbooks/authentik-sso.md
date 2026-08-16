# Authentik SSO Runbook

## Scope

Authentik is the private homelab identity provider at `https://auth.compaan`. It provides SSO for ArgoCD and Harbor. Authentik is reachable over the Ziti overlay and is not intended for public internet exposure.

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
- Client ID: use the Authentik-generated provider Client ID and keep `argocd/base/argocd/app.yaml` in sync.
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

## Harbor OIDC Provider

The `authentik-harbor-blueprint` ConfigMap declares the Harbor application and provider. The Authentik worker mounts this ConfigMap and applies its `harbor.yaml` blueprint.

The provider uses these values:

- Application and provider name: `Harbor`
- Application slug: `harbor`
- Client ID: `harbor`
- Redirect URI: `https://harbor.compaan/c/oidc/callback`
- Issuer: `https://auth.compaan/application/o/harbor/`
- Grants: authorization code and refresh token
- Scopes: `openid`, `profile`, `email`, `offline_access`
- Group claim: `groups`
- Harbor administrator group: `homelab-admins`

Harbor reads its OIDC configuration from `CONFIG_OVERWRITE_JSON`. The `harbor-oidc` SealedSecret supplies this environment variable to Harbor core.

Harbor trusts `auth.compaan` through the `harbor-ca-bundle` Secret. Kustomize generates this Secret from `argocd/homelab/harbor/compaan-ca.crt`.

The environment configuration makes Harbor authentication settings read-only. Change these settings in Git, not in the Harbor interface.

## Harbor OIDC Secret Rotation

1. Replace the password-store value:

   ```bash
   pass generate -i private/login/harbor.compaan-authentik-oidc 64
   ```

2. Generate both SealedSecrets:

   ```bash
   just seal-harbor-oidc
   ```

3. Increase `homelab.compaan.cloud/harbor-oidc-revision` in `argocd/base/authentik/app.yaml`.
4. Increase the core `homelab.compaan.cloud/secrets-revision` in `argocd/base/harbor/app.yaml`.
5. Commit and push all four changes together.

The two SealedSecrets must use the same client secret. A partial rotation prevents Harbor from authenticating with Authentik.

## Harbor Login and CLI Access

Open `https://harbor.compaan` to start an Authentik login. Authentik users join Harbor automatically after the first successful login.

Members of `homelab-admins` receive Harbor system administrator privileges. Other users receive only their assigned Harbor project roles.

Use `https://harbor.compaan/account/sign-in` for the local Harbor `admin` account. Keep this recovery path available.

Docker and Helm cannot use the browser redirect. An OIDC user must first sign in through the Harbor interface.

1. Open **User Profile** in Harbor.
2. Copy the Harbor CLI secret.
3. Use the Authentik username and Harbor CLI secret:

   ```bash
   docker login harbor.compaan -u USERNAME
   ```

Do not use the Authentik password as the Docker password.

## PostgreSQL Credentials

CloudNativePG generates the Authentik application database credentials because `argocd/homelab/authentik-db/postgres-cluster.yaml` does not set `bootstrap.initdb.secret`.

Authentik reads the generated credentials from the `authentik-postgres-app` secret:

- `username` -> `AUTHENTIK_POSTGRESQL__USER`
- `password` -> `AUTHENTIK_POSTGRESQL__PASSWORD`

The Authentik sealed secret `authentik-config` contains only Authentik configuration/bootstrap values, not PostgreSQL credentials.

## Verification Checklist

Run these checks after ArgoCD syncs the Authentik, ArgoCD, and Harbor changes:

```bash
kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n authentik get pods
kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n authentik get ingress authentik-server
kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n authentik get cluster authentik-postgres
kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n authentik get secret authentik-postgres-app
kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n authentik get configmap authentik-harbor-blueprint
kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n authentik get secret authentik-harbor-oidc
kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n harbor get secret harbor-oidc harbor-ca-bundle
curl -kI https://auth.compaan
curl -fsS https://auth.compaan/application/o/harbor/.well-known/openid-configuration | jq -er '.issuer'
curl -fsS https://harbor.compaan/api/v2.0/health | jq -er '.status'
```

Expected outcomes:

- Authentik server and worker pods are ready.
- CloudNativePG reports the `authentik-postgres` cluster.
- CloudNativePG generated the `authentik-postgres-app` secret.
- The `authentik-server` ingress lists `auth.compaan`.
- `curl -kI https://auth.compaan` returns an HTTP response from Authentik while connected to Ziti.
- ArgoCD local admin login still works.
- ArgoCD SSO login works for a user in `homelab-admins`.
- A user outside `homelab-admins` does not receive admin privileges.
- The Harbor OIDC discovery document reports `https://auth.compaan/application/o/harbor/` as its issuer.
- The Harbor login page starts the Authentik login flow.
- A member of `homelab-admins` receives Harbor system administrator privileges.
- The local Harbor `admin` account can still use `/account/sign-in`.
- An OIDC user can use a Harbor CLI secret for `docker login`.

## Rollout Notes

2026-07-07 rollout result:

- Authentik is reachable at `https://auth.compaan` over Ziti via Traefik and the `compaan-ca` TLS certificate.
- ArgoCD SSO login through Authentik was verified by an admin user in `homelab-admins`.
- The Authentik provider uses an Authentik-generated Client ID; ArgoCD `configs.cm.oidc.config.clientID` must match that generated value.
- ArgoCD trusts the private `compaan-ca` through `configs.cm.oidc.config.rootCA` so it can query the Authentik OIDC discovery endpoint.
- The ArgoCD OIDC client secret is stored in `private/login/argocd.compaan-authentik-oidc` and sealed to `argocd/homelab/infra/argocd-authentik-oidc-secret.yaml`.
- The Authentik Ziti service requires both Dial access and router hosting. `argocd/homelab/miniziti-operator/authentik/service.yaml` sets `spec.router.name: ziti-router`, and `access-policy.yaml` grants Dial access to the `admin` OpenZiti role.
- Non-admin ArgoCD authorization should still be checked when a suitable non-admin Authentik user is available.

## Recovery

If Authentik is unavailable, use the ArgoCD local admin account to inspect and roll back GitOps changes.

If ArgoCD SSO is broken but local admin works:

1. Sign in to ArgoCD with the local admin account.
2. Check `argocd/base/argocd/app.yaml` for `configs.cm.oidc.config` and `configs.rbac` changes.
3. Revert the Git commit that introduced the broken OIDC configuration.
4. Let ArgoCD reconcile from Git.

If Harbor SSO is broken, open `https://harbor.compaan/account/sign-in`.

1. Sign in with the local Harbor `admin` account.
2. Inspect the Authentik blueprint status and the Harbor core logs.
3. Correct the OIDC configuration in Git.
4. If the client secret changes, run `just seal-harbor-oidc`.
5. If the client secret changes, increase both OIDC revision annotations.
6. Commit and push the correction.
7. Let ArgoCD reconcile Authentik and Harbor from Git.
8. Open `https://harbor.compaan` and complete an Authentik login.
9. Open `https://harbor.compaan/account/sign-in` and complete a local administrator login.

CAUTION: A Git revert does not restore `db_auth`. Harbor stores the environment configuration in its database.

Restoring `db_auth` requires a supported Harbor authentication migration or a verified database restore. Treat this restoration as a separate recovery operation.

If Authentik database recovery is necessary, restore the CloudNativePG data for `authentik-postgres` before you add more OIDC clients.
