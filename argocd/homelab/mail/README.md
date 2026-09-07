# compaan.cloud mail (exim + dovecot)

This service receives and sends mail for compaan.cloud mailboxes. Read the
[design](../../../docs/specs/2026-08-15-compaan-cloud-mail-design.md) and the
[plan](../../../docs/plans/2026-08-15-compaan-cloud-mail.md) before you change
this service.

## Components

| Piece | Detail |
|---|---|
| `mail-exim` | MTA: port 25 for inbound mail and port 587 for submission. AUTH is available only after STARTTLS. It DKIM-signs outbound mail with selector `mail` for `compaan.cloud`. |
| `mail-dovecot` | IMAPS on port 993 only. It uses passwd-file authentication and the same accounts as Exim. |
| `mail-storage` PVC | RWX `longhorn-sata`, 50Gi. Maildirs are at `/var/mail/vmail/compaan.cloud/<user>/Maildir`. |
| `mail-exim-spool` PVC | RWO `longhorn-sata`, 5Gi. Only `mail-exim` mounts it, at `/var/spool/exim4`. |
| `mail-tls` Certificate | Certificate for `homelab.compaan.cloud` from `letsencrypt-prod`. |
| NodePorts | 30025 for SMTP, 30587 for submission, and 30993 for IMAPS. |

## Exim queue recovery

The dedicated `mail-exim-spool` PVC stores the Exim queue. It is separate from
the `mail-storage` PVC, which stores Maildirs. The `Recreate` Deployment
strategy prevents two Exim Pods from mounting the RWO queue PVC at the same
time.

If `mail-exim` needs recovery, do not delete the `mail-exim-spool` PVC. The
queue remains on this PVC across Pod replacement. Delivery can pause while the
RWO PVC attaches to the replacement Pod. Deferred messages remain queued until
Exim starts.

## Accounts

Passwords are in `pass` at `compaan.cloud/mail/<user>`. The same sha512-crypt
hash is sealed in two formats in SealedSecret `mail-auth`. The secret keys are
`passwd` for Exim and `passwd-dovecot` for Dovecot.

To add or rotate an account:

1. Set the `pass` entry.
2. If the account is new, add the user to the loop in the `seal-mail-auth` recipe.
3. Run `just seal-mail-auth`.
4. Commit and push the generated SealedSecret.

Both services receive mounted-secret updates without a restart. Exim reads the
file for each lookup. Dovecot reloads its passwd file when the file changes.

## DKIM

`just seal-mail-dkim` generates a new 2048-bit key, seals it as `mail-dkim`,
and prints the TXT value for `mail._domainkey.compaan.cloud`. A 2048-bit `p=`
value is more than 255 characters. At the DNS provider, split it into multiple
quoted strings in one TXT record.

The fixed `mail` selector must have exactly one TXT record. Do not publish
old and new TXT values together. During a rotation, replace the current TXT
value with the new value. A rotation can interrupt DKIM validation for mail in
flight.

## GitOps changes and rollback

Make all cluster changes through Git. Commit and push each manifest change.
Then let ArgoCD sync the change. If rollback is necessary, use `git revert`.
Then push the revert. Then let ArgoCD sync it.

Do not use `kubectl apply`, `kubectl patch`, `kubectl delete`, or `kubectl
rollout restart`. If `mail-exim` needs recovery, preserve the
`mail-exim-spool` PVC.

## TLS renewal

cert-manager renews `mail-tls` automatically. Exim reads the certificate for
each connection. Dovecot does not reload the certificate.

After a renewal, bump `homelab.compaan.cloud/mail-dovecot-restart: "N"` in the
Pod annotation in `deployments.yaml`. Commit and push this change. Then let
ArgoCD roll Dovecot.

## Images

Build the images from `docker/mail/`. Harbor is private and requires Ziti
access.

```sh
just harbor-login   # or: docker login harbor.compaan
docker build -t harbor.compaan/mail/exim:<tag> docker/mail/exim
docker build -t harbor.compaan/mail/dovecot:<tag> docker/mail/dovecot
docker push harbor.compaan/mail/exim:<tag>
docker push harbor.compaan/mail/dovecot:<tag>
```

After you push both images, set both `newTag` values in `kustomization.yaml`
to `<tag>`. Then commit the change. Use date tags: `YYYY-MM-DD`, with `-2` for
a repeated date.

## Operator checklist: DNS and router

| Item | Value |
|---|---|
| A record | `homelab.compaan.cloud` → `102.218.60.202` |
| MX | `compaan.cloud` → `10 homelab.compaan.cloud` |
| SPF | `v=spf1 ip4:129.232.177.170 ip4:102.218.60.202 -all` (keep upfront4 for Forgejo) |
| DKIM | `mail._domainkey.compaan.cloud` TXT from `just seal-mail-dkim` |
| DMARC | `_dmarc.compaan.cloud` = `v=DMARC1; p=none; rua=mailto:dmarc@compaan.cloud`. Set `p=quarantine` after outbound verification. |
| PTR | ISP request: `102.218.60.202` → `homelab.compaan.cloud` |
| Router forwards | 25→30025, 587→30587, 993→30993 |

## Verification

If the service is live, run these commands from an external network. Use a
phone hotspot or a VPS.

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

An unauthenticated relay to an external address must return `relay not
permitted`. `EHLO` before STARTTLS must not offer AUTH.

Send a message to https://mail-tester.com. The target score is at least 9/10.
Send a message to Gmail. In "Show original", SPF, DKIM, and DMARC must show
PASS.
