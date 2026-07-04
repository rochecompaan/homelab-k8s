# Garage S3 API access at s3-api.croprun.com

Date: 2026-07-04

## Context

Garage is deployed by ArgoCD from `argocd/homelab/garage`. The chart already exposes the S3 website endpoint on `s3.croprun.com`, but the S3 API ingress is disabled. The S3 API service listens on port `3900` and is intended to sit behind an HTTPS reverse proxy.

Garage path-style requests are always enabled. Its existing `garage.s3.api.rootDomain` value remains unchanged by this work so any current virtual-host behavior tied to that domain is preserved.

## Goal

Expose Garage's S3 API at:

```text
https://s3-api.croprun.com/<bucket>/<key>
```

This new public endpoint is path-style only.

## Non-goals

- Do not enable wildcard DNS or wildcard TLS for bucket virtual-host access on `s3-api.croprun.com`.
- Do not change the existing Garage S3 API `rootDomain` value.
- Do not expose the Garage admin API.
- Do not mutate cluster resources directly; ArgoCD must apply the change from Git.

## Design

Use the existing Garage Helm chart values to enable `ingress.s3.api` with Traefik and cert-manager:

- `ingress.s3.api.enabled: true`
- `ingress.s3.api.className: traefik`
- `ingress.s3.api.annotations.cert-manager.io/cluster-issuer: letsencrypt-prod`
- one host rule for `s3-api.croprun.com`
- one TLS entry using a dedicated secret such as `garage-s3-api-croprun-com-tls`

Do not configure a wildcard API ingress for `*.s3-api.croprun.com`. Leave `garage.s3.api.rootDomain` unchanged so this change only introduces the new path-style ingress host.

The request flow will be:

```text
client -> https://s3-api.croprun.com/<bucket>/<key> -> Traefik -> garage service port 3900 -> Garage S3 API
```

## Error handling and compatibility

- If DNS for `s3-api.croprun.com` is missing, cert-manager certificate issuance and external access will fail; the GitOps manifests remain valid.
- Existing website access at `s3.croprun.com` remains unchanged.
- Existing in-cluster clients using the Garage service are unaffected.
- Existing Garage S3 API `rootDomain` behavior remains unchanged.

## Verification

Use repository-local validation rather than direct cluster mutation:

1. Render the Garage chart and confirm an API Ingress exists for `s3-api.croprun.com` on service port `3900`.
2. Confirm no wildcard API host for `*.s3-api.croprun.com` is rendered.
3. Confirm the rendered `garage.toml` keeps the existing `[s3_api].root_domain` value.
4. Confirm the existing website ingress for `s3.croprun.com` still renders.

No new automated test is planned because this is a Helm values configuration change. The meaningful verification is template rendering of the generated Kubernetes resources and Garage config.
