id: whatsapp
url: http://matrix-whatsapp:29318
as_token: ${AS_TOKEN}
hs_token: ${HS_TOKEN}
sender_localpart: ${SENDER_LOCALPART}
rate_limited: false
namespaces:
  users:
    - regex: '^@whatsappbot:matrix\.compaan$'
      exclusive: true
    - regex: '^@whatsapp_.*:matrix\.compaan$'
      exclusive: true
de.sorunome.msc2409.push_ephemeral: true
receive_ephemeral: true
