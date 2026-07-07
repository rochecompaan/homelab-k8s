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

## PostgreSQL Credentials

CloudNativePG generates the Authentik application database credentials because `argocd/homelab/authentik-db/postgres-cluster.yaml` does not set `bootstrap.initdb.secret`.

Authentik reads the generated credentials from the `authentik-postgres-app` secret:

- `username` -> `AUTHENTIK_POSTGRESQL__USER`
- `password` -> `AUTHENTIK_POSTGRESQL__PASSWORD`

The Authentik sealed secret `authentik-config` contains only Authentik configuration/bootstrap values, not PostgreSQL credentials.

## Verification Checklist

Run these checks after ArgoCD syncs the Authentik and ArgoCD changes:

```bash
kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n authentik get pods
kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n authentik get ingress authentik-server
kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n authentik get cluster authentik-postgres
kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n authentik get secret authentik-postgres-app
curl -kI https://auth.compaan
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

## Recovery

If Authentik is unavailable, use the ArgoCD local admin account to inspect and roll back GitOps changes.

If ArgoCD SSO is broken but local admin works:

1. Sign in to ArgoCD with the local admin account.
2. Check `argocd/base/argocd/app.yaml` for `configs.cm.oidc.config` and `configs.rbac` changes.
3. Revert the Git commit that introduced the broken OIDC config.
4. Let ArgoCD reconcile from Git.

If Authentik database recovery is needed, restore the CloudNativePG data for `authentik-postgres` before adding more OIDC clients beyond ArgoCD.
