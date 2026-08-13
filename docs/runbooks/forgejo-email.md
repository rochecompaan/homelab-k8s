# Forgejo Email Operations

## Scope

Forgejo submits outbound mail to `mail.upfronthosting.co.za:587` using
STARTTLS and SMTP user `forgejo`. The visible and envelope sender is
`forgejo@git.compaan.cloud`. The password remains in
`pass show FORGEJO_SMTP_PASSWORD` and is committed only as SealedSecret
ciphertext.

## SMTP certificate

Run the server-side commands in this section as `root` on `upfront4`.
Varnish owns public port 80 and routes `mail.upfronthosting.co.za` to Apache
on backend port 81. The Apache vhost therefore binds to port 81. Certbot's
`--http-01-port 81` selects that local vhost; Let's Encrypt still connects to
public port 80 through Varnish. Do not modify Varnish or nginx for this flow.

### Apache HTTP-01 vhost

Create `/etc/apache2/sites-available/mail.upfronthosting.co.za.conf`:

```apache
<VirtualHost *:81>
    ServerName mail.upfronthosting.co.za
    DocumentRoot /var/www/mail-upfronthosting

    <Directory /var/www/mail-upfronthosting>
        Options None
        AllowOverride None
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/mail.upfronthosting.co.za-error.log
    CustomLog ${APACHE_LOG_DIR}/mail.upfronthosting.co.za-access.log combined
</VirtualHost>
```

Enable and probe it:

```bash
install -d -m 0755 /var/www/mail-upfronthosting/.well-known/acme-challenge
a2ensite mail.upfronthosting.co.za.conf
apache2ctl configtest
systemctl reload apache2
printf 'forgejo-acme-preflight\n' \
  > /var/www/mail-upfronthosting/.well-known/acme-challenge/forgejo-preflight
curl --fail --silent --show-error \
  --header 'Host: mail.upfronthosting.co.za' \
  http://127.0.0.1:81/.well-known/acme-challenge/forgejo-preflight
curl --fail --silent --show-error \
  http://mail.upfronthosting.co.za/.well-known/acme-challenge/forgejo-preflight
rm /var/www/mail-upfronthosting/.well-known/acme-challenge/forgejo-preflight
```

The probe must print `forgejo-acme-preflight` before requesting a certificate.

### Dedicated certificate

```bash
certbot certonly --apache \
  --http-01-port 81 \
  --cert-name mail.upfronthosting.co.za \
  -d mail.upfronthosting.co.za

grep -n '^http01_port = 81$' \
  /etc/letsencrypt/renewal/mail.upfronthosting.co.za.conf
certbot certificates --cert-name mail.upfronthosting.co.za
openssl x509 \
  -in /etc/letsencrypt/live/mail.upfronthosting.co.za/fullchain.pem \
  -noout -subject -issuer -dates -ext subjectAltName
```

The SAN must contain `DNS:mail.upfronthosting.co.za` and the issuer must not be
the old self-signed `Upfront Software (Pty) Ltd` certificate.

### Certificate install and renewal hook

Certbot's `live` and `archive` trees remain root-only. Exim runs as
`Debian-exim`, so do not grant it direct access to those trees. Instead, install
one combined certificate-chain/private-key PEM at
`/etc/exim4/exim-letsencrypt.pem`, owned by `root:Debian-exim` with mode `0640`.

Create `/etc/letsencrypt/renewal-hooks/deploy/install-exim4-mail-certificate`:

```sh
#!/bin/sh
set -eu

case " ${RENEWED_DOMAINS:-} " in
  *" mail.upfronthosting.co.za "*) ;;
  *) exit 0 ;;
esac

lineage=${RENEWED_LINEAGE:?RENEWED_LINEAGE is required}
fullchain="$lineage/fullchain.pem"
privkey="$lineage/privkey.pem"
target=/etc/exim4/exim-letsencrypt.pem
tmp=$(mktemp /etc/exim4/.exim-letsencrypt.pem.XXXXXX)
backup=
installed=0
had_target=0

rollback() {
  rc=$?
  trap - EXIT
  trap '' HUP INT TERM
  set +e
  rollback_failed=0

  if [ "$installed" -eq 1 ] && [ ! -e "$tmp" ]; then
    if [ "$had_target" -eq 1 ]; then
      mv -f "$backup" "$target" || rollback_failed=1
    else
      rm -f "$target" || rollback_failed=1
    fi
    if [ "$rollback_failed" -eq 0 ]; then
      /bin/systemctl reload exim4 || rollback_failed=1
    fi
  fi

  rm -f "$tmp"
  if [ -n "$backup" ]; then
    rm -f "$backup"
  fi
  if [ "$rollback_failed" -ne 0 ]; then
    echo "CRITICAL: failed to restore the previous Exim certificate" >&2
    exit 1
  fi
  exit "$rc"
}
trap rollback EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

cat "$fullchain" "$privkey" > "$tmp"
openssl x509 -in "$tmp" -noout >/dev/null
openssl pkey -in "$tmp" -noout >/dev/null 2>&1
cert_pub=$(openssl x509 -in "$tmp" -pubkey -noout \
  | openssl pkey -pubin -outform DER 2>/dev/null \
  | sha256sum | awk '{print $1}')
key_pub=$(openssl pkey -in "$tmp" -pubout -outform DER 2>/dev/null \
  | sha256sum | awk '{print $1}')
if [ "$cert_pub" != "$key_pub" ]; then
  echo "refusing to install mismatched Exim certificate and key" >&2
  exit 1
fi

chown root:Debian-exim "$tmp"
chmod 0640 "$tmp"
if [ "$(stat -c '%U:%G %a' "$tmp")" != "root:Debian-exim 640" ]; then
  echo "refusing to install Exim PEM with unexpected ownership or mode" >&2
  exit 1
fi

/usr/sbin/exim4 -bV >/dev/null
if [ -e "$target" ]; then
  backup=$(mktemp /etc/exim4/.exim-letsencrypt.previous.XXXXXX)
  rm -f "$backup"
  ln "$target" "$backup"
  had_target=1
fi
installed=1
mv -f "$tmp" "$target"
/bin/systemctl reload exim4
installed=0
if [ -n "$backup" ]; then
  rm -f "$backup"
fi
trap - EXIT HUP INT TERM
```

Install the hook and stage the current certificate while Exim still uses its
old paths:

```bash
chmod 0755 /etc/letsencrypt/renewal-hooks/deploy/install-exim4-mail-certificate
RENEWED_DOMAINS='mail.upfronthosting.co.za' \
RENEWED_LINEAGE='/etc/letsencrypt/live/mail.upfronthosting.co.za' \
  /etc/letsencrypt/renewal-hooks/deploy/install-exim4-mail-certificate
stat -c '%U:%G %a %n' /etc/exim4/exim-letsencrypt.pem
runuser -u Debian-exim -- test -r /etc/exim4/exim-letsencrypt.pem
```

### Exim TLS bundle

Preserve unrelated existing macros in `/etc/exim4/conf.d/main/000_localmacros`.
The active Debian TLS options file already sets `MAIN_TLS_ENABLE = yes`; do
not redefine it. Set the combined PEM exactly once:

```exim
MAIN_TLS_CERTKEY = /etc/exim4/exim-letsencrypt.pem
```

Regenerate, validate, and reload:

```bash
update-exim4.conf
exim4 -bV >/dev/null
exim4 -bP tls_certificate tls_privatekey
systemctl reload exim4
systemctl is-active --quiet exim4
```

`tls_certificate` must be `/etc/exim4/exim-letsencrypt.pem`.
`tls_privatekey` remains unset because the same PEM contains the private key.
The old `/etc/exim4/exim.crt` and `/etc/exim4/exim.key` remain available only
for immediate rollback.

### Renewal test

Never let a Certbot staging certificate reach Exim. Temporarily move the deploy
hook outside Certbot's hook directory during the dry-run, restore it through an
exit trap, and prove the production PEM did not change:

```bash
bash <<'SCRIPT'
set -Eeuo pipefail

host=mail.upfronthosting.co.za
renewal=/etc/letsencrypt/renewal/$host.conf
hook=/etc/letsencrypt/renewal-hooks/deploy/install-exim4-mail-certificate
disabled=/root/install-exim4-mail-certificate.dry-run-disabled
target=/etc/exim4/exim-letsencrypt.pem

restore_hook() {
  if [ -e "$disabled" ]; then
    mv "$disabled" "$hook" || return 1
    chmod 0755 "$hook" || return 1
  fi
}

cleanup() {
  rc=$?
  trap - EXIT HUP INT TERM
  set +e
  restore_hook
  restore_rc=$?
  if [ "$restore_rc" -ne 0 ]; then
    echo 'CRITICAL: failed to restore the Certbot deploy hook.' >&2
    exit 1
  fi
  exit "$rc"
}

test -x "$hook"
test ! -e "$disabled"
test -r "$target"
grep -Eq '^http01_port[[:space:]]*=[[:space:]]*81$' "$renewal"
mapfile -t deploy_hooks < <(find /etc/letsencrypt/renewal-hooks/deploy \
  -maxdepth 1 -type f -executable -print)
test "${#deploy_hooks[@]}" -eq 1
test "${deploy_hooks[0]}" = "$hook"

hook_configs=("$renewal")
if [ -e /etc/letsencrypt/cli.ini ]; then
  hook_configs+=(/etc/letsencrypt/cli.ini)
fi
if grep -nE '^(pre_hook|post_hook|renew_hook|deploy_hook)[[:space:]]*=' \
  "${hook_configs[@]}"; then
  echo 'unexpected explicit Certbot hook configuration' >&2
  exit 1
fi

before=$(sha256sum "$target" | awk '{print $1}')
trap cleanup EXIT HUP INT TERM
mv "$hook" "$disabled"
certbot renew --dry-run --cert-name "$host"
restore_hook

after=$(sha256sum "$target" | awk '{print $1}')
test "$before" = "$after"
test -x "$hook"
test ! -e "$disabled"
test "$(stat -c '%U:%G %a' "$target")" = 'root:Debian-exim 640'
runuser -u Debian-exim -- test -r "$target"
systemctl is-active --quiet exim4
SCRIPT
```

Do not add `--run-deploy-hooks` to the dry-run. The explicit production-lineage
invocation in the preceding section proves the hook's install behavior without
risking replacement by a staging certificate.

## Public TLS verification

From a machine outside the mail host, run:

```bash
python3 - <<'PY'
import smtplib
import ssl

host = "mail.upfronthosting.co.za"
with smtplib.SMTP(host, 587, timeout=15) as smtp:
    smtp.ehlo()
    if not smtp.has_extn("starttls"):
        raise SystemExit("STARTTLS is not advertised")
    smtp.starttls(context=ssl.create_default_context())
    smtp.ehlo()
    cert = smtp.sock.getpeercert()
    names = [value for kind, value in cert.get("subjectAltName", ()) if kind == "DNS"]
    if host not in names:
        raise SystemExit(f"certificate SANs do not contain {host}: {names}")
    print("trusted STARTTLS:", host)
    print("expires:", cert["notAfter"])
    print("AUTH:", smtp.esmtp_features.get("auth", "not advertised"))
PY
```

The script must complete without disabling certificate verification.

## Credential and delivery preflight

Run from the workstation that holds the `pass` entry:

```bash
python3 - <<'PY'
import smtplib
import ssl
import subprocess
from email.message import EmailMessage
from email.utils import formatdate, make_msgid

lines = subprocess.check_output(
    ["pass", "show", "FORGEJO_SMTP_PASSWORD"], text=True
).splitlines()
if not lines or not lines[0]:
    raise SystemExit("FORGEJO_SMTP_PASSWORD is empty")
password = lines[0]

message = EmailMessage()
message["From"] = "Forgejo <forgejo@git.compaan.cloud>"
message["To"] = "roche@upfrontsoftware.co.za"
message["Subject"] = "Forgejo SMTP preflight"
message["Date"] = formatdate(localtime=True)
message["Message-ID"] = make_msgid(domain="git.compaan.cloud")
message.set_content("Trusted STARTTLS and authenticated SMTP preflight succeeded.\n")

with smtplib.SMTP("mail.upfronthosting.co.za", 587, timeout=15) as smtp:
    smtp.ehlo()
    smtp.starttls(context=ssl.create_default_context())
    smtp.ehlo()
    smtp.login("forgejo", password)
    smtp.send_message(
        message,
        from_addr="forgejo@git.compaan.cloud",
        to_addrs=["roche@upfrontsoftware.co.za"],
    )

print("authenticated test message accepted")
PY
```

The password stays in process memory and is never printed or passed as a
command-line value.

## Deliverability gate

The `compaan.cloud` zone uses these records:

| Name | Type | Value |
| --- | --- | --- |
| `@` | `TXT` | `v=spf1 ip4:129.232.177.170 -all` |
| `mail._domainkey.git` | `TXT` | `v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA7p6YSxF5AWtx/3F3YffrxmRBIrnT8s6+sDkpn28oqAYl3bjAmm5MArLJrfpIYjxXBCI1dsopUJ2yCZEjlZenCm+pQdlVqF7+vRawMPjyzxImlB96jBqZAmH4BEZIkn0YttdBRPE9EWxvSUtpha6+r9kj9Hf2h/oLGjFKFuZ7Vh3J4OKTxMicZSwBTyJ15l4SjqsHJQl94wVjjjTtpU3uz2qgUmzXkdHIGxL5XT0IEpHTsdGVA6ZJx2JJMbIAldK5HcP6jWpbOS/1ekNrd4Tc6E2OcN4eJrZre6+cyf4P+TsOEJPidyf0n9AMgG/s4+s3EsUKOyMfW6SzDTqC7QnqPQIDAQAB` |
| `_dmarc.git` | `TXT` | `v=DMARC1; p=reject; adkim=s; aspf=s` |

Preserve `git.compaan.cloud CNAME compaan.cloud.`. The apex SPF policy is
therefore returned for the envelope sender domain. The DKIM record contains
the public key for Exim's active `/etc/exim4/dkim_rsa.private` key; never
publish the private key or the unused `/etc/exim4/dkim.key` public key.

Use these read-only DNS checks:

```bash
dig +noall +answer git.compaan.cloud CNAME
dig +noall +answer git.compaan.cloud TXT
dig +noall +answer compaan.cloud TXT
dig +noall +answer mail._domainkey.git.compaan.cloud TXT
dig +noall +answer _dmarc.git.compaan.cloud TXT
```

Send a fresh authenticated preflight message after DNS changes. Inspect its
`Authentication-Results` and require all of these aligned results before
enabling Forgejo mail:

```text
spf=pass smtp.mailfrom=forgejo@git.compaan.cloud
dkim=pass header.i=@git.compaan.cloud header.s=mail
dmarc=pass header.from=git.compaan.cloud
```

The validated preflight was delivered over TLS 1.3 and Google reported all
three passes under the strict `p=reject` policy.

## Forgejo Secret rotation

Generate or rotate the encrypted password with:

```bash
just seal-forgejo-mailer-secret
```

Commit the changed `mailer-secret.yaml` and increment
`homelab.compaan.cloud/forgejo-mailer-secret-revision` in the same commit.
ArgoCD performs the rollout; never use `kubectl rollout restart`.

## Failure recovery

- A failed Certbot issuance leaves Exim unchanged.
- Validate Exim before every reload.
- A failed renewal does not run the deploy hook.
- A failed pre-install hook check leaves the active combined PEM unchanged and does not reload Exim.
- A failed Exim reload restores the previous combined PEM and reloads it; treat a reported rollback failure as critical.
- Do not grant `Debian-exim` access to Certbot's root-only trees.
- If the initial switch fails, remove `MAIN_TLS_CERTKEY`, regenerate Exim configuration, and reload the unchanged `/etc/exim4/exim.crt` and `.key`.
- Never enable `FORCE_TRUST_SERVER_CERT` in Forgejo.
- Roll back Forgejo mail through Git, not direct cluster mutation.
- Repair or reissue a trusted SMTP certificate instead of restoring the
  expired self-signed certificate as a steady state.
