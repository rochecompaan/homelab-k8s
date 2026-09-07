#!/bin/sh
set -eu

mkdir -p /var/log/exim4
touch /var/log/exim4/mainlog /var/log/exim4/rejectlog /var/log/exim4/paniclog
chown Debian-exim:adm /var/log/exim4 /var/log/exim4/mainlog /var/log/exim4/rejectlog /var/log/exim4/paniclog 2>/dev/null || true

if [ "${1:-}" = "-bd" ]; then
  shift
  set -- -bdf "$@"
fi

stdbuf -oL -eL tail -n +1 -F /var/log/exim4/mainlog &
main_tail_pid=$!
stdbuf -oL -eL tail -n +1 -F /var/log/exim4/rejectlog /var/log/exim4/paniclog >&2 &
error_tail_pid=$!

/usr/sbin/exim4 "$@" &
exim_pid=$!

terminate() {
  kill "$exim_pid" 2>/dev/null || true
  kill "$main_tail_pid" "$error_tail_pid" 2>/dev/null || true
}

trap terminate INT TERM

wait "$exim_pid"
status=$?

terminate
wait "$main_tail_pid" "$error_tail_pid" 2>/dev/null || true

exit "$status"
