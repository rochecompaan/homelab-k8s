#!/usr/bin/env bash
set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG:-./.kubeconfig}"
KUBECTL_BIN="${KUBECTL:-kubectl}"
RECOVER=0
YES=0

usage() {
  cat <<'USAGE'
Usage: scripts/homelab-recovery.sh [--recover --yes]

Default mode is read-only and prints cluster health/status.

Options:
  --recover   Print the recovery plan. Requires --yes to run mutating steps.
  --yes       Allow mutating recovery steps when used with --recover.
  -h, --help  Show this help.
USAGE
}

while (($#)); do
  case "$1" in
    --recover) RECOVER=1 ;;
    --yes) YES=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 64 ;;
  esac
  shift
done

k() {
  "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" "$@"
}

heading() {
  printf '\n## %s\n' "$1"
}

warn() {
  printf 'warning: %s\n' "$*" >&2
}

planned_stages() {
  cat <<'PLAN'
Planned mutating stages:
  1. Recover Kyverno admission/background controllers if the webhook is unhealthy.
  2. Restart Longhorn manager pods and nudge the DaemonSet if pod creation stalls.
  3. Restart Longhorn CSI plugin, CSI sidecars, and driver deployer.
  4. Delete failed/unattached Kubernetes VolumeAttachments.
  5. Restart Traefik if its Kubernetes watchers show Unauthorized errors.
  6. Recycle known workload pods stuck in CrashLoopBackOff/CreateContainerError/Error/Unknown.
  7. Run final read-only verification.
PLAN
}

mutate() {
  printf '+ %q ' "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" "$@"
  printf '\n'
  if ! k "$@"; then
    warn "command failed: $*"
    return 1
  fi
}

status_report() {
  heading "homelab recovery status"
  printf 'kubeconfig: %s\n' "$KUBECONFIG_PATH"
  date -u '+time: %Y-%m-%dT%H:%M:%SZ'

  heading "nodes"
  k get nodes -o wide || true

  heading "pods not Running/Succeeded"
  k get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded -o wide || true

  heading "non-ready pods excluding completed jobs"
  k get pods -A -o json \
    | jq -r '.items[] | select(.status.phase != "Succeeded") | select((.status.containerStatuses // []) | any(.ready != true)) | [.metadata.namespace,.metadata.name,.spec.nodeName,.status.phase,((.status.containerStatuses // [])|map(.name+":"+(.ready|tostring)+":"+(.state.waiting.reason // .state.terminated.reason // "running"))|join(","))] | @tsv' \
    | column -t -s $'\t' || true

  heading "failed/unattached volumeattachments"
  k get volumeattachments.storage.k8s.io -o json \
    | jq -r '.items[] | select((.status.attached != true) or (.status.attachError != null)) | [.metadata.name,.spec.nodeName,.spec.source.persistentVolumeName, (.status.attached|tostring), (.status.attachError.message // "")] | @tsv' \
    | column -t -s $'\t' || true

  heading "longhorn nodes"
  k -n longhorn-system get nodes.longhorn.io -o wide || true

  heading "longhorn system non-running/non-ready"
  k -n longhorn-system get pods -o json \
    | jq -r '.items[] | select(.status.phase != "Succeeded") | select(.status.phase != "Running" or ((.status.containerStatuses // []) | any(.ready != true))) | [.metadata.name,.spec.nodeName,.status.phase,((.status.containerStatuses // [])|map(.name+":"+(.ready|tostring)+":"+(.state.waiting.reason // .state.terminated.reason // "running"))|join(","))] | @tsv' \
    | column -t -s $'\t' || true

  heading "longhorn volumes non-healthy"
  k -n longhorn-system get volumes.longhorn.io -o json \
    | jq -r '.items[] | select(.status.robustness != "healthy") | [.metadata.name,.status.state,.status.robustness,.status.currentNodeID, (.status.shareState // ""), (.status.conditions[]? | select(.type=="Scheduled") | (.reason+":"+.message))] | @tsv' \
    | column -t -s $'\t' || true

  heading "argocd apps unhealthy/out-of-sync"
  k -n argocd get applications.argoproj.io -o json \
    | jq -r '.items[] | select((.status.health.status // "") != "Healthy" or (.status.sync.status // "") != "Synced") | [.metadata.name, (.status.sync.status // "?"), (.status.health.status // "?"), (.status.operationState.phase // "")] | @tsv' \
    | sort || true

  heading "recent warning events tail"
  k get events -A --field-selector type=Warning --sort-by=.lastTimestamp 2>&1 | tail -50 || true
}

kyverno_needs_recovery() {
  local endpoints_json pods_json endpoint_count nonready_count
  endpoints_json="$(k -n kyverno get endpoints kyverno-svc -o json 2>/dev/null || echo '{}')"
  endpoint_count="$(jq -r '[.subsets[]?.addresses[]?] | length' <<<"$endpoints_json")"
  pods_json="$(k -n kyverno get pods -o json 2>/dev/null || echo '{"items":[]}')"
  nonready_count="$(jq -r '[.items[] | select(.metadata.labels."app.kubernetes.io/component" == "admission-controller" or .metadata.labels."app.kubernetes.io/component" == "background-controller") | select((.status.containerStatuses // []) | any(.ready != true))] | length' <<<"$pods_json")"
  [[ "$endpoint_count" -eq 0 || "$nonready_count" -gt 0 ]]
}

recover_kyverno() {
  heading "recover kyverno"
  if ! k -n kyverno get deploy/kyverno-admission-controller >/dev/null 2>&1; then
    echo "Kyverno deployment not found; skipping."
    return 0
  fi
  if kyverno_needs_recovery; then
    mutate -n kyverno delete pod -l app.kubernetes.io/component=admission-controller --ignore-not-found=true || true
    mutate -n kyverno delete pod -l app.kubernetes.io/component=background-controller --ignore-not-found=true || true
    mutate -n kyverno rollout status deploy/kyverno-admission-controller --timeout=180s || true
    mutate -n kyverno rollout status deploy/kyverno-background-controller --timeout=180s || true
  else
    echo "Kyverno admission/background controllers look healthy; skipping."
  fi
  k -n kyverno get pods,endpoints kyverno-svc -o wide || true
}

recover_longhorn_managers() {
  heading "recover longhorn managers"
  mutate -n longhorn-system delete pod -l app=longhorn-manager --ignore-not-found=true || true
  if ! mutate -n longhorn-system rollout status ds/longhorn-manager --timeout=240s; then
    warn "longhorn-manager rollout did not complete; nudging daemonset"
    mutate -n longhorn-system rollout restart ds/longhorn-manager || true
    mutate -n longhorn-system rollout status ds/longhorn-manager --timeout=240s || true
  fi
  k -n longhorn-system get ds longhorn-manager -o wide || true
  k -n longhorn-system get pods -l app=longhorn-manager -o wide || true
}

restart_if_exists() {
  local namespace="$1"
  local resource="$2"
  if k -n "$namespace" get "$resource" >/dev/null 2>&1; then
    mutate -n "$namespace" rollout restart "$resource" || true
    mutate -n "$namespace" rollout status "$resource" --timeout=240s || true
  else
    echo "$namespace/$resource not found; skipping."
  fi
}

recover_longhorn_csi() {
  heading "recover longhorn csi"
  restart_if_exists longhorn-system ds/longhorn-csi-plugin
  restart_if_exists longhorn-system deploy/csi-attacher
  restart_if_exists longhorn-system deploy/csi-resizer
  restart_if_exists longhorn-system deploy/csi-snapshotter
  restart_if_exists longhorn-system deploy/csi-provisioner
  restart_if_exists longhorn-system deploy/longhorn-driver-deployer
  k -n longhorn-system get pods -o wide || true
}

delete_failed_volumeattachments() {
  heading "delete failed/unattached volumeattachments"
  local names
  names="$(k get volumeattachments.storage.k8s.io -o json \
    | jq -r '.items[] | select((.status.attached != true) or (.status.attachError != null)) | .metadata.name' || true)"
  if [[ -z "$names" ]]; then
    echo "No failed/unattached VolumeAttachments found."
    return 0
  fi
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    mutate delete volumeattachments.storage.k8s.io "$name" || true
  done <<<"$names"
}

traefik_needs_recovery() {
  k -n kube-system logs -l app.kubernetes.io/name=traefik --since=30m 2>/dev/null \
    | grep -qiE 'Unauthorized|forbidden'
}

recover_traefik() {
  heading "recover traefik"
  if ! k -n kube-system get ds -l app.kubernetes.io/name=traefik -o name >/dev/null 2>&1; then
    echo "Traefik DaemonSet not found; skipping."
    return 0
  fi
  if traefik_needs_recovery; then
    for resource in $(k -n kube-system get ds -l app.kubernetes.io/name=traefik -o name); do
      mutate -n kube-system rollout restart "$resource" || true
      mutate -n kube-system rollout status "$resource" --timeout=240s || true
    done
  else
    echo "No recent Traefik Unauthorized/forbidden watcher errors; skipping."
  fi
  k -n kube-system get pods -l app.kubernetes.io/name=traefik -o wide || true
}

recover_workloads() {
  heading "recover stuck workload pods"
  local pods
  pods="$(k get pods -A -o json | jq -r '
    def allowed_ns: ["argocd","forgejo","garage","matrix","monitoring","mosquitto","nextcloud","webmutt"];
    def bad_reason: ["CrashLoopBackOff","CreateContainerError","Error","ContainerStatusUnknown","Unknown"] | index(.);
    .items[]
    | select(allowed_ns | index(.metadata.namespace))
    | select(.status.phase != "Succeeded")
    | select((.status.containerStatuses // []) | any((.ready != true) and (((.state.waiting.reason // .state.terminated.reason // "") | bad_reason) != null)))
    | [.metadata.namespace,.metadata.name] | @tsv
  ' || true)"
  if [[ -z "$pods" ]]; then
    echo "No stuck workload pods found."
    return 0
  fi
  while IFS=$'\t' read -r namespace pod; do
    [[ -n "${namespace:-}" && -n "${pod:-}" ]] || continue
    mutate -n "$namespace" delete pod "$pod" --ignore-not-found=true || true
  done <<<"$pods"
  sleep 90
}

run_recovery() {
  status_report
  recover_kyverno
  recover_longhorn_managers
  recover_longhorn_csi
  delete_failed_volumeattachments
  recover_traefik
  recover_workloads
  status_report
}

if [[ "$RECOVER" -eq 1 && "$YES" -ne 1 ]]; then
  echo "--recover requires --yes before mutating cluster resources." >&2
  planned_stages >&2
  exit 2
fi

if [[ "$RECOVER" -eq 1 ]]; then
  planned_stages
  run_recovery
else
  status_report
fi
