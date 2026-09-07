# compaan.cloud Mail Server Design

## Goal

Self-host sending and receiving for compaan.cloud user mailboxes (starting with
`roche@compaan.cloud` and `juan@compaan.cloud`) on the homelab Kubernetes
cluster: inbound MX traffic on port 25, authenticated submission on port 587,
IMAP-over-TLS on port 993, and direct outbound delivery with aligned SPF, DKIM,
and DMARC. No smarthost; mail leaves the cluster from the fixed IP
`102.218.60.202`.

## Prerequisite: Harbor registry (separate side-project)

This design assumes the in-cluster Harbor registry is already complete per
`docs/specs/2026-08-15-harbor-registry-design.md`. Harbor is exposed
**privately only** as `https://harbor.compaan` (traefik-private, TLS from the
`compaan-ca` ClusterIssuer, CoreDNS `*.compaan` rewrite, operator access over
Ziti). There is deliberately no public registry hostname. For this project,
"complete" means:

- the three Harbor Applications reconcile healthy and
  `https://harbor.compaan` serves the portal and `/v2/` API;
- a `mail` project exists in Harbor with **public pull** (anonymous read) so
  the cluster pulls images without an imagePullSecret;
- cluster nodes resolve `harbor.compaan` and containerd trusts the compaan CA
  for pulls (this node-level pull path is part of the Harbor implementation,
  not this one);
- the operator pushes from a Ziti-connected machine with a Harbor user or
  robot account held locally.

None of the mail work below blocks on Harbor internals — only on
`harbor.compaan/mail/<image>:<tag>` being pushable and pullable.

## Current state

- `compaan.cloud` A record resolves to the fixed homelab IP `102.218.60.202`
  (Home-Connect). No MX record exists yet.
- Current PTR for `102.218.60.202` is `102-218-60-202.ip.home-connect.co.za`,
  which trips dynamic-IP heuristics at receivers. A request is filed with the
  ISP to set it to `homelab.compaan.cloud`. Inbound mail does not depend on
  the PTR; outbound deliverability does.
- Apex SPF is `v=spf1 ip4:129.232.177.170 -all`. That IP is
  `upfront4.upfronthosting.co.za`, which sends Forgejo notifications with
  `@git.compaan.cloud` envelope senders and must stay authorized.
- No apex DMARC record exists (`_dmarc.git.compaan.cloud` covers only the
  git subdomain).
- Reference implementation: `~/projects/mycity` runs Exim + Dovecot on k8s
  (`k8s/mail/exim.conf`, `k8s/mail/dovecot.conf`, `exim/Dockerfile`). That
  config is specialised for logger telemetry; only its container shape,
  maildir layout, auth pattern, and ACL skeleton carry over.
- Cluster facts: traefik-public is a DaemonSet exposed on NodePorts 30080/30443
  and only watches Ingresses in the `forgejo` and `garage` namespaces;
  `letsencrypt-prod` ClusterIssuer solves HTTP-01 via `traefik-public`;
  SealedSecrets is the secret mechanism; `longhorn-sata` is the established
  StorageClass for RWX maildir PVCs (webmutt, openclaw-mail-sync); there is no
  MetalLB. NodePorts already in use: 30000–30009, 30021, 30080, 30443, 31883.

## Architecture

Two single-replica Deployments in a new `mail` namespace share the RWX
`mail-storage` PersistentVolumeClaim, which holds all mailboxes. The
`mail-exim` Deployment also mounts the dedicated RWO `mail-exim-spool` PVC at
`/var/spool/exim4`. The `mail-dovecot` Deployment does not mount this PVC.

- **exim** — MTA listening on 25 (inbound from other MTAs) and 587
  (authenticated submission). Delivers local mail to
  `/var/mail/vmail/compaan.cloud/<user>/Maildir`. Routes outbound via DNS and
  signs with DKIM. An init container resolves the `Debian-exim` user and group.
  It sets ownership of `/var/spool/exim4` before Exim starts.
- **dovecot** — IMAPS on 993, serving those same Maildirs.

Both authenticate users against the same account data from one SealedSecret
(`mail-auth`), mounted in two formats (see Secrets). Passwords change without
pod restarts: Exim's `lsearch` reads the file per lookup and Dovecot reloads
passwd-file on change; kubelet refreshes mounted secrets.

External exposure is dedicated NodePort Services (mycity pattern), keeping
Traefik out of the SMTP path:

| Service          | Port | NodePort | Router forward |
|------------------|------|----------|----------------|
| `mail-smtp`      | 25   | 30025    | 25 → 30025     |
| `mail-submission`| 587  | 30587    | 587 → 30587    |
| `mail-imaps`     | 993  | 30993    | 993 → 30993    |

Default (SNAT) traffic policy: Exim sees cluster-internal sender IPs. Acceptable
for this scope (no DNSBL checks); flipping to `externalTrafficPolicy: Local`
later is a one-line change if sender-IP-based filtering is ever wanted.

TLS for all three ports comes from one cert-manager `Certificate` (`mail-tls`,
dnsNames: `homelab.compaan.cloud`) via `letsencrypt-prod`. Because the ACME
HTTP-01 solver Ingress lands in the `mail` namespace, traefik-public's watched
Ingress namespaces gain `mail` (one-line Helm values edit in
`argocd/base/traefik/app.yaml`). Port-80 reachability for
`homelab.compaan.cloud` is already proven by forgejo/garage issuance.

`primary_hostname` (and thus HELO/EHLO and `smtp_active_hostname`) is
`homelab.compaan.cloud`, matching the A record and the requested PTR so
forward-confirmed reverse DNS validates.

## Repository layout

All cluster changes are GitOps-only; nothing is applied by hand.

```
argocd/base/mail/app.yaml              # Application: path argocd/homelab/mail,
argocd/base/mail/kustomization.yaml    #   namespace mail, sync-wave '3'
argocd/homelab/mail/
  namespace.yaml
  pvc.yaml                             # mail-storage (RWX, 50Gi) and mail-exim-spool (RWO, 5Gi)
  certificate.yaml                     # mail-tls via letsencrypt-prod
  services.yaml                        # the three NodePort Services
  deployments.yaml                     # mail-exim, mail-dovecot
  sealed-secrets.yaml                  # mail-auth, mail-dkim (ciphertext only)
  exim.conf                            # ┐ via configMapGenerator, name hashing
  dovecot.conf                         # ┘ ENABLED so config edits roll out
  kustomization.yaml                   #   declaratively on sync
  README.md                            # seal/rotate/runbook instructions
docker/mail/exim/Dockerfile            # bookworm-slim + exim4-daemon-heavy + tini
docker/mail/exim/exim-entrypoint.sh    # mycity's, unchanged
docker/mail/dovecot/Dockerfile         # bookworm-slim + dovecot-imapd
```

Registration: add `../../base/mail` to
`argocd/homelab/apps/kustomization.yaml` next to mosquitto.

Config changes roll out without manual pod restarts: the ConfigMap keeps
kustomize's name-suffix hash (unlike mycity), so a config edit changes the
Deployment's volume reference and ArgoCD sync triggers the rollout. Direct
`kubectl rollout restart` remains forbidden.

## Images

Built locally on a Ziti-connected machine from `docker/mail/` and pushed to
Harbor:

```sh
docker build -t harbor.compaan/mail/exim:<short-sha> docker/mail/exim
docker build -t harbor.compaan/mail/dovecot:<short-sha> docker/mail/dovecot
docker push ...
```

Manifests reference local names (`exim`, `dovecot`); the kustomization rewrites
them via `images:` to the Harbor names and tags (mycity pattern). The `mail`
Harbor project allows anonymous pull, so no imagePullSecret exists in the
cluster. Images contain no secrets — all configuration arrives via ConfigMap
and Secret mounts.

## Exim configuration

Derived from mycity's `exim.conf`, stripped of every logger router:

- `daemon_smtp_ports = 25 : 587`; `smtp_enforce_sync = false`.
- `tls_certificate` / `tls_privatekey` from the `mail-tls` secret mount;
  `tls_advertise_hosts = *` (STARTTLS on both ports).
- `auth_advertise_hosts = ${if eq{$tls_in_cipher}{}{}{*}}` — AUTH only after
  STARTTLS.
- `domainlist local_domains = compaan.cloud`.
- ACLs: `acl_smtp_rcpt` accepts local/generated traffic, rejects unverifiable
  local recipients, then accepts authenticated sessions with
  `control = submission/sender_retain`. Unauthenticated recipients must be in
  `+local_domains` — no unauthenticated relaying or accept-then-bounce.
- Routers, in order:
  1. `aliases` — redirect from `/etc/exim4/aliases` (ConfigMap):
     `postmaster`, `abuse`, `dmarc` → `roche@compaan.cloud`.
  2. `local_users` — accept for `+local_domains` where the local part exists in
     the auth passwd file; deliver via `local_maildir`.
  3. `unknown_local` — `:fail: No such user` for the rest of the local domains.
  4. `dnslookup` — everything else via `remote_smtp_dkim`, `no_more`.
- Transports:
  - `local_maildir`: appendfile, `maildir_format`, directory
    `/var/mail/vmail/$domain/$local_part/Maildir`, `create_directory`,
    user `vmail` (uid/gid 5000).
  - `remote_smtp_dkim`: smtp driver with `dkim_domain = compaan.cloud`,
    `dkim_selector = mail`,
    `dkim_private_key = /etc/exim4/dkim/dkim.private`,
    `dkim_canon = relaxed`.
- Authenticators: `plain_server` (and `login_server`) checking
  `${lookup{$auth2}lsearch{/etc/exim4/passwd}}` with `crypteq` against the
  bare `$6$` sha512-crypt hash.

## Dovecot configuration

- `protocols = imap`; only the `imaps` listener on 993 (implicit TLS); the
  plaintext 143 listener is disabled (`port = 0`).
- `ssl = required`, `ssl_min_protocol = TLSv1.2`, cert/key from the `mail-tls`
  secret mount; `disable_plaintext_auth = yes`;
  `auth_mechanisms = plain login`.
- `passdb` driver `passwd-file`, `args = scheme=SHA512-CRYPT /etc/dovecot/passwd`.
- `userdb` static: `uid=5000 gid=5000 home=/var/mail/vmail/%d/%n`.
- `mail_location = maildir:/var/mail/vmail/%d/%n/Maildir` — byte-identical to
  Exim's delivery path.
- Logs to stdout/stderr.

## Secrets and local tooling

Two SealedSecrets, committed as ciphertext only:

- `mail-auth` — two keys generated from the same plaintext passwords:
  - `passwd` (Exim): `roche@compaan.cloud:$6$<sha512-crypt>` per line.
  - `passwd-dovecot` (Dovecot passwd-file):
    `roche@compaan.cloud:{SHA512-CRYPT}$6$<same-hash>::::::` per line.
- `mail-dkim` — `dkim.private`: 2048-bit RSA private key. The public key is
  printed by the sealing recipe for the DNS TXT record.

Plaintext passwords live in `pass` (e.g. `pass compaan.cloud/mail/roche`),
matching the Forgejo mailer pattern. Two `Justfile` recipes:

- `seal-mail-auth` — reads both passwords from `pass`, builds the two file
  formats (hashes via `openssl passwd -6`), seals with `kubeseal` against the
  homelab controller, and atomically replaces the `mail-auth` entry in
  `sealed-secrets.yaml`. Plaintext exists only in a mode-0600 temp file
  removed on exit; never in shell history, chat, or git.
- `seal-mail-dkim` — generates the RSA key, seals `dkim.private`, and prints
  the `mail._domainkey.compaan.cloud` TXT value for DNS publication.

## DNS changes (manual, outside GitOps)

| Record | Value |
|---|---|
| `homelab.compaan.cloud A` | `102.218.60.202` |
| `compaan.cloud MX` | `10 homelab.compaan.cloud` |
| `compaan.cloud TXT` (SPF) | `v=spf1 ip4:129.232.177.170 ip4:102.218.60.202 -all` |
| `mail._domainkey.compaan.cloud TXT` | DKIM public key from `seal-mail-dkim` |
| `_dmarc.compaan.cloud TXT` | `v=DMARC1; p=none; rua=mailto:dmarc@compaan.cloud` initially; tighten to `p=quarantine` after outbound verification passes |
| PTR `102.218.60.202` | `homelab.compaan.cloud` — with the ISP (requested) |

The SPF record keeps `129.232.177.170` authorized: Forgejo sends
`@git.compaan.cloud` mail through upfront4, and SPF for the CNAME'd
`git.compaan.cloud` evaluates the apex record.

## Rollout

1. Harbor prerequisite complete per
   `docs/specs/2026-08-15-harbor-registry-design.md` (`harbor.compaan`
   serving, `mail` project created with public pull, node pull path working).
2. Publish the `homelab.compaan.cloud` A record.
3. Build both images; validate `exim -bV -C /etc/exim4/exim.conf` inside the
   exim image locally with the real `exim.conf` mounted; push to Harbor.
4. Run `seal-mail-auth` and `seal-mail-dkim`; publish the DKIM TXT record.
5. Merge the repo changes (one squash commit): new `argocd/base/mail` and
   `argocd/homelab/mail`, apps-kustomization registration, traefik-public
   namespace edit, `docker/mail/`, Justfile recipes.
6. ArgoCD syncs; the Certificate reaches Ready; pods start once the TLS secret
   exists.
7. Add router forwards 25→30025, 587→30587, 993→30993 on `102.218.60.202`.
8. Verify (below).
9. Publish MX and the SPF update. Inbound is now live.
10. When the ISP confirms the PTR: re-run outbound deliverability checks, then
    tighten DMARC to `p=quarantine`.

## Failure and rollback behavior

- TLS secret absent: pods stay Pending on the volume mount; nothing serves
  half-configured TLS. Fix the Certificate; do not hand-create the secret.
- Bad `exim.conf`: exim exits, pod CrashLoops, previous good config remains in
  git history — revert and sync. The pre-push `exim -bV` check in step 3 makes
  this unlikely.
- Unknown recipient: `:fail:` at RCPT time, sender gets a proper NDR; no
  accept-then-bounce.
- ISP never sets the PTR, or outbound 25 turns out blocked: inbound keeps
  working; outbound falls back to relaying through `upfront4` as a smarthost.
  That fallback is a documented option, not part of this implementation.
- All cluster state is GitOps-managed: rollback is `git revert` + ArgoCD sync.

## Security

- Commit only SealedSecret ciphertext; plaintext credentials stay in `pass`
  and short-lived mode-0600 temp files.
- AUTH is only offered over TLS on both SMTP ports; Dovecot refuses plaintext
  auth entirely.
- No open relay: unauthenticated sessions can only deliver to local domains.
- The DKIM private key exists only in the SealedSecret and the operator's
  local `pass`-managed store.
- Exim's master process starts as root to bind 25/587 and drops to
  `Debian-exim`. Its init container resolves that user and group, then sets
  ownership of the dedicated spool PVC. Mailstore writes run as uid/gid 5000
  (`vmail`), enforced by `fsGroup: 5000` on both pods.
- Both Pod specs set `automountServiceAccountToken: false`; the mail daemons do
  not require Kubernetes API access.
- Resource requests/limits on both containers (100m/128Mi → 500m/512Mi).

## Out of scope

Spam/virus filtering, Sieve, quotas, webmail, monitoring/alerting, additional
domains, and the optional `externalTrafficPolicy: Local` hardening. Each is a
follow-up once the base service proves itself.

## Verification

Static manifests and config files — per the Testing Value Gate no new
automated tests are written. Verification is direct:

1. `kustomize build argocd/homelab/mail` renders without error. The render
   contains both PVCs, the Exim-only spool mount, and the image rewrites to
   `harbor.compaan/mail/...`.
2. `exim -bV -C` validation of the exact committed `exim.conf` inside the
   built image before push (step 3 of Rollout).
3. After sync: `mail-tls` Certificate is Ready; both Deployments healthy.
4. DNS: `dig A homelab.compaan.cloud`, `dig -x 102.218.60.202` (once ISP
   confirms), `dig MX compaan.cloud`, `dig TXT mail._domainkey.compaan.cloud`.
5. From an external host: `swaks --server homelab.compaan.cloud --to
   postmaster@compaan.cloud` delivers to roche's Maildir via the alias.
6. Submission: `swaks --server homelab.compaan.cloud:587 --auth-user
   roche@compaan.cloud --tls` sends to an external address.
7. IMAP: `openssl s_client -connect homelab.compaan.cloud:993` then
   `a LOGIN roche@compaan.cloud <password>` succeeds; mail client shows the
   message from step 5.
8. Deliverability: mail-tester.com score ≥ 9/10; a Gmail recipient's
   "Show original" reports SPF, DKIM, and DMARC all PASS.
9. Negative checks: unauthenticated relay attempt to an external address is
   rejected (`relay not permitted`); AUTH on port 25/587 without STARTTLS is
   not offered.
