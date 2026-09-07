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
