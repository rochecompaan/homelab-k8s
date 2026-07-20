# Matrix CPU and K3s Alert Cleanup Design

## Context

Prometheus reports sustained CPU throttling for the Matrix PostgreSQL container. The container is healthy and averages roughly 20m CPU, but its 150m CPU limit constrains short database bursts. Prometheus also reports `KubeControllerManagerDown`, `KubeSchedulerDown`, and `KubeProxyDown` because kube-prometheus-stack expects standalone Kubernetes component targets that do not exist in this K3s cluster.

## Matrix PostgreSQL resources

Configure explicit resources under `postgresql.primary.resources` in `argocd/base/matrix/app.yaml`:

- CPU request: `100m`
- CPU limit: `500m`
- Memory request: `128Mi`
- Memory limit: `192Mi`
- Ephemeral-storage request: `50Mi`
- Ephemeral-storage limit: `2Gi`

This preserves every current resource value except the CPU limit. The higher CPU limit permits short PostgreSQL bursts without increasing its guaranteed CPU reservation.

## K3s monitoring cleanup

Set these kube-prometheus-stack components to `enabled: false` in `argocd/base/kube-prometheus-stack/app.yaml`:

- `kubeControllerManager`
- `kubeProxy`
- `kubeScheduler`

The pinned kube-prometheus-stack chart gates each component's ServiceMonitor and alert/recording rules on these values. Disabling the components therefore removes both the unusable standalone scrape configuration and the false-positive `*Down` rules. It does not affect API server, kubelet, node, workload, or other cluster monitoring.

Do not modify the Grafana log-error exclusion query: these are Prometheus metric alerts, not log-derived alerts.

## Delivery and verification

All changes remain GitOps-only; no cluster resources will be mutated directly.

Because these are static Helm-value changes, no new automated test is warranted under the Testing Value Gate. Verify directly by:

1. Parsing the edited Application manifests as YAML.
2. Rendering Matrix chart `2.9.16` and confirming PostgreSQL has the intended resource requests and limits.
3. Rendering kube-prometheus-stack `79.12.0` and confirming the three component ServiceMonitors and their `*Down` rules are absent.
4. Rendering the homelab ArgoCD bootstrap Kustomization to ensure repository composition remains valid.

The repository revision does not contain `flake.nix`, so the previously documented flake-check command is not applicable.
