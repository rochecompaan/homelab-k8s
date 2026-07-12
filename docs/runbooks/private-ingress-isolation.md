# Private ingress isolation

This cluster intentionally exposes only the following public hostnames through the router's public 80/443 forwarding path:

- `git.compaan.cloud`
- `s3.croprun.com`
- `s3-api.croprun.com`
- `ctrl.compaan.cloud`
- `rtr.compaan.cloud`

All `*.compaan` application hostnames are private OpenZiti-only names and must not be served by the public Traefik instance.

## Ingress model

- `traefik` is the public NodePort ingress controller. It uses the `traefik-public` ingress class and only watches:
  - HTTP Ingresses in `forgejo` and `garage`
  - Traefik CRDs in `openziti` labelled `ingress-scope=public`
- `traefik-private` is the private ClusterIP ingress controller. It uses the `traefik-private` ingress class and watches Traefik CRDs labelled `ingress-scope=private`.
- Cluster DNS rewrites `*.compaan` to `traefik-private.kube-system.svc.cluster.local`.
- OpenZiti private services should target `traefik-private` or the destination app service directly.

## Rollout notes

Apply the split via GitOps only. For the lowest-risk rollout, sync in this order:

1. `traefik-private`
2. `traefik`
3. public apps: `forgejo`, `garage`, `ziti-controller`, `ziti-router`
4. private apps and infra that reference `traefik-private`

After sync, verify from an external host that private names do not route through the public IP, for example:

```sh
ssh upfront4 'curl --noproxy "*" -k --http1.1 --connect-timeout 5 --max-time 10 \
  -sS -o /dev/null -D - \
  --resolve "longhorn.compaan:443:102.218.60.202" \
  "https://longhorn.compaan/"'
```

Expected result for private `*.compaan` names: no public app response from the cluster.
