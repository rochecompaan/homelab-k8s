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
CMD ["-bd", "-q30m"]
