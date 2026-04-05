set shell := ["bash", "-euo", "pipefail", "-c"]

gmail_username_entry := "GMAIL_MAIL_SYNC_USERNAME"
gmail_webmutt_app_password_entry := "GMAIL_WEBMUTT_MAIL_SYNC"
gmail_openclaw_app_password_entry := "GMAIL_OPENCLAW_MAIL_SYNC"
argocd_server := "argocd.compaan"
argocd_username := "admin"
argocd_password_entry := "private/login/argocd.compaan-login-admin"
argocd_chart_version := "9.1.6"
argocd_root_app_name := "root"
argocd_root_app_path := "argocd/homelab/apps"
argocd_repo_secret_name := "github-repo-secret"
github_repo := "rochecompaan/homelab-k8s"
github_repo_ssh_url := "git@github.com:rochecompaan/homelab-k8s.git"
github_deploy_key_title := "homelab-k8s ArgoCD GitHub Deploy Key"
argocd_github_deploy_key_entry := "private/git/homelab-k8s-argocd-deploy-key"
forgejo_admin_username := "roche"
forgejo_admin_password_entry := "private/login/git.compaan-admin"
openziti_controller_url := "https://ctrl.compaan.cloud/edge/management/v1"
openziti_login_controller := "ctrl.compaan.cloud:443"
openziti_username := "admin"
openziti_password_entry := "private/login/zac-ctrl.compaan.cloud-admin"
matrix_namespace := "matrix"
matrix_deployment := "matrix"
matrix_internal_url := "http://localhost:8008"
matrix_public_url := "https://matrix.compaan"
openclaw_namespace := "openclaw"
openclaw_secret_name := "openclaw-env-secret"
openclaw_secret_path := "argocd/homelab/infra/openclaw-secret.yaml"

default:
  @just --list

mail-secrets: seal-webmutt-secret seal-openclaw-mail-secret

seal-webmutt-secret:
  kubectl create secret generic webmutt-gmail-secret \
    --namespace webmutt \
    --from-literal=GMAIL_ADDRESS="$(pass show {{gmail_username_entry}} | head -n1 | tr -d '[:space:]')" \
    --from-literal=GMAIL_APP_PASSWORD="$(pass show {{gmail_webmutt_app_password_entry}} | head -n1 | tr -d '[:space:]')" \
    --dry-run=client \
    -o yaml \
    | kubeseal --format=yaml \
    > argocd/homelab/webmutt/secret.yaml

seal-openclaw-mail-secret:
  kubectl create secret generic webmutt-gmail-secret \
    --namespace openclaw \
    --from-literal=GMAIL_ADDRESS="$(pass show {{gmail_username_entry}} | head -n1 | tr -d '[:space:]')" \
    --from-literal=GMAIL_APP_PASSWORD="$(pass show {{gmail_openclaw_app_password_entry}} | head -n1 | tr -d '[:space:]')" \
    --dry-run=client \
    -o yaml \
    | kubeseal --format=yaml \
    > argocd/homelab/openclaw-mail-sync/secret.yaml

seal-matrix-secret:
  mkdir -p argocd/homelab/infra; \
  tmpdir="$(mktemp -d)"; \
  trap 'rm -rf "$tmpdir"' EXIT; \
  form_secret="$(openssl rand -base64 48 | tr -d '\n')"; \
  macaroon_secret_key="$(openssl rand -base64 48 | tr -d '\n')"; \
  registration_shared_secret="$(openssl rand -base64 48 | tr -d '\n')"; \
  signing_key_id="a_$(openssl rand -hex 4)"; \
  signing_key_seed="$(openssl rand -base64 32 | tr -d '\n')"; \
  printf 'ed25519 %s %s\n' "$signing_key_id" "$signing_key_seed" > "$tmpdir/signing.key"; \
  kubectl create secret generic matrix \
    --namespace matrix \
    --from-file=signing.key="$tmpdir/signing.key" \
    --from-literal=form_secret="$form_secret" \
    --from-literal=macaroon_secret_key="$macaroon_secret_key" \
    --from-literal=registration_shared_secret="$registration_shared_secret" \
    --dry-run=client \
    -o yaml \
    | kubeseal --format=yaml \
    > argocd/homelab/infra/matrix-secret.yaml

seal-forgejo-admin-secret:
  mkdir -p argocd/homelab/forgejo/bootstrap; \
  username="${FORGEJO_ADMIN_USERNAME:-{{forgejo_admin_username}}}"; \
  password="${FORGEJO_ADMIN_PASSWORD:-$(pass show {{forgejo_admin_password_entry}} | head -n1 | tr -d '[:space:]' || true)}"; \
  if [[ -z "$password" ]]; then \
    password="$(openssl rand -base64 32 | tr -d '\n')"; \
  fi; \
  printf '%s\n' \
    'apiVersion: kustomize.config.k8s.io/v1beta1' \
    'kind: Kustomization' \
    'resources:' \
    '  - oci-repository.yaml' \
    '  - admin-secret.yaml' \
    > argocd/homelab/forgejo/bootstrap/kustomization.yaml; \
  kubectl create secret generic forgejo-admin \
    --namespace forgejo \
    --from-literal="username=$username" \
    --from-literal="password=$password" \
    --dry-run=client \
    -o yaml \
    | kubeseal --format=yaml \
    > argocd/homelab/forgejo/bootstrap/admin-secret.yaml

matrix-create-user username password:
  password="$(printf '%s' {{ quote(password) }} | tr -d '\r')"; \
  kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" \
    -n {{matrix_namespace}} \
    exec deploy/{{matrix_deployment}} -- \
    register_new_matrix_user \
      -c /tmp/synapse.yaml \
      -u {{ quote(username) }} \
      -p "$password" \
      --no-admin \
      --exists-ok \
      {{matrix_internal_url}}

matrix-create-access-token username password device="openclaw":
  password="$(printf '%s' {{ quote(password) }} | tr -d '\r')"; \
  payload="$(jq -nc \
    --arg user {{ quote(username) }} \
    --arg password "$password" \
    --arg device {{ quote(device) }} \
    '{type: "m.login.password", identifier: {type: "m.id.user", user: $user}, password: $password, initial_device_display_name: $device}')"; \
  tmpfile="$(mktemp)"; \
  trap 'rm -f "$tmpfile"' EXIT; \
  status="$(curl -skS -o "$tmpfile" -w '%{http_code}' {{matrix_public_url}}/_matrix/client/v3/login \
    -H 'Content-Type: application/json' \
    --data "$payload")"; \
  if [[ "$status" != "200" ]]; then \
    echo "Matrix login failed for {{username}} (HTTP $status)" >&2; \
    cat "$tmpfile" >&2; \
    exit 1; \
  fi; \
  jq -er '.access_token' < "$tmpfile"

seal-openclaw-secret matrix_access_token:
  mkdir -p "$(dirname {{quote(openclaw_secret_path)}})"; \
  matrix_access_token={{ quote(matrix_access_token) }}; \
  [[ -n "$matrix_access_token" ]] || { echo "Refusing to seal empty MATRIX_ACCESS_TOKEN" >&2; exit 1; }; \
  openrouter_api_key="${OPENROUTER_API_KEY:-$(kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n {{openclaw_namespace}} get secret {{openclaw_secret_name}} -o jsonpath='{.data.OPENROUTER_API_KEY}' | base64 -d)}"; \
  openclaw_gateway_token="${OPENCLAW_GATEWAY_TOKEN:-$(kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n {{openclaw_namespace}} get secret {{openclaw_secret_name}} -o jsonpath='{.data.OPENCLAW_GATEWAY_TOKEN}' | base64 -d)}"; \
  kubectl create secret generic {{openclaw_secret_name}} \
    --namespace {{openclaw_namespace}} \
    --from-literal="OPENROUTER_API_KEY=$openrouter_api_key" \
    --from-literal="OPENCLAW_GATEWAY_TOKEN=$openclaw_gateway_token" \
    --from-literal="MATRIX_ACCESS_TOKEN=$matrix_access_token" \
    --dry-run=client \
    -o yaml \
    | kubeseal --format=yaml \
    > {{openclaw_secret_path}}

seal-openclaw-matrix-token username password device="openclaw":
  matrix_access_token="$(just --quiet matrix-create-access-token {{ quote(username) }} {{ quote(password) }} device={{ quote(device) }})"; \
  just seal-openclaw-secret "$matrix_access_token"

generate-github-deploy-key:
  tmpdir="$(mktemp -d)"; \
  trap 'rm -rf "$tmpdir"' EXIT; \
  ssh-keygen -t ed25519 -f "$tmpdir/id_ed25519" -q -N ""; \
  pass insert -m -f {{argocd_github_deploy_key_entry}} < "$tmpdir/id_ed25519"

add-github-deploy-key:
  key_id="$(gh repo deploy-key list --repo {{github_repo}} | awk -F '\t' '$2 == "{{github_deploy_key_title}}" { print $1 }' | head -n1)"; \
  if [[ -n "$key_id" ]]; then \
    gh repo deploy-key delete "$key_id" --repo {{github_repo}}; \
  fi; \
  tmpdir="$(mktemp -d)"; \
  trap 'rm -rf "$tmpdir"' EXIT; \
  pass show {{argocd_github_deploy_key_entry}} > "$tmpdir/id_ed25519"; \
  chmod 600 "$tmpdir/id_ed25519"; \
  ssh-keygen -y -f "$tmpdir/id_ed25519" > "$tmpdir/id_ed25519.pub"; \
  gh repo deploy-key add "$tmpdir/id_ed25519.pub" \
    --title "{{github_deploy_key_title}}" \
    --repo {{github_repo}}

install-argocd version=argocd_chart_version:
  helm repo add argocd https://argoproj.github.io/argo-helm
  helm repo update argocd
  helm upgrade --install argocd argo-cd \
    --repo https://argoproj.github.io/argo-helm \
    --version {{version}} \
    --namespace argocd \
    --create-namespace \
    --set configs.params.server.insecure=true

show-github-deploy-key-pub:
  tmpdir="$(mktemp -d)"; \
  trap 'rm -rf "$tmpdir"' EXIT; \
  pass show {{argocd_github_deploy_key_entry}} > "$tmpdir/id_ed25519"; \
  chmod 600 "$tmpdir/id_ed25519"; \
  ssh-keygen -y -f "$tmpdir/id_ed25519"

create-repository-secret:
  tmpdir="$(mktemp -d)"; \
  trap 'rm -rf "$tmpdir"' EXIT; \
  pass show {{argocd_github_deploy_key_entry}} > "$tmpdir/id_ed25519"; \
  chmod 600 "$tmpdir/id_ed25519"; \
  kubectl -n argocd create secret generic {{argocd_repo_secret_name}} \
    --from-literal=type=git \
    --from-literal=url={{github_repo_ssh_url}} \
    --from-literal=project=default \
    --from-file=sshPrivateKey="$tmpdir/id_ed25519" \
    --from-literal=depth=1 \
    --dry-run=client -o yaml \
    | kubectl apply -f -; \
  kubectl -n argocd label secret {{argocd_repo_secret_name}} \
    argocd.argoproj.io/secret-type=repository \
    --overwrite

create-github-webhook-secret:
  : "${ARGOCD_GITHUB_ACCESS_TOKEN:?Set ARGOCD_GITHUB_ACCESS_TOKEN}"; \
  kubectl -n argocd create secret generic github-token \
    --from-literal=token="$ARGOCD_GITHUB_ACCESS_TOKEN" \
    --dry-run=client -o yaml \
    | kubectl apply -f -

bootstrap-root-app:
  printf '%s\n' \
    'apiVersion: argoproj.io/v1alpha1' \
    'kind: Application' \
    'metadata:' \
    '  name: {{argocd_root_app_name}}' \
    '  namespace: argocd' \
    '  finalizers:' \
    '    - resources-finalizer.argocd.argoproj.io' \
    '  labels:' \
    '    app.kubernetes.io/name: {{argocd_root_app_name}}' \
    'spec:' \
    '  project: default' \
    '  source:' \
    '    repoURL: {{github_repo_ssh_url}}' \
    '    targetRevision: main' \
    '    path: {{argocd_root_app_path}}' \
    '  destination:' \
    '    server: https://kubernetes.default.svc' \
    '    namespace: argocd' \
    '  syncPolicy:' \
    '    automated:' \
    '      prune: true' \
    '      selfHeal: true' \
    '    syncOptions:' \
    '      - allowEmpty=true' \
    | kubectl apply -f -

bootstrap version=argocd_chart_version:
  just install-argocd version="{{version}}"
  just generate-github-deploy-key
  just add-github-deploy-key
  just create-repository-secret
  just bootstrap-root-app

argocd-login:
  argocd login {{argocd_server}} \
    --username {{argocd_username}} \
    --password "$(pass show {{argocd_password_entry}} | head -1)"

argocd-sync app="root": argocd-login
  argocd app sync {{app}}

ziti-edge-login:
  ziti edge login {{openziti_login_controller}} \
    -u "{{openziti_username}}" \
    -p "$(pass show {{openziti_password_entry}} | head -n1)"

seal-openziti-management-secret: ziti-edge-login
  mkdir -p argocd/homelab/miniziti-operator; \
  controller_url="${OPENZITI_CONTROLLER_URL:-{{openziti_controller_url}}}"; \
  username="${OPENZITI_USERNAME:-{{openziti_username}}}"; \
  password="${OPENZITI_PASSWORD:-$(pass show {{openziti_password_entry}} | head -n1 | tr -d '[:space:]')}"; \
  args=(create secret generic openziti-management \
    --namespace ziti \
    --from-literal="controllerUrl=$controller_url" \
    --from-literal="username=$username" \
    --from-literal="password=$password" \
    --dry-run=client \
    -o yaml); \
  if [[ -n "${OPENZITI_CA_BUNDLE_FILE:-}" ]]; then \
    args+=(--from-file="caBundle=${OPENZITI_CA_BUNDLE_FILE}"); \
  fi; \
  kubectl "${args[@]}" \
    | kubeseal --format=yaml \
    > argocd/homelab/miniziti-operator/openziti-management-secret.yaml
