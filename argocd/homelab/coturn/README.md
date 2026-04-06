# coturn

TURN relay for Matrix voice/video calls.

## Components

- `configmap.yaml` - coturn configuration template
- `deployment.yaml` - single coturn pod in the `matrix` namespace
- `service.yaml` - ClusterIP service on `3478/TCP`

## How it works

- Synapse advertises `turn:turn.matrix.compaan:3478?transport=tcp`
- Synapse reads `turn_shared_secret` from the `matrix` Secret's `registration_shared_secret`
- coturn renders the same secret into `static-auth-secret`
- OpenZiti exposes `turn.matrix.compaan:3478` to client identities with the `matrix` role attribute via:
  - `argocd/homelab/miniziti-operator/matrix-turn/service.yaml`
  - `argocd/homelab/miniziti-operator/matrix-turn/access-policy.yaml`

## Notes

- This deployment is intentionally a `Deployment`, not `hostNetwork`, because clients reach TURN through OpenZiti.
- The init container renders `turnserver.conf` with Python so shared secrets containing special characters are preserved exactly.
- coturn is configured for Matrix-style shared-secret auth with:
  - `lt-cred-mech`
  - `use-auth-secret`
  - `static-auth-secret`

## Debugging

Check the TURN config advertised by Synapse:

```sh
curl -sS \
  -H "Authorization: Bearer <ACCESS_TOKEN>" \
  https://matrix.compaan/_matrix/client/v3/voip/turnServer | jq
```

Check coturn logs:

```sh
KUBECONFIG=./.kubeconfig kubectl -n matrix logs deploy/coturn -f
```

Inspect the rendered config in the pod:

```sh
KUBECONFIG=./.kubeconfig kubectl -n matrix exec deploy/coturn -- cat /etc/coturn/turnserver.conf
```

Test Ziti-backed reachability from a client host:

```sh
nc -vz turn.matrix.compaan 3478
```
