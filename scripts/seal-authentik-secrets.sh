#!/usr/bin/env bash
set -euo pipefail

sealed_secrets_controller_name="sealed-secrets-controller"
sealed_secrets_controller_namespace="kube-system"

authentik_namespace="authentik"
authentik_config_secret_name="authentik-config"
authentik_config_secret_path="argocd/homelab/authentik-db/authentik-config-secret.yaml"
authentik_secret_key_entry="private/login/auth.compaan-secret-key"
authentik_bootstrap_password_entry="private/login/auth.compaan-akadmin"
authentik_bootstrap_token_entry="private/login/auth.compaan-bootstrap-token"
authentik_bootstrap_email="akadmin@auth.compaan"

argocd_authentik_oidc_secret_name="argocd-authentik-oidc"
argocd_authentik_oidc_secret_path="argocd/homelab/infra/argocd-authentik-oidc-secret.yaml"
argocd_authentik_oidc_client_secret_entry="private/login/argocd.compaan-authentik-oidc"

tmpfile_to_cleanup=""

cleanup_tmpfile() {
  if [[ -n "$tmpfile_to_cleanup" ]]; then
    rm -f "$tmpfile_to_cleanup"
  fi
}
trap cleanup_tmpfile EXIT

usage() {
  printf 'Usage: %s {authentik-config|argocd-oidc}\n' "$(basename "$0")" >&2
}

read_pass_first_line() {
  local entry="$1"
  local label="$2"
  local value

  value="$(pass show "$entry" 2>/dev/null | head -n1 | tr -d '[:space:]' || true)"
  if [[ -z "$value" ]]; then
    printf 'Missing %s in pass entry %s\n' "$label" "$entry" >&2
    exit 1
  fi

  printf '%s' "$value"
}

seal_secret() {
  kubeseal \
    --kubeconfig "${KUBECONFIG:-./.kubeconfig}" \
    --controller-name "$sealed_secrets_controller_name" \
    --controller-namespace "$sealed_secrets_controller_namespace" \
    --format=yaml
}

seal_authentik_config() {
  local secret_key bootstrap_password bootstrap_token

  mkdir -p "$(dirname "$authentik_config_secret_path")"
  tmpfile_to_cleanup="$(mktemp)"

  secret_key="$(read_pass_first_line "$authentik_secret_key_entry" "Authentik secret key")"
  bootstrap_password="$(read_pass_first_line "$authentik_bootstrap_password_entry" "Authentik bootstrap password")"
  bootstrap_token="$(read_pass_first_line "$authentik_bootstrap_token_entry" "Authentik bootstrap token")"

  kubectl create secret generic "$authentik_config_secret_name" \
    --namespace "$authentik_namespace" \
    --from-literal=AUTHENTIK_SECRET_KEY="$secret_key" \
    --from-literal=AUTHENTIK_BOOTSTRAP_EMAIL="$authentik_bootstrap_email" \
    --from-literal=AUTHENTIK_BOOTSTRAP_PASSWORD="$bootstrap_password" \
    --from-literal=AUTHENTIK_BOOTSTRAP_TOKEN="$bootstrap_token" \
    --dry-run=client \
    -o yaml \
    | seal_secret \
    > "$tmpfile_to_cleanup"

  mv "$tmpfile_to_cleanup" "$authentik_config_secret_path"
  tmpfile_to_cleanup=""
}

seal_argocd_oidc() {
  local client_secret

  mkdir -p "$(dirname "$argocd_authentik_oidc_secret_path")"
  tmpfile_to_cleanup="$(mktemp)"

  client_secret="$(read_pass_first_line "$argocd_authentik_oidc_client_secret_entry" "ArgoCD Authentik OIDC client secret")"

  kubectl create secret generic "$argocd_authentik_oidc_secret_name" \
    --namespace argocd \
    --from-literal=clientSecret="$client_secret" \
    --dry-run=client \
    -o yaml \
    | kubectl label --local -f - app.kubernetes.io/part-of=argocd -o yaml \
    | seal_secret \
    > "$tmpfile_to_cleanup"

  mv "$tmpfile_to_cleanup" "$argocd_authentik_oidc_secret_path"
  tmpfile_to_cleanup=""
}

case "${1:-}" in
  authentik-config)
    seal_authentik_config
    ;;
  argocd-oidc)
    seal_argocd_oidc
    ;;
  *)
    usage
    exit 2
    ;;
esac
