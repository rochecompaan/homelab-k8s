# Garage Private S3 Ingress Design

## Goal

Make `http://s3.compaan` work from the Forgejo runner and other in-cluster clients without adding a Ziti DNS forwarder or changing the cluster-wide `.compaan` DNS policy.

The route must also support Garage's configured virtual-host addressing under `*.s3.compaan`.

## Current behavior

CoreDNS rewrites every `.compaan` query to the `traefik-private` Service. Consequently, `s3.compaan` resolves to the private Traefik ClusterIP rather than the OpenZiti intercept address.

This works for internal names that have a matching `traefik-private` Ingress. Garage currently has no such route. Its existing ingresses are public routes for `s3-api.croprun.com` and `s3.croprun.com`.

Garage's `rootDomain: ".s3.compaan"` setting controls S3 virtual-host request interpretation; it does not create DNS or ingress routing.

## Design

Add a dedicated, values-driven Garage Ingress rendered from a separate Helm template.

The Ingress will:

- use `ingressClassName: traefik-private`;
- accept `s3.compaan` and `*.s3.compaan`;
- route prefix `/` to the existing Garage Service on port `3900`;
- use HTTP only, with no TLS configuration; and
- have a distinct name from the existing public S3 API Ingress.

The new private-ingress values will live under the existing Garage S3 API ingress configuration. Keeping the template separate avoids coupling the private and public ingress classes or growing the existing public-ingress template with unrelated rendering branches.

## Request flow

1. An in-cluster client requests `http://s3.compaan` or a bucket host such as `http://photos.s3.compaan`.
2. Cluster DNS rewrites the `.compaan` name to the `traefik-private` Service address.
3. Traefik selects the new private Ingress from the original HTTP `Host` header.
4. Traefik proxies the request to the Garage Service on port `3900`.
5. Garage handles the S3 request using its `.s3.compaan` root-domain configuration.

## Unchanged behavior

- The CoreDNS ConfigMap remains unchanged.
- No Ziti DNS forwarding resources are added.
- Existing public Garage ingresses remain unchanged.
- Existing private `.compaan` applications continue using the current catch-all DNS rewrite.
- No Kubernetes resources are applied directly; ArgoCD remains responsible for reconciliation.

## Failure behavior

If Garage has no ready endpoints, Traefik returns an upstream availability error. DNS continues resolving because it targets Traefik rather than Garage directly. Requests with unrelated hostnames do not match the new route.

## Security

The endpoint is intentionally HTTP-only and reachable through the internal `traefik-private` ingress class. This change does not add a public hostname or public ingress route. Traffic between the runner, Traefik, and Garage remains unencrypted within the cluster network, matching the requested `http://s3.compaan` endpoint.

## Verification

This is static Helm/Kubernetes configuration, so no new automated test is justified under the Testing Value Gate. Verify it directly by:

1. running `helm lint argocd/homelab/garage`;
2. rendering the chart with `helm template garage argocd/homelab/garage --namespace garage`;
3. confirming the rendered private Ingress has both host rules, `traefik-private`, and backend port `3900`; and
4. confirming the existing public Garage ingresses render unchanged.
