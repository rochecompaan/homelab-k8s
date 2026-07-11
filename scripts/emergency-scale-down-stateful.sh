#!/usr/bin/env bash
set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG:-./.kubeconfig}"
KUBECTL_BIN="${KUBECTL:-kubectl}"
EXECUTE=0
YES=0
WAIT=1
WAIT_TIMEOUT="120s"

DEFAULT_APPS=(
  webmutt
  openclaw-mail-sync
  openclaw
  ftp
  jellyfin
  mosquitto
  coturn
  matrix
  nextcloud
  forgejo-runner
  forgejo
  redis-harbor
  harbor
  container-registry
  garage
  ziti-router
  ziti-controller
  victoria-logs
  kube-prometheus-stack
  infra
)

DEFAULT_NAMESPACES=(
  webmutt
  openclaw
  ftp
  jellyfin
  mosquitto
  matrix
  nextcloud
  forgejo
  harbor
  garage
  openziti
  victoria-logs
  monitoring
  home-assistant
)

APPS=()
NAMESPACES=()

usage() {
  cat <<'USAGE'
Usage: scripts/emergency-scale-down-stateful.sh [options]

Break-glass helper for UPS/power-loss emergencies. By default this is a dry-run
and prints the planned ArgoCD pause + workload scale-down actions without
calling kubectl.

Options:
  --execute              Run mutating kubectl commands. Requires --yes.
  --yes                  Confirm break-glass cluster mutation.
  --app NAME             Limit/pick an ArgoCD Application to pause. Repeatable.
  --namespace NAME       Limit/pick a namespace to scale. Repeatable.
  --no-wait              Do not wait for rollout status after scaling to zero.
  --wait-timeout VALUE   Rollout wait timeout. Default: 120s.
  -h, --help             Show this help.

Environment:
  KUBECONFIG             Kubeconfig path. Default: ./.kubeconfig
  KUBECTL                kubectl binary. Default: kubectl

What it does in --execute mode:
  1. Removes spec.syncPolicy.automated from target ArgoCD Applications so
     self-heal does not immediately undo emergency scaling.
  2. Scales all Deployments and StatefulSets in target namespaces to 0.
  3. Hibernates CloudNativePG clusters found in target namespaces by setting
     cnpg.io/hibernation=on.

After power is stable, re-enable ArgoCD automation/sync from Git and turn
CloudNativePG hibernation off before restoring workloads.
USAGE
}

while (($#)); do
  case "$1" in
    --execute) EXECUTE=1 ;;
    --yes) YES=1 ;;
    --app)
      [[ $# -ge 2 ]] || { echo "--app requires a value" >&2; exit 64; }
      APPS+=("$2")
      shift
      ;;
    --namespace)
      [[ $# -ge 2 ]] || { echo "--namespace requires a value" >&2; exit 64; }
      NAMESPACES+=("$2")
      shift
      ;;
    --no-wait) WAIT=0 ;;
    --wait-timeout)
      [[ $# -ge 2 ]] || { echo "--wait-timeout requires a value" >&2; exit 64; }
      WAIT_TIMEOUT="$2"
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 64 ;;
  esac
  shift
done

if [[ ${#APPS[@]} -eq 0 ]]; then
  APPS=("${DEFAULT_APPS[@]}")
fi

if [[ ${#NAMESPACES[@]} -eq 0 ]]; then
  NAMESPACES=("${DEFAULT_NAMESPACES[@]}")
fi

if [[ "$EXECUTE" -eq 1 && "$YES" -ne 1 ]]; then
  echo "--execute requires --yes before mutating cluster resources." >&2
  exit 2
fi

quote_command() {
  printf '+ '
  printf '%q ' "$@"
  printf '\n'
}

k() {
  "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" "$@"
}

run_cmd() {
  quote_command "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" "$@"
  if [[ "$EXECUTE" -eq 1 ]]; then
    k "$@"
  fi
}

warn() {
  printf 'warning: %s\n' "$*" >&2
}

heading() {
  printf '\n## %s\n' "$1"
}

pause_argocd_app() {
  local app="$1"
  local patch='{"spec":{"syncPolicy":{"automated":null}}}'

  if [[ "$EXECUTE" -eq 1 ]]; then
    if ! k -n argocd get application "$app" >/dev/null 2>&1; then
      warn "argocd application not found; skipping pause: $app"
      return 0
    fi
  fi

  run_cmd -n argocd patch application "$app" --type=merge -p "$patch" || \
    warn "failed to pause argocd application: $app"
}

namespace_exists() {
  local namespace="$1"
  k get namespace "$namespace" >/dev/null 2>&1
}

scale_namespace_to_zero() {
  local namespace="$1"

  if [[ "$EXECUTE" -eq 1 ]] && ! namespace_exists "$namespace"; then
    warn "namespace not found; skipping scale-down: $namespace"
    return 0
  fi

  run_cmd -n "$namespace" scale deployment,statefulset --all --replicas=0 || \
    warn "failed to scale Deployments/StatefulSets in namespace: $namespace"

  if [[ "$WAIT" -eq 1 ]]; then
    run_cmd -n "$namespace" rollout status deployment --all --timeout="$WAIT_TIMEOUT" || true
    run_cmd -n "$namespace" rollout status statefulset --all --timeout="$WAIT_TIMEOUT" || true
  fi
}

hibernate_cnpg_clusters() {
  local namespace="$1"
  local clusters cluster name

  if [[ "$EXECUTE" -ne 1 ]]; then
    quote_command "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" -n "$namespace" annotate clusters.postgresql.cnpg.io '<cluster>' cnpg.io/hibernation=on --overwrite
    return 0
  fi

  if ! namespace_exists "$namespace"; then
    return 0
  fi

  clusters="$(k -n "$namespace" get clusters.postgresql.cnpg.io -o name 2>/dev/null || true)"
  [[ -n "$clusters" ]] || return 0

  while IFS= read -r cluster; do
    [[ -n "$cluster" ]] || continue
    name="${cluster#*/}"
    run_cmd -n "$namespace" annotate clusters.postgresql.cnpg.io "$name" cnpg.io/hibernation=on --overwrite || \
      warn "failed to hibernate CloudNativePG cluster: $namespace/$name"
  done <<<"$clusters"
}

main() {
  if [[ "$EXECUTE" -eq 1 ]]; then
    echo "BREAK-GLASS EXECUTE: mutating cluster resources via $KUBECTL_BIN"
  else
    echo "DRY-RUN: no kubectl commands will be executed. Add --execute --yes to run."
  fi

  heading "pause argocd self-heal for target apps"
  for app in "${APPS[@]}"; do
    pause_argocd_app "$app"
  done

  heading "scale deployments/statefulsets to zero"
  for namespace in "${NAMESPACES[@]}"; do
    scale_namespace_to_zero "$namespace"
  done

  heading "hibernate cloudnative-pg clusters"
  for namespace in "${NAMESPACES[@]}"; do
    hibernate_cnpg_clusters "$namespace"
  done

  heading "next step"
  cat <<'NEXT'
If UPS time is still low, shut down nodes now:
  workers first:       sudo shutdown -h now
  control-plane last:  sudo shutdown -h now

After power returns, re-enable ArgoCD automation/sync from Git and unhibernate
CloudNativePG clusters before scaling workloads back up.
NEXT
}

main
