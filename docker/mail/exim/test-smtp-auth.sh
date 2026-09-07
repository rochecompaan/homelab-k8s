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

printf 'roche@compaan.cloud:%s\n' \
  "$(openssl passwd -6 -salt smtpfixture "$password")" > "$tmp/passwd"
cp "$root/argocd/homelab/mail/aliases" "$tmp/aliases"
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "$tmp/tls.key" \
  -out "$tmp/tls.crt" \
  -days 1 \
  -subj '/CN=homelab.compaan.cloud' >/dev/null 2>&1

docker run -d --rm --name "$container" --entrypoint /bin/sh \
  -p 127.0.0.1::587 "$image" -c 'exec sleep infinity' >/dev/null
docker exec "$container" mkdir -p /etc/exim4/auth /etc/exim4/dkim /etc/exim4/tls
docker cp "$root/argocd/homelab/mail/exim.conf" "$container:/etc/exim4/exim.conf"
docker cp "$tmp/aliases" "$container:/etc/exim4/aliases"
docker cp "$tmp/passwd" "$container:/etc/exim4/auth/passwd"
docker cp "$tmp/tls.crt" "$container:/etc/exim4/tls/tls.crt"
docker cp "$tmp/tls.key" "$container:/etc/exim4/tls/tls.key"
docker exec "$container" /bin/sh -ec '
  chown root:root /etc/exim4/exim.conf /etc/exim4/aliases /etc/exim4/auth/passwd
  chmod 0644 /etc/exim4/exim.conf /etc/exim4/aliases /etc/exim4/auth/passwd
  chmod 0644 /etc/exim4/tls/tls.crt /etc/exim4/tls/tls.key
  /usr/sbin/exim4 -bV -C /etc/exim4/exim.conf >/dev/null
  nohup /usr/sbin/exim4 -bd -C /etc/exim4/exim.conf >/tmp/exim.log 2>&1 &
'
port="$(docker port "$container" 587/tcp | sed -n 's/.*:\([0-9][0-9]*\)$/\1/p')"

starttls() {
  openssl s_client -quiet -crlf -starttls smtp \
    -connect "127.0.0.1:$port" 2>/dev/null
}

for _ in $(seq 1 20); do
  if printf 'QUIT\r\n' | starttls >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

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

printf 'EXIM-SMTP-AUTH-OK\n'
