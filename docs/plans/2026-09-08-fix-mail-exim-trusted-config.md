# Fix Mail Exim Trusted Configuration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep Exim privileged when it loads the Kubernetes-managed configuration so local delivery can switch from `Debian-exim` to the `vmail` UID/GID.

**Architecture:** Mount the existing ConfigMap key at Exim's first default trusted configuration path, `/etc/exim4/exim4.conf`, and start Exim without `-C`. De-taint the virtual mailbox path by retrieving the canonical recipient address from the trusted passwd file with `lsearch,ret=key`. Preserve the current mailbox ownership model and prove both fixes by extending the existing container integration test to deliver a real message into the Maildir.

**Tech Stack:** Exim 4.96, Docker, Kubernetes Deployment manifests, Kustomize, Bash, Python standard library, OpenSSL

## Global Constraints

- Make repository changes only; do not mutate Kubernetes or publish DNS.
- Do not change outbound routing while the provider considers opening TCP/25.
- Do not expose mail credentials or DKIM/identity key material.
- Do not push an image or commit without explicit authorization.
- Keep `vmail` UID/GID 5000 and the existing Maildir ownership model.
- Extend the existing behavior test instead of adding a test that only asserts YAML text.

---

### Task 1: Preserve Exim privilege for local Maildir delivery

**Files:**
- Modify: `docker/mail/exim/test-smtp-auth.sh`
- Modify: `docker/mail/exim/Dockerfile`
- Modify: `argocd/homelab/mail/deployments.yaml`
- Modify: `argocd/homelab/mail/exim.conf`
- Modify: `argocd/homelab/mail/kustomization.yaml`
- Modify: `docs/specs/2026-08-15-compaan-cloud-mail-design.md`
- Modify: `docs/plans/2026-08-15-compaan-cloud-mail.md`

**Interfaces:**
- Consumes: ConfigMap key `exim.conf`, account fixture `roche@compaan.cloud`, and Maildir root `/var/mail/vmail`.
- Produces: Exim startup through `/etc/exim4/exim4.conf` without `-C`, while preserving SMTP AUTH and local Maildir delivery.

- [x] **Step 1: Build the current Exim image**

Run:

```sh
docker build -t mail-exim:dev docker/mail/exim
```

Expected: exit 0.

- [x] **Step 2: Add a local-delivery regression assertion before changing startup behavior**

Extend `docker/mail/exim/test-smtp-auth.sh` to submit a message through the running container's SMTP listener with Python's synchronized `smtplib` client, a null envelope sender, STARTTLS, and recipient `roche@compaan.cloud`. Wait for a file under `/var/mail/vmail/compaan.cloud/roche/Maildir/new`, and fail with sanitized Exim logs if delivery does not occur. Keep the current `/etc/exim4/exim.conf` and `-C` setup for the red run.

The production regression caught by this assertion is: Exim accepts a local recipient but cannot switch from UID 100 to UID/GID 5000, so no Maildir message appears.

- [x] **Step 3: Run the integration test and verify the expected failure**

Run:

```sh
docker/mail/exim/test-smtp-auth.sh
```

Expected: non-zero exit because the Maildir message is absent; the delivery log contains `exim user lost privilege for using -C option` and `unable to set gid=5000 or uid=5000 (euid=100)`.

- [x] **Step 4: Move the test fixture to the trusted default configuration path**

In `docker/mail/exim/test-smtp-auth.sh`:

- Copy the config to `/etc/exim4/exim4.conf`.
- Set ownership and mode on `/etc/exim4/exim4.conf`.
- Validate with `/usr/sbin/exim4 -bV` without `-C`.
- Start the daemon with `/usr/sbin/exim4 -bd` without `-C`.
- Start the unchanged image entrypoint and default command after installing a ConfigMap-like `root:5000`, mode-0644 fixture.

- [x] **Step 5: Update production startup and mount paths**

In `docker/mail/exim/Dockerfile`, replace:

```dockerfile
CMD ["-bd", "-q30m", "-C", "/etc/exim4/exim.conf"]
```

with:

```dockerfile
CMD ["-bd", "-q30m"]
```

In `argocd/homelab/mail/deployments.yaml`, use:

```yaml
args: ["-bd", "-q30m"]
```

and mount the existing ConfigMap key at:

```yaml
mountPath: /etc/exim4/exim4.conf
subPath: exim.conf
```

In `argocd/homelab/mail/kustomization.yaml`, bump only the Exim image tag to `2026-09-08`. Keep the Dovecot image tag unchanged.

- [x] **Step 6: De-taint the validated virtual mailbox path**

In `argocd/homelab/mail/exim.conf`, make the successful account lookup return an untainted copy of its key:

```exim
address_data = ${lookup{$local_part@$domain}lsearch,ret=key{/etc/exim4/auth/passwd}{$value}{}}
```

Build the transport directory from that trusted canonical address:

```exim
directory = /var/mail/vmail/${domain:$address_data}/${local_part:$address_data}/Maildir
```

This keeps attacker-controlled SMTP values out of filesystem paths while preserving the existing account database and layout.

- [x] **Step 7: Correct the maintained design and plan references**

Replace instructions that start Exim with `-C /etc/exim4/exim.conf` or describe that as the runtime path with the trusted default path and startup command. Update the documented router and transport snippets to use the validated, untainted canonical address. Do not change unrelated historical content.

- [x] **Step 8: Rebuild and verify the behavior test passes**

Run:

```sh
docker build -t mail-exim:dev -t harbor.compaan/mail/exim:2026-09-08 docker/mail/exim
docker/mail/exim/test-smtp-auth.sh
```

Expected: exit 0 with `EXIM-SMTP-AUTH-OK` and a local-delivery success marker; no `lost privilege for using -C option` or UID/GID delivery error.

- [x] **Step 9: Verify the rendered Kubernetes configuration**

Run:

```sh
kubectl kustomize argocd/homelab/mail >/tmp/mail-rendered.yaml
```

Inspect the rendered Exim container and require:

- arguments `-bd` and `-q30m`, with no `-C`;
- ConfigMap key `exim.conf` mounted at `/etc/exim4/exim4.conf`;
- Exim image `harbor.compaan/mail/exim:2026-09-08`;
- unchanged `fsGroup: 5000`, mail storage, secrets, services, and NodePorts.

Expected: render exits 0 and all requirements are present.

- [x] **Step 10: Review the repository diff**

Run:

```sh
git diff --check
git status --short
git diff --stat
git diff -- docker/mail/exim/test-smtp-auth.sh docker/mail/exim/Dockerfile argocd/homelab/mail/deployments.yaml argocd/homelab/mail/exim.conf argocd/homelab/mail/kustomization.yaml docs/specs/2026-08-15-compaan-cloud-mail-design.md docs/plans/2026-08-15-compaan-cloud-mail.md
```

Expected: only the scoped trusted-config fix, regression test, and documentation references are changed. Leave all changes uncommitted pending explicit authorization.

**Release prerequisite met:** With explicit authorization, `harbor.compaan/mail/exim:2026-09-08` was published and verified with `docker manifest inspect`. Remote manifest digest: `sha256:0d4cd39ee15188c8c100dde1edd529e8d80985d323d4591f864f195c830b936a`.
