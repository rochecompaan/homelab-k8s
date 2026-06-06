# Homelab Grafana alerts

This overlay provisions Grafana alert rules adapted for the homelab cluster:

- Kubernetes health: NotReady nodes, CrashLoopBackOff pods, unavailable Deployment/StatefulSet replicas, critical Prometheus targets down.
- Node resources: filesystem, memory, CPU, load, node-exporter availability, and PVC usage thresholds.
- Longhorn health: unhealthy Longhorn volumes.
- Logs: recent error/exception/panic/fatal entries from VictoriaLogs.
- Backups: CNPG backup age when backup telemetry exists for homelab CNPG clusters.

Grafana sends notifications to an internal webhook relay. The relay code lives in `webhook/grafana_matrix_webhook.py`; Kustomize packages it into the `grafana-matrix-webhook` ConfigMap. The relay converts Grafana webhook payloads into Matrix `m.notice` messages and sends them to a dedicated Matrix room.

## Matrix room setup

Use a dedicated room for alerts. It keeps noisy infrastructure notifications out of personal chats, lets you tune notification settings independently, and limits the Matrix bot token to alert delivery.

Generate the Matrix user, create the room, and seal the relay secret:

```bash
just setup-grafana-matrix-alerts '<new-grafana-alerts-user-password>'
```

The target overwrites `grafana-matrix-webhook-secret.yaml` with a SealedSecret containing the Matrix room ID and access token. Commit that SealedSecret before syncing this app.

## Reload provisioning

After ArgoCD syncs updated alert rules, ask Grafana to reload provisioned alerting resources:

```bash
just grafana-alerts-reload
```

The target defaults to `https://grafana.compaan` and reads the Grafana admin credentials from `pass show private/login/grafana.compaan`. Override with `GRAFANA_URL`, `GRAFANA_USER`, or `GRAFANA_PASSWORD` if needed.

## Validation

```bash
python3 scripts/test-grafana-matrix-webhook.py
kubectl kustomize argocd/homelab/grafana-dashboards
kubectl kustomize argocd/homelab/apps
```
