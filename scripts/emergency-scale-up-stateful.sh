#!/usr/bin/env bash
set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG:-./.kubeconfig}"
KUBECTL_BIN="${KUBECTL:-kubectl}"
EXECUTE=0
YES=0
WAIT=1
WAIT_TIMEOUT="600s"

DEFAULT_APPS=(
  infra
  garage
  redis-harbor
  harbor
  container-registry
  nextcloud-db
  nextcloud
  matrix-whatsapp
  matrix
  forgejo
  forgejo-runner
  mosquitto
  jellyfin
  ftp
  openclaw-mail-sync
  openclaw
  webmutt
  coturn
  ziti-controller
  ziti-router
  victoria-logs
  kube-prometheus-stack
)

DEFAULT_NAMESPACES=(
  nextcloud
  matrix
  garage
  harbor
  forgejo
  mosquitto
  jellyfin
  ftp
  openclaw
  webmutt
  openziti
  victoria-logs
  monitoring
  home-assistant
)

NO_PRUNE_SELF_HEAL_APPS=(
  kube-prometheus-stack
)

APPS=()
NAMESPACES=()

usage() {
  cat <<'USAGE'
Usage: scripts/emergency-scale-up-stateful.sh [options]

Break-glass helper to recover after scripts/emergency-scale-down-stateful.sh.
By default this is a dry-run and prints planned actions without calling kubectl.

Options:
  --execute              Run mutating kubectl commands. Requires --yes.
  --yes                  Confirm break-glass cluster mutation.
  --app NAME             Limit/pick an ArgoCD Application to restore. Repeatable.
  --namespace NAME       Limit/pick a namespace to unhibernate CNPG in. Repeatable.
  --no-wait              Do not wait for CloudNativePG clusters to become Ready.
  --wait-timeout VALUE   Wait timeout for CloudNativePG clusters. Default: 600s.
  -h, --help             Show this help.

Environment:
  KUBECONFIG             Kubeconfig path. Default: ./.kubeconfig
  KUBECTL                kubectl binary. Default: kubectl

What it does in --execute mode:
  1. Removes cnpg.io/hibernation from CloudNativePG clusters in target
     namespaces so databases can start first.
  2. Re-enables ArgoCD automated sync for target Applications. Most apps are
     restored with prune/selfHeal; kube-prometheus-stack is restored to the
     repository's automated: {} behavior.
  3. Requests a hard ArgoCD refresh so restored automation reconciles Git state.

This script does not directly scale application workloads up. ArgoCD should do
that from the committed manifests after automation is restored.
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

contains() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

namespace_exists() {
  local namespace="$1"
  k get namespace "$namespace" >/dev/null 2>&1
}

app_exists() {
  local app="$1"
  k -n argocd get application "$app" >/dev/null 2>&1
}

restore_argocd_app() {
  local app="$1"
  local patch

  if contains "$app" "${NO_PRUNE_SELF_HEAL_APPS[@]}"; then
    patch='{"spec":{"syncPolicy":{"automated":{}}}}'
  else
    patch='{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'
  fi

  if [[ "$EXECUTE" -eq 1 ]]; then
    if ! app_exists "$app"; then
      warn "argocd application not found; skipping restore: $app"
      return 0
    fi
  fi

  run_cmd -n argocd patch application "$app" --type=merge -p "$patch" || \
    warn "failed to restore argocd automation for application: $app"
  run_cmd -n argocd annotate application "$app" argocd.argoproj.io/refresh=hard --overwrite || \
    warn "failed to request hard refresh for application: $app"
}

cnpg_clusters() {
  local namespace="$1"
  k -n "$namespace" get clusters.postgresql.cnpg.io -o name 2>/dev/null || true
}

unhibernate_cnpg_clusters() {
  local namespace="$1"
  local clusters cluster name

  if [[ "$EXECUTE" -ne 1 ]]; then
    quote_command "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" -n "$namespace" annotate clusters.postgresql.cnpg.io '<cluster>' cnpg.io/hibernation- --overwrite
    if [[ "$WAIT" -eq 1 ]]; then
      quote_command "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" -n "$namespace" wait --for=condition=Ready clusters.postgresql.cnpg.io --all --timeout="$WAIT_TIMEOUT"
    fi
    return 0
  fi

  if ! namespace_exists "$namespace"; then
    warn "namespace not found; skipping CNPG unhibernate: $namespace"
    return 0
  fi

  clusters="$(cnpg_clusters "$namespace")"
  [[ -n "$clusters" ]] || return 0

  while IFS= read -r cluster; do
    [[ -n "$cluster" ]] || continue
    name="${cluster#*/}"
    run_cmd -n "$namespace" annotate clusters.postgresql.cnpg.io "$name" cnpg.io/hibernation- --overwrite || \
      warn "failed to unhibernate CloudNativePG cluster: $namespace/$name"
  done <<<"$clusters"

  if [[ "$WAIT" -eq 1 ]]; then
    run_cmd -n "$namespace" wait --for=condition=Ready clusters.postgresql.cnpg.io --all --timeout="$WAIT_TIMEOUT" || \
      warn "CloudNativePG clusters did not report Ready before timeout in namespace: $namespace"
  fi
}

print_status_commands() {
  cat <<'NEXT'
Useful follow-up checks:
  kubectl get nodes
  kubectl -n longhorn-system get volumes.longhorn.io
  kubectl -n argocd get applications.argoproj.io
  kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded

If an app does not come back after automation is restored, inspect it with:
  kubectl -n argocd describe application <app>
NEXT
}

main() {
  if [[ "$EXECUTE" -eq 1 ]]; then
    echo "BREAK-GLASS EXECUTE: mutating cluster resources via $KUBECTL_BIN"
  else
    echo "DRY-RUN: no kubectl commands will be executed. Add --execute --yes to run."
  fi

  heading "unhibernate cloudnative-pg clusters"
  for namespace in "${NAMESPACES[@]}"; do
    unhibernate_cnpg_clusters "$namespace"
  done

  heading "restore argocd automation and request refresh"
  for app in "${APPS[@]}"; do
    restore_argocd_app "$app"
  done

  heading "next checks"
  print_status_commands
}

main
