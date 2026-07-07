# Authentik SSO Design

## Goal

Add a self-hosted identity provider to the homelab Kubernetes cluster for single sign-on to applications that support native OIDC. Phase 1 focuses on deploying Authentik and integrating ArgoCD only. Later phases can add Forgejo, Harbor/container registry, Nextcloud, Matrix, Grafana, and other native-OIDC apps one at a time.

## Decisions

- Use **Authentik** as the homelab identity provider.
- Use **OIDC only** for phase 1; SAML is not required for the initial app set.
- Keep Authentik **fully self-hosted** with local users, groups, credentials, and MFA.
- Support **YubiKey/WebAuthn** as an MFA/passkey path.
- Expose Authentik only on the private/Ziti overlay network.
- Use the generic private hostname **`auth.compaan`**.
- Integrate **ArgoCD only** in the first rollout wave.
- Keep ArgoCD's local admin recovery path enabled during rollout.
- Prefer direct ArgoCD `oidc.config` against Authentik instead of routing through ArgoCD's bundled Dex.
- Keep Authentik application/user/group setup manual in phase 1 unless implementation discovers a low-risk declarative bootstrap path.

## Current Context

The repo is GitOps-managed through ArgoCD:

- `argocd/base/*/app.yaml` defines ArgoCD `Application` resources.
- `argocd/homelab/*` contains cluster-specific manifests, Helm values, and Kustomize overlays.
- Existing platform services include Traefik, cert-manager, trust-manager, sealed-secrets, reflector, Kyverno, CloudNativePG, ArgoCD, OpenZiti, and storage components.
- User-facing services that may later use SSO include Forgejo, Harbor/container registry, Nextcloud, Matrix, Garage, Webmutt, Jellyfin, Grafana-related services, and Victoria Logs.
- No dedicated identity provider is currently present in `argocd/base`.

## Chosen Approach

Deploy Authentik as a GitOps-managed ArgoCD application and configure it as the OIDC issuer for ArgoCD.

The first phase intentionally avoids a broad SSO migration. Authentik will be proven with one high-value administrative app, ArgoCD, while preserving a local fallback login. Once Authentik deployment, recovery, backups, and YubiKey/WebAuthn login are proven, additional applications can be integrated in separate changes.

## Alternatives Considered

### Keycloak

Keycloak is mature, feature-complete, and has excellent OIDC and WebAuthn support. It is a good fit for larger or more enterprise-oriented deployments. For this homelab, it is heavier operationally than needed for 2-10 household users and an easy-admin preference.

### Kanidm

Kanidm is lightweight, modern, and security-focused. It is attractive for self-hosted identity, but has fewer homelab integration examples and would likely require more manual discovery for common app integrations than Authentik.

### External IdP

External identity providers such as Google, GitHub, Apple, or Cloudflare were rejected as the primary source because the desired design is fully self-hosted with local users and local MFA.

### Ingress auth proxy first

An ingress-level auth proxy such as Authelia or oauth2-proxy is useful for apps without native SSO, but the primary goal is native OIDC integration for apps that already support it. Auth proxy integration can be evaluated later if needed.

## Architecture

Add a new Authentik application to the existing ArgoCD layout:

- `argocd/base/authentik/app.yaml`
  - ArgoCD `Application` for Authentik.
  - Uses the official Authentik Helm chart unless implementation finds an established repo-local reason to vendor manifests instead.
- `argocd/base/authentik/kustomization.yaml`
  - Includes the Authentik application.
- `argocd/homelab/authentik/`
  - Cluster-specific Authentik values and supporting manifests.
  - Database, secret, and ingress/Ziti-facing resources as needed.

Runtime components:

- Authentik server and worker.
- Dedicated PostgreSQL database, preferably following the repo's existing CloudNativePG patterns.
- Dedicated Redis for Authentik cache/task coordination. A chart-managed Redis is acceptable if it keeps phase 1 simple and matches the Authentik chart's supported deployment model.
- Sealed secrets for sensitive values.
- Private ingress/service exposure for `auth.compaan` over the Ziti overlay.

Sync ordering should preserve dependency readiness:

1. Existing platform operators such as CloudNativePG, cert-manager, sealed-secrets, and Traefik are available.
2. Authentik database and prerequisite secrets are applied.
3. Authentik server, worker, and Redis are deployed.
4. Authentik is configured through its UI for the first ArgoCD OIDC client.
5. ArgoCD OIDC configuration and RBAC mapping are applied after Authentik is reachable.

## Auth Flow

1. A user opens ArgoCD through the Ziti overlay.
2. ArgoCD redirects the user to Authentik at `auth.compaan`.
3. Authentik authenticates the user with local credentials and YubiKey/WebAuthn MFA.
4. Authentik returns OIDC tokens and claims to ArgoCD.
5. ArgoCD maps Authentik groups or claims to ArgoCD RBAC roles.
6. Members of `homelab-admins` receive ArgoCD admin access.
7. Users outside admin groups do not receive admin permissions.

## Authentik Configuration Model

Phase 1 uses a pragmatic hybrid model:

- Cluster infrastructure is GitOps-managed.
- Authentik user, group, provider, and application setup is performed manually in the Authentik UI unless implementation identifies a stable and low-risk declarative bootstrap mechanism.

Required Authentik objects:

- Initial admin account from sealed bootstrap credentials.
- Household user accounts.
- WebAuthn/YubiKey MFA enrollment policy or stage.
- `homelab-admins` group.
- Optional `homelab-users` group for future non-admin app access.
- OIDC provider/application for ArgoCD.
- OIDC claims that allow ArgoCD to map `homelab-admins` to admin privileges.

## ArgoCD Integration

ArgoCD should be configured directly with Authentik's OIDC issuer:

- Add ArgoCD `oidc.config` that points at Authentik's issuer URL.
- Store the ArgoCD OIDC client secret in a Kubernetes secret managed through the repo's sealed-secret workflow.
- Add ArgoCD RBAC mapping for `homelab-admins`.
- Keep the local ArgoCD admin account available through initial rollout and verification.
- Document the process for disabling or further restricting local admin later, but do not require that in phase 1.

## Secrets

Use sealed secrets for:

- Authentik secret key.
- PostgreSQL credentials.
- Authentik bootstrap/admin credentials.
- ArgoCD OIDC client secret.
- Any Redis password if Redis authentication is enabled.

Secrets must not be committed in plaintext.

## Persistence and Backups

Authentik becomes critical infrastructure once applications rely on it for login. Before adding more applications beyond ArgoCD, confirm that Authentik's PostgreSQL data is covered by the homelab backup and recovery story.

Phase 1 should include recovery documentation for:

- Restoring Authentik database data.
- Recovering from a broken Authentik deployment.
- Recovering from a broken ArgoCD OIDC configuration.
- Using the local ArgoCD admin fallback if Authentik is unavailable.

## Network Exposure

Authentik should be reachable only through the private/Ziti overlay at `auth.compaan`. Public internet exposure is out of scope for phase 1.

TLS should follow the existing private certificate pattern, likely using cert-manager and the existing `compaan-ca` issuer unless implementation discovers a better existing convention for Ziti-only services.

## Rollout Plan

1. Add Authentik manifests and ArgoCD application.
2. Add database, Redis, ingress, and sealed-secret prerequisites.
3. Sync Authentik through ArgoCD.
4. Verify Authentik pods, services, database connectivity, Redis connectivity, TLS, and `auth.compaan` access through Ziti.
5. Log into Authentik with the bootstrap admin.
6. Create household users and enroll YubiKey/WebAuthn MFA.
7. Create `homelab-admins` and add the appropriate admin user.
8. Create the ArgoCD OIDC provider/application in Authentik.
9. Add ArgoCD OIDC configuration and RBAC mapping through GitOps.
10. Verify ArgoCD local admin still works.
11. Verify ArgoCD SSO works for a `homelab-admins` member.
12. Verify a non-admin/default user does not receive admin access.
13. Document operational recovery steps.

## Verification

No new automated tests are required for the spec itself or for static GitOps YAML content. The implementation should use direct verification instead:

- YAML/Kustomize/Helm rendering checks where practical.
- Existing repo validation commands when relevant.
- ArgoCD sync status for Authentik and ArgoCD.
- Runtime pod readiness checks.
- Authentik UI login with YubiKey/WebAuthn MFA.
- ArgoCD SSO login and RBAC checks.
- ArgoCD local admin fallback check.

A baseline check in the design worktree found that `pytest` is not installed in the current environment. Python syntax compilation for existing Python scripts/tests passed. This is sufficient for the design-only change.

## Out of Scope for Phase 1

- SAML support.
- Public internet exposure for Authentik.
- Protecting non-OIDC apps through an ingress auth proxy.
- Migrating Forgejo, Harbor, Nextcloud, Matrix, Grafana, Jellyfin, or other apps to SSO.
- Fully declarative Authentik application/provider/user provisioning unless implementation discovers a simple and reliable existing mechanism.
- Disabling ArgoCD local admin before SSO and recovery paths are proven.

## Future Phases

Potential follow-up work:

- Add Forgejo OIDC integration.
- Add Harbor/container registry OIDC integration.
- Add Nextcloud OIDC integration.
- Add Matrix OIDC integration if desired.
- Evaluate ingress-level auth for apps without native SSO.
- Automate Authentik configuration through Terraform, Authentik blueprints, or API-driven bootstrap if manual UI setup becomes burdensome.
- Harden local admin recovery accounts after multiple successful SSO integrations.
