#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
image="${MAIL_EXIM_IMAGE:-mail-exim:dev}"
container="mail-exim-smtp-test-$$"
password='smtp-fixture-password'

umask 077
tmp="$(mktemp -d)"
cleanup() {
  docker rm -f "$container" >/dev/null 2>&1 || true
  rm -rf "$tmp"
}
trap cleanup EXIT

mkdir -p "$tmp/exim4/auth" "$tmp/exim4/dkim" "$tmp/exim4/tls"
printf 'roche@compaan.cloud:%s\n' \
  "$(openssl passwd -6 -salt smtpfixture "$password")" \
  > "$tmp/exim4/auth/passwd"
cp "$root/argocd/homelab/mail/exim.conf" "$tmp/exim4/exim4.conf"
cp "$root/argocd/homelab/mail/aliases" "$tmp/exim4/aliases"
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "$tmp/exim4/tls/tls.key" \
  -out "$tmp/exim4/tls/tls.crt" \
  -days 1 \
  -subj '/CN=homelab.compaan.cloud' >/dev/null 2>&1
chmod 0755 \
  "$tmp/exim4" \
  "$tmp/exim4/auth" \
  "$tmp/exim4/dkim" \
  "$tmp/exim4/tls"
chmod 0644 \
  "$tmp/exim4/exim4.conf" \
  "$tmp/exim4/aliases" \
  "$tmp/exim4/auth/passwd" \
  "$tmp/exim4/tls/tls.crt" \
  "$tmp/exim4/tls/tls.key"

docker create --name "$container" -p 127.0.0.1::587 "$image" >/dev/null
tar --owner=0 --group=5000 -C "$tmp/exim4" -cf - . \
  | docker cp - "$container:/etc/exim4"
docker start "$container" >/dev/null
port="$(docker port "$container" 587/tcp | sed -n 's/.*:\([0-9][0-9]*\)$/\1/p')"

starttls() {
  openssl s_client -quiet -crlf -starttls smtp \
    -connect "127.0.0.1:$port" 2>/dev/null
}

ready=false
for _ in $(seq 1 20); do
  if printf 'QUIT\r\n' | starttls >/dev/null 2>&1; then
    ready=true
    break
  fi
  sleep 1
done

if [[ "$ready" != true ]]; then
  printf 'Exim did not become ready\n' >&2
  docker logs "$container" >&2 2>&1 || true
  exit 1
fi

assert_contains() {
  local output="$1"
  local expected="$2"

  if ! grep -Fq "$expected" <<< "$output"; then
    printf 'Expected SMTP response not found: %s\n' "$expected" >&2
    printf '%s\n' "$output" >&2
    exit 1
  fi
}

plain_token="$(printf '\0roche@compaan.cloud\0%s' "$password" | base64 -w0)"
plain_output="$(printf 'EHLO client.example\r\nAUTH PLAIN %s\r\nMAIL FROM:<roche@compaan.cloud>\r\nRCPT TO:<recipient@example.net>\r\nQUIT\r\n' "$plain_token" | starttls)"
assert_contains "$plain_output" '235 Authentication succeeded'
assert_contains "$plain_output" '250 Accepted'

login_user="$(printf '%s' 'roche@compaan.cloud' | base64 -w0)"
login_password="$(printf '%s' "$password" | base64 -w0)"
login_output="$(printf 'EHLO client.example\r\nAUTH LOGIN\r\n%s\r\n%s\r\nMAIL FROM:<roche@compaan.cloud>\r\nRCPT TO:<nobody@compaan.cloud>\r\nQUIT\r\n' "$login_user" "$login_password" | starttls)"
assert_contains "$login_output" '235 Authentication succeeded'
assert_contains "$login_output" '550 No such user'

bad_token="$(printf '\0roche@compaan.cloud\0bad-password' | base64 -w0)"
bad_output="$(printf 'EHLO client.example\r\nAUTH PLAIN %s\r\nQUIT\r\n' "$bad_token" | starttls)"
assert_contains "$bad_output" '535'

if ! MAIL_TEST_PORT="$port" python3 >"$tmp/local-delivery.log" 2>&1 <<'PY'
import os
import smtplib
import ssl

message = "\r\n".join(
    [
        "From: postmaster@example.net",
        "To: roche@compaan.cloud",
        "Subject: EXIM local delivery regression",
        "",
        "Local Maildir delivery test.",
    ]
)

with smtplib.SMTP("127.0.0.1", int(os.environ["MAIL_TEST_PORT"]), timeout=30) as smtp:
    smtp.ehlo()
    smtp.starttls(context=ssl._create_unverified_context())
    smtp.ehlo()
    refused = smtp.sendmail("", ["roche@compaan.cloud"], message)
    if refused:
        raise RuntimeError("local recipient was refused")
PY
then
  printf 'Local SMTP delivery transaction failed\n' >&2
  cat "$tmp/local-delivery.log" >&2
  docker logs "$container" 2>&1 \
    | grep -E 'lost privilege|unable to set (gid|uid)|local delivery|Tainted' >&2 \
    || true
  exit 1
fi

for _ in $(seq 1 20); do
  if docker exec "$container" /bin/sh -ec \
    'find /var/mail/vmail/compaan.cloud/roche/Maildir/new -type f -exec grep -lF "Subject: EXIM local delivery regression" {} \; 2>/dev/null | grep -q .'; then
    printf 'EXIM-LOCAL-DELIVERY-OK\n'
    printf 'EXIM-SMTP-AUTH-OK\n'
    exit 0
  fi
  sleep 1
done

printf 'Expected local message was not delivered to the Maildir\n' >&2
cat "$tmp/local-delivery.log" >&2
docker logs "$container" 2>&1 \
  | grep -E 'lost privilege|unable to set (gid|uid)|local delivery|Tainted' >&2 \
  || true
exit 1
