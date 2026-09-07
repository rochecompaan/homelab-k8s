# compaan.cloud Mail Server Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Self-host send/receive for compaan.cloud mailboxes on the homelab cluster: exim on 25+587, dovecot IMAPS on 993, DKIM-signed direct outbound.

**Architecture:** The `mail-exim` and `mail-dovecot` Deployments run one replica each in the `mail` namespace. They share the RWX `mail-storage` `longhorn-sata` PVC for Maildirs. `mail-exim` also mounts the dedicated RWO `mail-exim-spool` `longhorn-sata` PVC at `/var/spool/exim4`. An init container resolves the `Debian-exim` user and group. It sets spool ownership before Exim starts. A hashed ConfigMap supplies config and rolls out config edits declaratively. SealedSecrets mount as directories, so rotations do not restart pods. Dedicated NodePorts 30025/30587/30993 are behind router port-forwards. A `letsencrypt-prod` Certificate supplies TLS for `homelab.compaan.cloud`. Add `mail` to traefik-public's watched Ingress namespaces.

**Tech Stack:** Kubernetes + Kustomize, ArgoCD (GitOps-only), Exim 4 (exim4-daemon-heavy on Debian bookworm), Dovecot 2.3 (bookworm), cert-manager (Let's Encrypt HTTP-01), Sealed Secrets (kubeseal), Harbor at `harbor.compaan` (private, via Ziti), `just` + `pass` + `openssl` for local secret tooling.

**Spec:** `docs/specs/2026-08-15-compaan-cloud-mail-design.md`
**Prerequisite spec (Harbor):** `docs/specs/2026-08-15-harbor-registry-design.md`

## Global Constraints

- **GitOps-only:** no direct cluster mutations (`kubectl apply/patch/delete`, `helm upgrade`). All `kubectl` in recipes is `--dry-run=client` (local manifest generation); `kubeseal` only fetches the controller's public cert (read-only).
- **Secrets:** commit SealedSecret ciphertext only. Plaintext lives in `pass` and mode-0600/0700 temp files removed on exit. Never in shell history, command lines, chat, or git.
- **Commits:** Conventional Commits, signed, hooks never bypassed (escalate sandbox instead).
- **Testing Value Gate:** this is static configuration — no new automated tests. Every task has a direct verification step instead.
- **Image tags:** pinned, no `latest`. Both mail images use tag `2026-08-15` initially; bump the tag in `kustomization.yaml` whenever the Dockerfiles change.
- **Naming:** namespace `mail`; hostname `homelab.compaan.cloud`; DKIM selector `mail`; `mail-storage` PVC (RWX, `longhorn-sata`, 50Gi); `mail-exim-spool` PVC (RWO, `longhorn-sata`, 5Gi); NodePorts 30025 (smtp), 30587 (submission), 30993 (imaps).
- **One-way door:** do not merge to `main` until images are pushed to Harbor (Task 8); otherwise pods ImagePullBackOff on sync.
- Spec deviation (accepted): two SealedSecret files (`mail-auth-sealed-secret.yaml`, `mail-dkim-sealed-secret.yaml`) instead of one `sealed-secrets.yaml` — matches the Forgejo one-file-per-recipe pattern.

---

### Task 1: Container images for exim and dovecot

**Files:**
- Create: `docker/mail/exim/Dockerfile`
- Create: `docker/mail/exim/exim-entrypoint.sh`
- Create: `docker/mail/dovecot/Dockerfile`

**Interfaces:**
- Produces: local images built as `mail-exim:dev` / `mail-dovecot:dev` for Task 2–3 verification; Deployment image names `exim` and `dovecot` (Task 5) rewritten by kustomize to `harbor.compaan/mail/exim:2026-08-15` / `harbor.compaan/mail/dovecot:2026-08-15` (Task 8 pushes exactly those tags).
- Produces: exim container expects config at `/etc/exim4/exim.conf`, auth at `/etc/exim4/auth/passwd`, DKIM key at `/etc/exim4/dkim/dkim.private`, TLS at `/etc/exim4/tls/{tls.crt,tls.key}`, mailstore at `/var/mail/vmail`.
- Produces: dovecot container expects config at `/etc/dovecot/dovecot.conf`, auth at `/etc/dovecot/auth/passwd-dovecot`, TLS at `/etc/dovecot/tls/{tls.crt,tls.key}`, mailstore at `/var/mail/vmail`.

- [ ] **Step 1: Write `docker/mail/exim/Dockerfile`**

```dockerfile
FROM debian:bookworm-slim

COPY exim-entrypoint.sh /usr/local/bin/exim-entrypoint

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates \
      exim4-daemon-heavy \
      tini \
    && groupadd --gid 5000 vmail \
    && useradd --uid 5000 --gid 5000 --home-dir /var/mail/vmail --shell /usr/sbin/nologin vmail \
    && mkdir -p /var/mail/vmail /var/spool/exim4 /var/log/exim4 \
    && chown -R vmail:vmail /var/mail/vmail \
    && chown -R Debian-exim:Debian-exim /var/spool/exim4 \
    && chmod 0755 /usr/local/bin/exim-entrypoint \
    && rm -rf /var/lib/apt/lists/*

EXPOSE 25 587
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/exim-entrypoint"]
CMD ["-bd", "-q30m", "-C", "/etc/exim4/exim.conf"]
```

- [ ] **Step 2: Write `docker/mail/exim/exim-entrypoint.sh`**

Copy verbatim from the mycity project: `~/projects/mycity/exim/exim-entrypoint.sh`. It turns `-bd` into `-bdf`, tails `/var/log/exim4/mainlog` to stdout and `rejectlog`/`paniclog` to stderr, and terminates cleanly on SIGTERM. Then `chmod 0755 docker/mail/exim/exim-entrypoint.sh`.

- [ ] **Step 3: Write `docker/mail/dovecot/Dockerfile`**

```dockerfile
FROM debian:bookworm-slim

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates \
      dovecot-imapd \
      openssl \
      tini \
    && groupadd --gid 5000 vmail \
    && useradd --uid 5000 --gid 5000 --home-dir /var/mail/vmail --shell /usr/sbin/nologin vmail \
    && mkdir -p /var/mail/vmail \
    && chown -R vmail:vmail /var/mail/vmail \
    && rm -rf /var/lib/apt/lists/*

EXPOSE 993
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/usr/sbin/dovecot", "-F", "-c", "/etc/dovecot/dovecot.conf"]
```

- [ ] **Step 4: Build both images**

Run:
```bash
docker build -t mail-exim:dev docker/mail/exim
docker build -t mail-dovecot:dev docker/mail/dovecot
```
Expected: both build with no errors.

- [ ] **Step 5: Commit**

```bash
git add docker/mail
git commit -m "feat(mail): add exim and dovecot container images"
```

---

### Task 2: Exim configuration

**Files:**
- Create: `argocd/homelab/mail/exim.conf`
- Create: `argocd/homelab/mail/aliases`
- Create: `docker/mail/exim/test-smtp-auth.sh`

**Interfaces:**
- Consumes: image `mail-exim:dev` and its container paths from Task 1.
- Produces: config referenced by ConfigMap `mail-config` keys `exim.conf`, `aliases` (Task 5); routing contract: `postmaster|abuse|dmarc@compaan.cloud` → `roche@compaan.cloud`; `<user>@compaan.cloud` (present in `/etc/exim4/auth/passwd`) → Maildir `/var/mail/vmail/compaan.cloud/<user>/Maildir`; other local parts → `:fail:`; non-local → DKIM-signed DNS delivery.

- [ ] **Step 1: Write `argocd/homelab/mail/exim.conf`**

```
######################################################################
# compaan.cloud homelab Exim config (k8s)
######################################################################

primary_hostname = homelab.compaan.cloud

daemon_smtp_ports = 25 : 587
smtp_enforce_sync = false
smtp_accept_max = 100

tls_certificate = /etc/exim4/tls/tls.crt
tls_privatekey = /etc/exim4/tls/tls.key
tls_advertise_hosts = *

# Offer AUTH only after STARTTLS.
auth_advertise_hosts = ${if eq{$tls_in_cipher}{}{}{*}}

domainlist local_domains = compaan.cloud

acl_smtp_rcpt = acl_check_rcpt

begin acl

acl_check_rcpt:
  accept hosts = :

  deny message = No such user
       domains = +local_domains
       !verify = recipient

  accept authenticated = *
         control = submission/sender_retain

  require message = relay not permitted
          domains = +local_domains

  require verify = recipient

  accept

begin routers

aliases:
  driver = redirect
  domains = +local_domains
  data = ${lookup{$local_part}lsearch{/etc/exim4/aliases}{$value}fail}

local_users:
  driver = accept
  domains = +local_domains
  address_data = ${lookup{$local_part@$domain}lsearch{/etc/exim4/auth/passwd}{$value}{}}
  condition = ${lookup{$local_part@$domain}lsearch{/etc/exim4/auth/passwd}{yes}{}}
  transport = local_maildir

unknown_local:
  driver = redirect
  domains = +local_domains
  allow_fail
  data = :fail: No such user

dnslookup:
  driver = dnslookup
  domains = ! +local_domains
  transport = remote_smtp_dkim
  no_more

begin transports

local_maildir:
  driver = appendfile
  directory = /var/mail/vmail/$domain/$local_part/Maildir
  create_directory
  maildir_format
  user = vmail
  mode = 0660

remote_smtp_dkim:
  driver = smtp
  dkim_domain = compaan.cloud
  dkim_selector = mail
  dkim_private_key = /etc/exim4/dkim/dkim.private
  dkim_canon = relaxed

begin authenticators

plain_server:
  driver = plaintext
  public_name = PLAIN
  server_condition = ${if crypteq{$auth3}{${lookup{$auth2}lsearch{/etc/exim4/auth/passwd}{$value}fail}}{1}{0}}
  server_set_id = $auth2
  server_prompts = :

login_server:
  driver = plaintext
  public_name = LOGIN
  server_prompts = Username:: : Password::
  server_condition = ${if crypteq{$auth2}{${lookup{$auth1}lsearch{/etc/exim4/auth/passwd}{$value}fail}}{1}{0}}
  server_set_id = $auth1
```

- [ ] **Step 2: Write `argocd/homelab/mail/aliases`**

```
postmaster: roche@compaan.cloud
abuse: roche@compaan.cloud
dmarc: roche@compaan.cloud
```

- [ ] **Step 3: Validate config syntax and routing in the Task 1 image**

Run:
```bash
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
printf 'roche@compaan.cloud:$6$dummyhash\n' > "$tmp/passwd"
cp argocd/homelab/mail/aliases "$tmp/aliases"
run_exim() {
  docker run --rm --entrypoint /bin/sh \
    -v "$PWD/argocd/homelab/mail/exim.conf:/mnt/exim.conf:ro" \
    -v "$tmp/passwd:/etc/exim4/auth/passwd:ro" \
    -v "$tmp/aliases:/etc/exim4/aliases:ro" \
    mail-exim:dev -c 'cp /mnt/exim.conf /tmp/exim.conf && exec /usr/sbin/exim4 -C /tmp/exim.conf "$@"' exim4 "$@"
}
run_exim -bV
```
The root-owned in-container copy is required because Exim does not trust a
host-owned bind-mounted configuration file. Expected: version banner and build
info, no syntax errors (non-zero exit = fix the config).

- [ ] **Step 4: Verify routing decisions**

Run:
```bash
run_exim -bt postmaster@compaan.cloud
```
Expected: `postmaster@compaan.cloud` → `roche@compaan.cloud` routed by
`local_users`, transport `local_maildir`.

Repeat with `run_exim -bt nobody@compaan.cloud`:
Expected: `unknown_local` router, `:fail: No such user` (Exim exits non-zero
for this expected rejected address).

Repeat with `run_exim -bt someone@gmail.com`:
Expected: `dnslookup` router, transport `remote_smtp_dkim`.

Verify SMTP recipient rejection and pre-TLS AUTH using the same temporary
fixtures:
```bash
run_smtp() {
  docker run --rm -i --entrypoint /bin/sh \
    -v "$PWD/argocd/homelab/mail/exim.conf:/mnt/exim.conf:ro" \
    -v "$tmp/passwd:/etc/exim4/auth/passwd:ro" \
    -v "$tmp/aliases:/etc/exim4/aliases:ro" \
    mail-exim:dev -c 'cp /mnt/exim.conf /tmp/exim.conf && exec /usr/sbin/exim4 -C /tmp/exim.conf -bh 127.0.0.1'
}
printf 'EHLO client.example\r\nMAIL FROM:<sender@example.org>\r\nRCPT TO:<postmaster@compaan.cloud>\r\nQUIT\r\n' | run_smtp
printf 'EHLO client.example\r\nMAIL FROM:<sender@example.org>\r\nRCPT TO:<nobody@compaan.cloud>\r\nQUIT\r\n' | run_smtp
printf 'EHLO client.example\r\nMAIL FROM:<sender@example.org>\r\nRCPT TO:<recipient@example.net>\r\nQUIT\r\n' | run_smtp
printf 'EHLO client.example\r\nAUTH PLAIN\r\nQUIT\r\n' | run_smtp
```
Expected: the known alias is accepted; the unknown local recipient is rejected
with `550 No such user`; an unauthenticated external recipient is rejected
with `550 relay not permitted`; AUTH is not advertised before STARTTLS and an
AUTH attempt returns `503 AUTH command used when not advertised`.

Run `docker/mail/exim/test-smtp-auth.sh` to verify a local STARTTLS session.
Expected: PLAIN and LOGIN authentication succeed with the fixture credential;
an authenticated external recipient is accepted; a bad password is rejected;
and an authenticated unknown local recipient is rejected with `550 No such
user`.

- [ ] **Step 5: Commit**

```bash
git add argocd/homelab/mail/exim.conf argocd/homelab/mail/aliases
git commit -m "feat(mail): add exim configuration"
```

---

### Task 3: Dovecot configuration

**Files:**
- Create: `argocd/homelab/mail/dovecot.conf`

**Interfaces:**
- Consumes: image `mail-dovecot:dev` and container paths from Task 1.
- Produces: config referenced by ConfigMap `mail-config` key `dovecot.conf` (Task 5); mail path `maildir:/var/mail/vmail/%d/%n/Maildir` must resolve to the same Maildir layout as exim's `local_maildir` directory (Task 2).

- [ ] **Step 1: Write `argocd/homelab/mail/dovecot.conf`**

```
protocols = imap
listen = *, ::

log_path = /dev/stderr
info_log_path = /dev/stdout
log_timestamp = "%Y-%m-%d %H:%M:%S "
login_greeting = compaan.cloud mail ready.

ssl = required
ssl_min_protocol = TLSv1.2
ssl_cert = </etc/dovecot/tls/tls.crt
ssl_key = </etc/dovecot/tls/tls.key
disable_plaintext_auth = yes
auth_mechanisms = plain login

first_valid_uid = 5000
last_valid_uid = 5000
first_valid_gid = 5000
last_valid_gid = 5000

mail_location = maildir:/var/mail/vmail/%d/%n/Maildir
mail_privileged_group = vmail

passdb {
  driver = passwd-file
  args = scheme=SHA512-CRYPT /etc/dovecot/auth/passwd-dovecot
}

userdb {
  driver = static
  args = uid=5000 gid=5000 home=/var/mail/vmail/%d/%n
}

service auth {
  user = root
}

service imap-login {
  inet_listener imap {
    port = 0
  }
  inet_listener imaps {
    port = 993
    ssl = yes
  }
}

service imap {
  vsz_limit = 2048 M
}
```

- [ ] **Step 2: Validate the config in the Task 1 image**

`doveconf -n` resolves the SSL files, so generate a throwaway cert first:

```bash
docker run --rm --entrypoint /bin/sh \
  -v "$PWD/argocd/homelab/mail/dovecot.conf:/etc/dovecot/dovecot.conf:ro" \
  mail-dovecot:dev -c '
    mkdir -p /etc/dovecot/tls
    openssl req -x509 -newkey rsa:2048 -nodes \
      -keyout /etc/dovecot/tls/tls.key -out /etc/dovecot/tls/tls.crt \
      -subj /CN=config-check -days 1 2>/dev/null
    doveconf -n -c /etc/dovecot/dovecot.conf >/dev/null && echo CONFIG-OK
  '
```
Expected: `CONFIG-OK`.

- [ ] **Step 3: Commit**

```bash
git add argocd/homelab/mail/dovecot.conf
git commit -m "feat(mail): add dovecot configuration"
```

---

### Task 4: Seal recipes and SealedSecrets

**Files:**
- Modify: `Justfile`
- Create: `argocd/homelab/mail/mail-auth-sealed-secret.yaml` (generated)
- Create: `argocd/homelab/mail/mail-dkim-sealed-secret.yaml` (generated)

**Interfaces:**
- Consumes: existing Justfile variables `sealed_secrets_controller_name` / `sealed_secrets_controller_namespace`; `pass` entries `compaan.cloud/mail/roche` and `compaan.cloud/mail/juan` (create them first — step 1).
- Produces: SealedSecret `mail-auth` (namespace `mail`, keys `passwd`, `passwd-dovecot`) and SealedSecret `mail-dkim` (namespace `mail`, key `dkim.private`) — consumed by Task 5 deployments; DKIM public key TXT value printed for the operator's DNS work (Task 9).

- [ ] **Step 1: Ensure the pass entries exist**

```bash
pass show compaan.cloud/mail/roche >/dev/null || pass generate compaan.cloud/mail/roche 32
pass show compaan.cloud/mail/juan  >/dev/null || pass generate compaan.cloud/mail/juan 32
```

- [ ] **Step 2: Add variables and recipes to `Justfile`**

Add near the other variable definitions:

```just
mail_roche_password_entry := "compaan.cloud/mail/roche"
mail_juan_password_entry := "compaan.cloud/mail/juan"
mail_auth_secret_path := "argocd/homelab/mail/mail-auth-sealed-secret.yaml"
mail_dkim_secret_path := "argocd/homelab/mail/mail-dkim-sealed-secret.yaml"
```

Add the recipes:

```just
# Seal the shared mail credentials (exim + dovecot formats) for namespace mail.
seal-mail-auth:
  @mkdir -p "$(dirname {{quote(mail_auth_secret_path)}})"; \
  tmpdir="$(mktemp -d)"; \
  tmpfile="$(mktemp "$(dirname {{quote(mail_auth_secret_path)}})/.mail-auth.yaml.XXXXXX")"; \
  trap 'rm -rf "$tmpdir"; rm -f "$tmpfile"' EXIT; \
  umask 077; \
  : > "$tmpdir/passwd"; \
  : > "$tmpdir/passwd-dovecot"; \
  for entry in {{mail_roche_password_entry}} {{mail_juan_password_entry}}; do \
    user="${entry##*/}"; \
    password="$(pass show "$entry" | head -n1 | tr -d '\r\n')"; \
    [[ -n "$password" ]] || { echo "Refusing to seal empty password for $user" >&2; exit 1; }; \
    hash="$(printf '%s' "$password" | openssl passwd -6 -stdin)"; \
    printf '%s@compaan.cloud:%s\n' "$user" "$hash" >> "$tmpdir/passwd"; \
    printf '%s@compaan.cloud:{SHA512-CRYPT}%s::::::\n' "$user" "$hash" >> "$tmpdir/passwd-dovecot"; \
  done; \
  kubectl create secret generic mail-auth \
    --namespace mail \
    --from-file=passwd="$tmpdir/passwd" \
    --from-file=passwd-dovecot="$tmpdir/passwd-dovecot" \
    --dry-run=client \
    -o yaml \
  | kubeseal \
      --kubeconfig "${KUBECONFIG:-./.kubeconfig}" \
      --controller-name {{sealed_secrets_controller_name}} \
      --controller-namespace {{sealed_secrets_controller_namespace}} \
      --format=yaml \
  > "$tmpfile"; \
  mv "$tmpfile" {{quote(mail_auth_secret_path)}}

# Seal a fresh DKIM private key and print the DNS TXT value to publish.
seal-mail-dkim:
  @mkdir -p "$(dirname {{quote(mail_dkim_secret_path)}})"; \
  tmpdir="$(mktemp -d)"; \
  tmpfile="$(mktemp "$(dirname {{quote(mail_dkim_secret_path)}})/.mail-dkim.yaml.XXXXXX")"; \
  trap 'rm -rf "$tmpdir"; rm -f "$tmpfile"' EXIT; \
  umask 077; \
  openssl genrsa -out "$tmpdir/dkim.private" 2048 2>/dev/null; \
  kubectl create secret generic mail-dkim \
    --namespace mail \
    --from-file=dkim.private="$tmpdir/dkim.private" \
    --dry-run=client \
    -o yaml \
  | kubeseal \
      --kubeconfig "${KUBECONFIG:-./.kubeconfig}" \
      --controller-name {{sealed_secrets_controller_name}} \
      --controller-namespace {{sealed_secrets_controller_namespace}} \
      --format=yaml \
  > "$tmpfile"; \
  mv "$tmpfile" {{quote(mail_dkim_secret_path)}}; \
  printf '\nPublish this TXT record (see README for chunking):\n'; \
  printf '  name:  mail._domainkey.compaan.cloud\n'; \
  printf '  value: v=DKIM1; k=rsa; p=%s\n' \
    "$(openssl rsa -in "$tmpdir/dkim.private" -pubout -outform der 2>/dev/null | openssl base64 -A)"
```

- [ ] **Step 3: Verify recipe parse and dry-render**

Run: `just --list` (parses the Justfile; both new recipes appear).

- [ ] **Step 4: Run the recipes (needs `.kubeconfig` cluster access; read-only)**

```bash
just seal-mail-auth
just seal-mail-dkim
```
Expected: both sealed files written; the DKIM TXT value printed. **Save the DKIM TXT output for Task 9** (operator DNS step). Confirm no plaintext landed in git: `git status --short` must show only the two `*-sealed-secret.yaml` files and `Justfile`; `grep -L encryptedData argocd/homelab/mail/*-sealed-secret.yaml` prints nothing.

- [ ] **Step 5: Commit**

```bash
git add Justfile argocd/homelab/mail/mail-auth-sealed-secret.yaml argocd/homelab/mail/mail-dkim-sealed-secret.yaml
git commit -m "feat(mail): seal mail credentials and DKIM key"
```

---

### Task 5: Kubernetes manifests

**Files:**
- Create: `argocd/homelab/mail/namespace.yaml`
- Create: `argocd/homelab/mail/pvc.yaml`
- Create: `argocd/homelab/mail/certificate.yaml`
- Create: `argocd/homelab/mail/services.yaml`
- Create: `argocd/homelab/mail/deployments.yaml`
- Create: `argocd/homelab/mail/kustomization.yaml`

**Interfaces:**
- Consumes: `exim.conf`, `dovecot.conf`, `aliases` (Task 2–3) via configMapGenerator; SealedSecrets `mail-auth`, `mail-dkim` (Task 4); image names `exim`/`dovecot` and tag `2026-08-15` (Task 1, pushed in Task 8).
- Produces: kustomize package at `argocd/homelab/mail` consumed by the ArgoCD Application (Task 6). NodePorts 30025/30587/30993 consumed by the operator's router forwards (Task 8). Certificate `mail-tls` consumed by both pods as secret `mail-tls`.

- [ ] **Step 1: `namespace.yaml`**

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: mail
```

- [ ] **Step 2: `pvc.yaml`**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mail-storage
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 50Gi
  storageClassName: longhorn-sata
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mail-exim-spool
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: longhorn-sata
```

- [ ] **Step 3: `certificate.yaml`**

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: mail-tls
  namespace: mail
spec:
  secretName: mail-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - homelab.compaan.cloud
```

- [ ] **Step 4: `services.yaml`**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mail-smtp
  labels:
    app.kubernetes.io/name: mail-exim
    app.kubernetes.io/part-of: mail
spec:
  type: NodePort
  selector:
    app.kubernetes.io/name: mail-exim
    app.kubernetes.io/part-of: mail
  ports:
    - name: smtp
      port: 25
      targetPort: smtp
      protocol: TCP
      nodePort: 30025
---
apiVersion: v1
kind: Service
metadata:
  name: mail-submission
  labels:
    app.kubernetes.io/name: mail-exim
    app.kubernetes.io/part-of: mail
spec:
  type: NodePort
  selector:
    app.kubernetes.io/name: mail-exim
    app.kubernetes.io/part-of: mail
  ports:
    - name: submission
      port: 587
      targetPort: submission
      protocol: TCP
      nodePort: 30587
---
apiVersion: v1
kind: Service
metadata:
  name: mail-imaps
  labels:
    app.kubernetes.io/name: mail-dovecot
    app.kubernetes.io/part-of: mail
spec:
  type: NodePort
  selector:
    app.kubernetes.io/name: mail-dovecot
    app.kubernetes.io/part-of: mail
  ports:
    - name: imaps
      port: 993
      targetPort: imaps
      protocol: TCP
      nodePort: 30993
```

- [ ] **Step 5: `deployments.yaml`**

Secret and config volumes mount as directories, never `subPath`. Thus, sealed-secret rotations propagate without restarts. The hashed ConfigMap rolls out config edits on sync. The Exim init container resolves `Debian-exim` and sets ownership on the dedicated spool PVC before Exim starts.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mail-exim
  labels:
    app.kubernetes.io/name: mail-exim
    app.kubernetes.io/part-of: mail
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app.kubernetes.io/name: mail-exim
      app.kubernetes.io/part-of: mail
  template:
    metadata:
      labels:
        app.kubernetes.io/name: mail-exim
        app.kubernetes.io/part-of: mail
    spec:
      automountServiceAccountToken: false
      securityContext:
        fsGroup: 5000
      initContainers:
        - name: init-exim-spool
          image: exim
          imagePullPolicy: IfNotPresent
          securityContext:
            runAsUser: 0
            runAsGroup: 0
          command:
            - /bin/sh
            - -ec
            - |
              uid="$(id -u Debian-exim)"
              gid="$(id -g Debian-exim)"
              chown -R "${uid}:${gid}" /var/spool/exim4
          volumeMounts:
            - name: mail-exim-spool
              mountPath: /var/spool/exim4
      containers:
        - name: exim
          image: exim
          imagePullPolicy: IfNotPresent
          args: ["-bd", "-q30m", "-C", "/etc/exim4/exim.conf"]
          ports:
            - name: smtp
              containerPort: 25
              protocol: TCP
            - name: submission
              containerPort: 587
              protocol: TCP
          readinessProbe:
            tcpSocket:
              port: smtp
            initialDelaySeconds: 10
            periodSeconds: 5
            timeoutSeconds: 3
          livenessProbe:
            tcpSocket:
              port: smtp
            initialDelaySeconds: 30
            periodSeconds: 10
            timeoutSeconds: 5
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
          volumeMounts:
            - name: mail-config
              mountPath: /etc/exim4/exim.conf
              subPath: exim.conf
              readOnly: true
            - name: mail-config
              mountPath: /etc/exim4/aliases
              subPath: aliases
              readOnly: true
            - name: mail-auth
              mountPath: /etc/exim4/auth
              readOnly: true
            - name: mail-dkim
              mountPath: /etc/exim4/dkim
              readOnly: true
            - name: mail-tls
              mountPath: /etc/exim4/tls
              readOnly: true
            - name: mail-storage
              mountPath: /var/mail/vmail
            - name: mail-exim-spool
              mountPath: /var/spool/exim4
      volumes:
        - name: mail-config
          configMap:
            name: mail-config
        - name: mail-auth
          secret:
            secretName: mail-auth
        - name: mail-dkim
          secret:
            secretName: mail-dkim
        - name: mail-tls
          secret:
            secretName: mail-tls
        - name: mail-storage
          persistentVolumeClaim:
            claimName: mail-storage
        - name: mail-exim-spool
          persistentVolumeClaim:
            claimName: mail-exim-spool
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mail-dovecot
  labels:
    app.kubernetes.io/name: mail-dovecot
    app.kubernetes.io/part-of: mail
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app.kubernetes.io/name: mail-dovecot
      app.kubernetes.io/part-of: mail
  template:
    metadata:
      labels:
        app.kubernetes.io/name: mail-dovecot
        app.kubernetes.io/part-of: mail
    spec:
      automountServiceAccountToken: false
      securityContext:
        fsGroup: 5000
      containers:
        - name: dovecot
          image: dovecot
          imagePullPolicy: IfNotPresent
          args: ["/usr/sbin/dovecot", "-F", "-c", "/etc/dovecot/dovecot.conf"]
          ports:
            - name: imaps
              containerPort: 993
              protocol: TCP
          readinessProbe:
            tcpSocket:
              port: imaps
            initialDelaySeconds: 10
            periodSeconds: 5
            timeoutSeconds: 3
          livenessProbe:
            tcpSocket:
              port: imaps
            initialDelaySeconds: 30
            periodSeconds: 10
            timeoutSeconds: 5
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
          volumeMounts:
            - name: mail-config
              mountPath: /etc/dovecot/dovecot.conf
              subPath: dovecot.conf
              readOnly: true
            - name: mail-auth
              mountPath: /etc/dovecot/auth
              readOnly: true
            - name: mail-tls
              mountPath: /etc/dovecot/tls
              readOnly: true
            - name: mail-storage
              mountPath: /var/mail/vmail
      volumes:
        - name: mail-config
          configMap:
            name: mail-config
        - name: mail-auth
          secret:
            secretName: mail-auth
        - name: mail-tls
          secret:
            secretName: mail-tls
        - name: mail-storage
          persistentVolumeClaim:
            claimName: mail-storage
```

- [ ] **Step 6: `kustomization.yaml`**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: mail
resources:
  - namespace.yaml
  - pvc.yaml
  - certificate.yaml
  - services.yaml
  - deployments.yaml
  - mail-auth-sealed-secret.yaml
  - mail-dkim-sealed-secret.yaml
configMapGenerator:
  - name: mail-config
    files:
      - exim.conf
      - dovecot.conf
      - aliases
images:
  - name: exim
    newName: harbor.compaan/mail/exim
    newTag: "2026-08-15"
  - name: dovecot
    newName: harbor.compaan/mail/dovecot
    newTag: "2026-08-15"
```

Note: `generatorOptions.disableNameSuffixHash` is deliberately **not** set — the
hash makes config changes roll out declaratively.

- [ ] **Step 7: Verify the render**

Run:
```bash
kustomize build argocd/homelab/mail > /dev/null && echo RENDER-OK
kustomize build argocd/homelab/mail | grep -c 'harbor.compaan/mail/' # expect 3 references
kustomize build argocd/homelab/mail | grep -o 'harbor.compaan/mail/[a-z]*:2026-08-15' | sort -u | wc -l # expect 2 unique images
kustomize build argocd/homelab/mail | grep 'nodePort'                  # 30025, 30587, 30993
kustomize build argocd/homelab/mail | grep -E '^  name: mail-config-[a-z0-9]{10}$'
```
Expected: RENDER-OK, `3` image references for `2` unique image names, the
three NodePorts, and a hash-suffixed `mail-config-<hash>` name.

- [ ] **Step 8: Commit**

```bash
git add argocd/homelab/mail
git commit -m "feat(mail): add mail namespace manifests"
```

---

### Task 6: ArgoCD registration and traefik-public namespace

**Files:**
- Create: `argocd/base/mail/app.yaml`
- Create: `argocd/base/mail/kustomization.yaml`
- Modify: `argocd/homelab/apps/kustomization.yaml`
- Modify: `argocd/base/traefik/app.yaml`

**Interfaces:**
- Consumes: kustomize package `argocd/homelab/mail` (Task 5).
- Produces: Application `mail` (sync-wave `3`, namespace `mail`); traefik-public watching Ingresses in namespace `mail` so the cert-manager HTTP-01 solver for `mail-tls` (Task 5) is routable.

- [ ] **Step 1: `argocd/base/mail/app.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: mail
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: '3'
spec:
  project: default
  source:
    repoURL: git@github.com:rochecompaan/homelab-k8s.git
    targetRevision: main
    path: argocd/homelab/mail
  destination:
    server: https://kubernetes.default.svc
    namespace: mail
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
    syncOptions:
      - CreateNamespace=true
```

- [ ] **Step 2: `argocd/base/mail/kustomization.yaml`**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: argocd
resources:
  - app.yaml
```

- [ ] **Step 3: Register in `argocd/homelab/apps/kustomization.yaml`**

Insert `- ../../base/mail` between `- ../../base/local-path-provisioner` and `- ../../base/mosquitto`.

- [ ] **Step 4: Add `mail` to traefik-public's Ingress namespaces**

In `argocd/base/traefik/app.yaml`, change:

```yaml
          kubernetesIngress:
            ingressClass: traefik-public
            namespaces:
              - forgejo
              - garage
```

to:

```yaml
          kubernetesIngress:
            ingressClass: traefik-public
            namespaces:
              - forgejo
              - garage
              - mail
```

- [ ] **Step 5: Verify the render**

Run:
```bash
kustomize build argocd/homelab/apps | grep -c 'name: mail$'     # expect 1 (the Application)
yq '.spec.source.helm.valuesObject.providers.kubernetesIngress.namespaces' argocd/base/traefik/app.yaml
```
Expected: `1`; the namespace list includes `mail`.

- [ ] **Step 6: Commit**

```bash
git add argocd/base/mail argocd/homelab/apps/kustomization.yaml argocd/base/traefik/app.yaml
git commit -m "feat(mail): register mail application with argocd"
```

---

### Task 7: Runbook README

**Files:**
- Create: `argocd/homelab/mail/README.md`

**Interfaces:**
- Consumes: everything above; operator-facing.

- [ ] **Step 1: Write `argocd/homelab/mail/README.md`**

```markdown
# compaan.cloud mail (exim + dovecot)

Receives and sends mail for compaan.cloud mailboxes. Design:
`docs/specs/2026-08-15-compaan-cloud-mail-design.md`; plan:
`docs/plans/2026-08-15-compaan-cloud-mail.md`.

## Components

| Piece | Detail |
|---|---|
| `mail-exim` | MTA: 25 inbound, 587 submission (AUTH only after STARTTLS); DKIM-signs outbound (selector `mail`, domain `compaan.cloud`) |
| `mail-dovecot` | IMAPS 993 only; passwd-file auth, same accounts as exim |
| `mail-storage` PVC | RWX `longhorn-sata`, 50Gi; Maildirs at `/var/mail/vmail/compaan.cloud/<user>/Maildir` |
| `mail-exim-spool` PVC | RWO `longhorn-sata`, 5Gi; mounted only by `mail-exim` at `/var/spool/exim4` |
| `mail-tls` Certificate | `homelab.compaan.cloud` via `letsencrypt-prod` |
| NodePorts | 30025 smtp, 30587 submission, 30993 imaps |

## Accounts

Passwords live in `pass` at `compaan.cloud/mail/<user>`. The same sha512-crypt
hash is sealed in two formats into SealedSecret `mail-auth` (keys `passwd` for
exim, `passwd-dovecot` for dovecot).

- Add/rotate an account: set the `pass` entry, re-run `just seal-mail-auth`,
  commit, push. Both services pick up mounted-secret updates without a
  restart (exim re-reads per lookup; dovecot reloads passwd-file on change).
- Add the new user to the loop in the `seal-mail-auth` recipe.

## DKIM

`just seal-mail-dkim` generates a fresh 2048-bit key, seals it as
`mail-dkim`, and prints the TXT value for
`mail._domainkey.compaan.cloud`. A 2048-bit `p=` value exceeds 255 chars:
split it into multiple quoted strings in one TXT record at the DNS provider.
Rotation invalidates the old key as soon as pods mount the updated secret —
keep the old TXT live for a day if mail is in flight.

## TLS renewal

cert-manager renews `mail-tls` automatically. Exim re-reads the cert per
connection. Dovecot does not: after a renewal, bump
`homelab.compaan.cloud/mail-dovecot-restart: "N"` (pod annotation in
`deployments.yaml`) and let ArgoCD roll it. Never `kubectl rollout restart`.

## Images

Built from `docker/mail/` and pushed to Harbor (private, Ziti-only):

```sh
just harbor-login   # or: docker login harbor.compaan
docker build -t harbor.compaan/mail/exim:<tag> docker/mail/exim
docker build -t harbor.compaan/mail/dovecot:<tag> docker/mail/dovecot
docker push harbor.compaan/mail/exim:<tag>
docker push harbor.compaan/mail/dovecot:<tag>
```

Bump `newTag` in `kustomization.yaml` to `<tag>` and commit. Convention:
date tags (`YYYY-MM-DD`, suffix `-2` on repeats).

## Operator checklist: DNS and router

| Item | Value |
|---|---|
| A record | `homelab.compaan.cloud` → `102.218.60.202` |
| MX | `compaan.cloud` → `10 homelab.compaan.cloud` |
| SPF | `v=spf1 ip4:129.232.177.170 ip4:102.218.60.202 -all` (keep upfront4 for Forgejo) |
| DKIM | `mail._domainkey.compaan.cloud` TXT from `just seal-mail-dkim` |
| DMARC | `_dmarc.compaan.cloud` = `v=DMARC1; p=none; rua=mailto:dmarc@compaan.cloud`, tighten to `p=quarantine` after outbound verification |
| PTR | ISP request: `102.218.60.202` → `homelab.compaan.cloud` |
| Router forwards | 25→30025, 587→30587, 993→30993 |

## Verification

Run from an external network (phone hotspot or VPS):

```sh
# inbound + alias
swaks --server homelab.compaan.cloud --from test@example.org --to postmaster@compaan.cloud
# submission (STARTTLS, auth)
swaks --server homelab.compaan.cloud:587 --tls --auth-user roche@compaan.cloud \
  --from roche@compaan.cloud --to <external-address>
# imap login
openssl s_client -connect homelab.compaan.cloud:993
#   then: a LOGIN roche@compaan.cloud <password>
```

Negative checks: unauthenticated relay to an external address must get
`relay not permitted`; `EHLO` before STARTTLS must not offer AUTH.

Deliverability: send to https://mail-tester.com (target ≥ 9/10) and to a
Gmail address → "Show original" must show SPF/DKIM/DMARC PASS.
```

- [ ] **Step 2: Commit**

```bash
git add argocd/homelab/mail/README.md
git commit -m "docs(mail): add runbook readme"
```

---

### Task 8: Push images and roll out

**Files:**
- Modify: none (operator steps + merge)

**Interfaces:**
- Consumes: all previous tasks; Harbor prerequisite (`docs/specs/2026-08-15-harbor-registry-design.md`) **complete** — `docker login harbor.compaan` works from a Ziti-connected machine and the `mail` project exists with public pull.
- Produces: running `mail` application.

- [ ] **Step 1: Build, tag, push**

```bash
just harbor-login
docker build -t harbor.compaan/mail/exim:2026-08-15 docker/mail/exim
docker build -t harbor.compaan/mail/dovecot:2026-08-15 docker/mail/dovecot
docker push harbor.compaan/mail/exim:2026-08-15
docker push harbor.compaan/mail/dovecot:2026-08-15
docker manifest inspect harbor.compaan/mail/exim:2026-08-15 > /dev/null && echo PUSH-OK
```

- [ ] **Step 2: Merge to main and sync**

Per project convention, offer a squash merge of `feat/compaan-cloud-mail`
into `main`, then push. ArgoCD's root app reconciles; watch with
`just argocd-sync` / the ArgoCD UI. Expected: Certificate `mail-tls` becomes
Ready (needs the A record and router 80 forward already live), then both
Deployments reach Available.

- [ ] **Step 3: Router forwards**

Forward on the fixed-IP router: 25→30025, 587→30587, 993→30993 (to any
cluster node's IP).

- [ ] **Step 4: Commit** — nothing to commit (operator steps only). Mark the task done when pods are Running and the Certificate is Ready.

---

### Task 9: External verification and DNS cutover

**Files:**
- Modify: none (external checks + DNS)

**Interfaces:**
- Consumes: Task 8 running service; DKIM TXT value saved from Task 4.

- [ ] **Step 1: Run the README verification block** (swaks inbound, swaks submission, imaps login, negative relay/AUTH checks) from an external network.

- [ ] **Step 2: Publish DNS**: MX, SPF update, DKIM TXT (from Task 4), DMARC `p=none`.

- [ ] **Step 3: Deliverability**: mail-tester.com ≥ 9/10; Gmail "Show original" SPF/DKIM/DMARC PASS. If the PTR is not yet set, expect dynamic-rDNS complaints — re-run after the ISP confirms `102.218.60.202` → `homelab.compaan.cloud`.

- [ ] **Step 4: Tighten DMARC** to `p=quarantine` once step 3 passes cleanly.

---

## Self-Review Notes

- Spec coverage: architecture (T5), exim config (T2), dovecot config (T3), secrets/tooling (T4), exposure/TLS/traefik edit (T5–T6), images (T1, T8), registration (T6), README/DNS/rollout/verification (T7–T9). Harbor assumption referenced, not implemented.
- One known runtime caveat documented in README: dovecot serves the old cert until restarted after a cert-manager renewal (pod-annotation bump, GitOps-style).
