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

- [x] Verify the existing snapshot controller and source PVC health.
- [x] Create `longhorn-snapshot-retain` with `type: snap` and `deletionPolicy: Retain`.
- [x] Create a non-root anchor with the production PVC mounted read-only and required affinity to the current Forgejo pod.
- [x] Deny all anchor network traffic and disable its service account token.
- [x] Create the rehearsal namespace and a deny-all NetworkPolicy before application pods.
- [x] Run Kustomize builds and YAML lint. Do not add tests that only assert static YAML.
- [x] Obtain independent review before delivery or production maintenance.
- [x] Commit with signing and normal hooks. Deliver only this preparation through Git.
- [x] Wait for Argo synchronization and anchor readiness before starting the outage.
- [x] Verify blocked egress from both the anchor and a data-free rehearsal probe, with a positive control from a non-isolated pod.
- [x] Require restricted security contexts on every rehearsal init container and application container.

## Task 2: Capture the consistent snapshot and resume production

**Files:**
- Temporarily modify `argocd/base/forgejo/app.yaml` with `replicaCount: 0` and `helm.skipSchemaValidation: true`.
  Chart 17.1.3 requires at least one replica in its values schema, although its Deployment template supports zero.
  Verify the exact rendered zero-replica Deployment with `helm template --skip-schema-validation` before delivery.
  This narrow maintenance exception does not skip commit signing, hooks, YAML lint, or rendered manifest checks.
- Create `argocd/homelab/forgejo/maintenance/snapshot-2026-09-12.yaml`.
- Modify the maintenance Kustomization to include that snapshot only after Forgejo exits.

**Interfaces:** Produces a ready snapshot and its immutable `snap://` handle. Restores the production replica count before any rehearsal work.

- [x] Recheck running CI and current production image immediately before maintenance.
- [x] Verify that the anchor and production Forgejo pods are Ready on the same node.
- [x] Record UTC start time in the external evidence directory.
- [x] Commit and deliver the zero-replica value. Wait for the Forgejo pod to exit normally.
- [x] Commit and deliver the source VolumeSnapshot with `persistentVolumeClaimName: gitea-shared-storage`.
- [x] Wait for the exact snapshot to report ready, with no error.

```sh
kubectl -n forgejo wait volumesnapshot/forgejo-pre-v16-20260912 \
  --for=jsonpath='{.status.readyToUse}'=true --timeout=180s
kubectl -n forgejo get volumesnapshot forgejo-pre-v16-20260912 -o json
```

- [x] Scale the anchor to zero through Git and wait for its pod to exit, even if capture fails.
- [x] Immediately remove both the temporary replica override and `skipSchemaValidation` through Git.
- [x] Wait for the unchanged production deployment to become available.
- [x] Record UTC recovery time and calculate actual downtime.
- [x] Verify health, UI access, HTTPS/SSH git reads, and runner connection without dispatching CI.
- [x] Use the existing private SSH remote `ssh://git@git.compaan/roche/croprun.git`. The public `.cloud` SSH endpoint already denied the workstation key before maintenance.
- [x] Report capture and production recovery separately from later restore verification.

## Task 3: Restore into an isolated PVC and export the backup

**Files:**
- Create `argocd/homelab/forgejo/rehearsal/snapshot.yaml` with the captured handle.
- Create `argocd/homelab/forgejo/rehearsal/pvc.yaml`.
- Create `argocd/homelab/forgejo/rehearsal/deployment.yaml` in read-only inspection mode.
- Update the rehearsal Kustomization.

**Interfaces:** Consumes the ready source snapshot. Produces an independent 10 GiB PVC and a readable encrypted external archive.

- [x] Read the bound source VolumeSnapshotContent and its exact snapshot handle.
- [x] Declare a retained pre-provisioned content object bound to a snapshot in `forgejo-rehearsal`.
- [x] Declare a 10 GiB RWO Longhorn PVC with that snapshot as its data source.
- [x] Start the inspection deployment with image `15.0.5-rootless`, a sleep command, and a read-only PVC mount.
- [x] Deliver through Git. Require the PVC to bind and the inspection pod to become ready.
- [x] Prepare `/home/roche/backups/forgejo/2026-09-12` with mode 0700.
- [x] Test an age encryption/decryption round trip using the existing recovery identity before capture.
- [x] Stream the restored data to an encrypted external archive with shell `pipefail`.

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

- [x] Export sealed-secrets controller recovery keys separately, encrypted to the same public recipient. Never print secret data.
- [x] Decrypt the archive into a mode-0700 temporary directory under `/run/user/1000`.
- [x] Verify archive file hashes, SQLite `PRAGMA integrity_check`, and `git fsck --full` for all restored bare repositories.
- [x] Decode task logs 734 and 739 with zstd and compare their hashes with the previously recovered logs.
- [x] Remove the plaintext temporary restore after successful verification.
- [x] Report exact archive paths and verification results. State that this is one off-cluster copy, not replicated off-site storage.

## Task 4: Rehearse migration and API access

**Files:**
- Create `argocd/homelab/forgejo/rehearsal/config.yaml`.
- Modify the rehearsal deployment for a writable clone and `16.0.4-rootless`.
- Create a ClusterIP service for the clone.

**Interfaces:** Consumes only the restored PVC. Produces isolated migration and HTTP test evidence.

- [x] Generate a separate configuration file for the clone, without changing the saved production configuration.
- [x] Set local URLs and separate signing material. Disable mail, cron, SSH, LFS serving, and new mirrors.
- [x] Keep default-deny ingress/egress and disable service account mounting.
- [x] Deliver only the rehearsal change through Git.
- [x] Require successful startup migration and application health. Inspect logs without printing sensitive configuration.
- [x] Use a localhost port-forward to inspect old runs and native log endpoints.
- [x] Verify run jobs is an array, job logs are plaintext, and run logs are a readable ZIP.
- [x] Verify missing/invalid tokens cannot read private logs. Verify cross-repository IDs are rejected.
- [x] Verify clone egress cannot reach the production service or external integrations.
- [x] Repeat SQLite integrity verification against a consistent clone database capture.
- [x] If registration and workflow execution are needed, declare a dedicated `12.7.3` rehearsal runner through Git.
- [x] Use a new disposable clone-only repository and a harmless workflow with a unique runner label. Never reuse a production registration token.
- [x] Report protocol compatibility separately from production Docker workflow verification.

## Task 5: Document results and hold the production upgrade

**Files:**
- Create `docs/runbooks/forgejo-actions-logs.md`.
- Create `docs/runbooks/forgejo-upgrade-rehearsal.md`.
- Update this plan with evidence and residual risks.

**Interfaces:** Produces durable recovery and automation guidance. Does not deliver a production version change.

- [x] Document both `tea api` and `curl`/`jq` usage with correct run/job/attempt IDs.
- [x] Mark API evidence as rehearsal-only until production verification exists.
- [x] Record source snapshot identity, backup checksum, restore checks, outage duration, and clone verification.
- [x] Record retention, cleanup approval, runner-test limits, and the full-data rollback requirement.
- [x] Re-render the production chart with a local `16.0.4-rootless` override, without delivering it.
- [x] Verify production remains Healthy/Synced on `15.0.5-rootless` with the original runner.
- [x] Report production readiness and wait for explicit upgrade-window approval.

## Residual risks and limits

- Runner protocol test used the host executor inside a restricted container. It proves runner 12.7.3 is compatible with the Forgejo 16 protocol. It does not prove the production Docker/DinD execution model works.
- The rehearsal clone generates ephemeral `SECRET_KEY` and `INTERNAL_TOKEN` values. Production-encrypted database fields are not readable in the clone. Authentication and OAuth2 flows are not fidelity-tested.
- The external archive is one encrypted off-cluster copy on one workstation (`kipchoge`). It is not independently replicated off-site.
- The rehearsal ConfigMap uses a manual revision annotation. Increment the annotation if the ConfigMap changes, or switch to a content-hashed generator.
- The pre-start cryptographic hash of the original `app.ini` was not captured. Size, ownership, and mode were verified unchanged before and after.
- No Kubeconform schemas exist for VolumeSnapshot, VolumeSnapshotContent, or SealedSecret. Those three resources were skipped in schema validation. All built-in resources passed strict validation.
- Production v16 delivery is not authorized. Await explicit owner approval and a Docker/DinD runner test before scheduling an upgrade window.
