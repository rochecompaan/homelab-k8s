# Forgejo Actions Log Access Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Verify snapshot recovery and Forgejo 16 log access without upgrading production.

**Architecture:** Capture a retained CSI snapshot while production is stopped. Resume production, restore an isolated PVC, export an encrypted backup, and rehearse the upgrade.

**Tech Stack:** Argo CD, Kustomize, Longhorn 1.10.1, Kubernetes CSI snapshots, Forgejo, SQLite, Git, age.

## Global constraints

- Production stays on `15.0.5-rootless` and chart `17.1.3` after capture.
- Do not change the production runner or rerun historical CI jobs.
- Deliver Kubernetes resources through Git and Argo CD only.
- Do not delete snapshots, source storage, or backup archives during this task.
- The future production image override remains undelivered.
- Reference design: `docs/specs/2026-09-12-forgejo-actions-log-access-design.md`.

## Task 1: Prepare snapshot and isolation resources

**Files:**
- Create `argocd/base/forgejo-maintenance/{app.yaml,kustomization.yaml}`.
- Create `argocd/homelab/forgejo/maintenance/{kustomization.yaml,snapshot-class.yaml,anchor.yaml}`.
- Create `argocd/base/forgejo-rehearsal/{app.yaml,kustomization.yaml}`.
- Create `argocd/homelab/forgejo/rehearsal/{kustomization.yaml,namespace.yaml,network-policy.yaml,probe.yaml}`.
- Modify `argocd/homelab/apps/kustomization.yaml`.

**Interfaces:** The maintenance app owns the retained snapshot class and read-only anchor. The rehearsal app owns its isolated namespace.

- [ ] Verify the existing snapshot controller and source PVC health.
- [ ] Create `longhorn-snapshot-retain` with `type: snap` and `deletionPolicy: Retain`.
- [ ] Create a non-root anchor with the production PVC mounted read-only and required affinity to the current Forgejo pod.
- [ ] Deny all anchor network traffic and disable its service account token.
- [ ] Create the rehearsal namespace and a deny-all NetworkPolicy before application pods.
- [ ] Run Kustomize builds and YAML lint. Do not add tests that only assert static YAML.
- [ ] Obtain independent review before delivery or production maintenance.
- [ ] Commit with signing and normal hooks. Deliver only this preparation through Git.
- [ ] Wait for Argo synchronization and anchor readiness before starting the outage.
- [ ] Verify blocked egress from both the anchor and a data-free rehearsal probe, with a positive control from a non-isolated pod.
- [ ] Require restricted security contexts on every rehearsal init container and application container.

## Task 2: Capture the consistent snapshot and resume production

**Files:**
- Temporarily modify `argocd/base/forgejo/app.yaml` with `replicaCount: 0`.
- Create `argocd/homelab/forgejo/maintenance/snapshot-2026-09-12.yaml`.
- Modify the maintenance Kustomization to include that snapshot only after Forgejo exits.

**Interfaces:** Produces a ready snapshot and its immutable `snap://` handle. Restores the production replica count before any rehearsal work.

- [ ] Recheck running CI and current production image immediately before maintenance.
- [ ] Verify that the anchor and production Forgejo pods are Ready on the same node.
- [ ] Record UTC start time in the external evidence directory.
- [ ] Commit and deliver the zero-replica value. Wait for the Forgejo pod to exit normally.
- [ ] Commit and deliver the source VolumeSnapshot with `persistentVolumeClaimName: gitea-shared-storage`.
- [ ] Wait for the exact snapshot to report ready, with no error.

```sh
kubectl -n forgejo wait volumesnapshot/forgejo-pre-v16-20260912 \
  --for=jsonpath='{.status.readyToUse}'=true --timeout=180s
kubectl -n forgejo get volumesnapshot forgejo-pre-v16-20260912 -o json
```

- [ ] Scale the anchor to zero through Git and wait for its pod to exit, even if capture fails.
- [ ] Immediately remove the temporary production replica override through Git.
- [ ] Wait for the unchanged production deployment to become available.
- [ ] Record UTC recovery time and calculate actual downtime.
- [ ] Verify health, UI access, HTTPS/SSH git reads, and runner connection without dispatching CI.
- [ ] Use the existing private SSH remote `ssh://git@git.compaan/roche/croprun.git`. The public `.cloud` SSH endpoint already denied the workstation key before maintenance.
- [ ] Report capture and production recovery separately from later restore verification.

## Task 3: Restore into an isolated PVC and export the backup

**Files:**
- Create `argocd/homelab/forgejo/rehearsal/snapshot.yaml` with the captured handle.
- Create `argocd/homelab/forgejo/rehearsal/pvc.yaml`.
- Create `argocd/homelab/forgejo/rehearsal/deployment.yaml` in read-only inspection mode.
- Update the rehearsal Kustomization.

**Interfaces:** Consumes the ready source snapshot. Produces an independent 10 GiB PVC and a readable encrypted external archive.

- [ ] Read the bound source VolumeSnapshotContent and its exact snapshot handle.
- [ ] Declare a retained pre-provisioned content object bound to a snapshot in `forgejo-rehearsal`.
- [ ] Declare a 10 GiB RWO Longhorn PVC with that snapshot as its data source.
- [ ] Start the inspection deployment with image `15.0.5-rootless`, a sleep command, and a read-only PVC mount.
- [ ] Deliver through Git. Require the PVC to bind and the inspection pod to become ready.
- [ ] Prepare `/home/roche/backups/forgejo/2026-09-12` with mode 0700.
- [ ] Test an age encryption/decryption round trip using the existing recovery identity before capture.
- [ ] Stream the restored data to an encrypted external archive with shell `pipefail`.

```sh
set -o pipefail
recipient=$(age-keygen -y /home/roche/.config/sops/age/keys.txt)
backup=/home/roche/backups/forgejo/2026-09-12
kubectl -n forgejo-rehearsal exec deploy/forgejo-rehearsal -- \
  tar -C /data -czf - . | age -r "$recipient" \
  -o "$backup/forgejo-data.tar.gz.age.partial"
mv "$backup/forgejo-data.tar.gz.age.partial" "$backup/forgejo-data.tar.gz.age"
sha256sum "$backup/forgejo-data.tar.gz.age" > "$backup/forgejo-data.tar.gz.age.sha256"
```

- [ ] Export sealed-secrets controller recovery keys separately, encrypted to the same public recipient. Never print secret data.
- [ ] Decrypt the archive into a mode-0700 temporary directory under `/run/user/1000`.
- [ ] Verify archive file hashes, SQLite `PRAGMA integrity_check`, and `git fsck --full` for all restored bare repositories.
- [ ] Decode task logs 734 and 739 with zstd and compare their hashes with the previously recovered logs.
- [ ] Remove the plaintext temporary restore after successful verification.
- [ ] Report exact archive paths and verification results. State that this is one off-cluster copy, not replicated off-site storage.

## Task 4: Rehearse migration and API access

**Files:**
- Create `argocd/homelab/forgejo/rehearsal/config.yaml`.
- Modify the rehearsal deployment for a writable clone and `16.0.4-rootless`.
- Create a ClusterIP service for the clone.

**Interfaces:** Consumes only the restored PVC. Produces isolated migration and HTTP test evidence.

- [ ] Generate a separate configuration file for the clone, without changing the saved production configuration.
- [ ] Set local URLs and separate signing material. Disable mail, cron, SSH, LFS serving, and new mirrors.
- [ ] Keep default-deny ingress/egress and disable service account mounting.
- [ ] Deliver only the rehearsal change through Git.
- [ ] Require successful startup migration and application health. Inspect logs without printing sensitive configuration.
- [ ] Use a localhost port-forward to inspect old runs and native log endpoints.
- [ ] Verify run jobs is an array, job logs are plaintext, and run logs are a readable ZIP.
- [ ] Verify missing/invalid tokens cannot read private logs. Verify cross-repository IDs are rejected.
- [ ] Verify clone egress cannot reach the production service or external integrations.
- [ ] Repeat SQLite integrity verification against a consistent clone database capture.
- [ ] If registration and workflow execution are needed, declare a dedicated `12.7.3` rehearsal runner through Git.
- [ ] Use a new disposable clone-only repository and a harmless workflow with a unique runner label. Never reuse a production registration token.
- [ ] Report protocol compatibility separately from production Docker workflow verification.

## Task 5: Document results and hold the production upgrade

**Files:**
- Create `docs/runbooks/forgejo-actions-logs.md`.
- Create `docs/runbooks/forgejo-upgrade-rehearsal.md`.
- Update this plan with evidence and residual risks.

**Interfaces:** Produces durable recovery and automation guidance. Does not deliver a production version change.

- [ ] Document both `tea api` and `curl`/`jq` usage with correct run/job/attempt IDs.
- [ ] Mark API evidence as rehearsal-only until production verification exists.
- [ ] Record source snapshot identity, backup checksum, restore checks, outage duration, and clone verification.
- [ ] Record retention, cleanup approval, runner-test limits, and the full-data rollback requirement.
- [ ] Re-render the production chart with a local `16.0.4-rootless` override, without delivering it.
- [ ] Verify production remains Healthy/Synced on `15.0.5-rootless` with the original runner.
- [ ] Report production readiness and wait for explicit upgrade-window approval.
