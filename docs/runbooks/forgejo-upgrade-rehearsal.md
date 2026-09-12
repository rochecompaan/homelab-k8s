# Forgejo v16 upgrade rehearsal: record and runbook

## Scope

This document records the snapshot, backup, and isolated v16 rehearsal
performed on 2026-09-12. It also gives the steps to verify the production
chart render before any future upgrade window.

Production remains on `15.0.5-rootless`. No production upgrade is authorized.
Read the production hold statement at the end of this document before any
upgrade work.

## Snapshot record

| Field | Value |
|---|---|
| VolumeSnapshot name | `forgejo-pre-v16-20260912` |
| Namespace | `forgejo` |
| VolumeSnapshotContent name | `snapcontent-7157c072-e4e2-48e6-904a-1f8a4fee19e4` |
| Snapshot handle | `snap://pvc-b7b5baeb-8b60-4823-81e2-2bc6b35ba79c/snapshot-7157c072-e4e2-48e6-904a-1f8a4fee19e4` |
| Source PVC | `forgejo/gitea-shared-storage` |
| Snapshot class | `longhorn-snapshot-retain` (deletionPolicy: Retain) |
| Capture time | 2026-09-12T13:30:00Z |
| Restore size | 10 GiB |
| Ready | true |

To read the current snapshot status:

```bash
kubectl -n forgejo get volumesnapshot forgejo-pre-v16-20260912 -o json \
  | jq '{readyToUse: .status.readyToUse, restoreSize: .status.restoreSize}'
```

To read the content handle:

```bash
kubectl get volumesnapshotcontent \
  snapcontent-7157c072-e4e2-48e6-904a-1f8a4fee19e4 \
  -o jsonpath='{.status.snapshotHandle}'
```

## Outage record

| Field | Value |
|---|---|
| Outage start | 2026-09-12T13:24:04Z |
| Outage end | 2026-09-12T13:39:35Z |
| Duration | 930.472 seconds (15 minutes, 30 seconds) |

Production health checks passed after restoration:

- `GET /api/healthz`: HTTP `200`
- `GET /user/login`: HTTP `200`
- `GET /roche/croprun.git/info/refs?service=git-upload-pack`: HTTP `200`
- `GET /api/v1/admin/actions/runners`: HTTP `200`
- SSH clone read: exit `0`

## External backup record

| Field | Value |
|---|---|
| Archive path | `/home/roche/backups/forgejo/2026-09-12/forgejo-data.tar.gz.age` |
| Encryption | age, encrypted to the SOPS age recipient of the owner |
| Archive SHA-256 | `e6aec34fb7a702ea97610364da6c5320ecd27b33e6bd45c98447d19c3442dd03` |
| Checksum file | `/home/roche/backups/forgejo/2026-09-12/forgejo-data.tar.gz.age.sha256` |
| Recovery key export | `/home/roche/backups/forgejo-recovery/2026-09-12/` (sealed-secrets controller) |

CAUTION: This archive is one encrypted off-cluster copy on one workstation.
It is not an independently replicated off-site backup. Do not delete it
without a separate owner decision.

The recovery key export directory contains the sealed-secrets controller
recovery material. Never print or commit the recovery key content.

## Backup verification results

Verification ran on 2026-09-12T13:49:47Z against the plaintext restored
archive in a private tmpfs directory. The plaintext was removed after
verification.

| Check | Result |
|---|---|
| Archive file hashes | 4,808 files verified, zero mismatches |
| SQLite `PRAGMA integrity_check` | `ok` |
| `git fsck --full`: `rozanne/ylps-website.git` | exit `0`, clean |
| `git fsck --full`: `roche/pi-config.git` | exit `0`, clean |
| `git fsck --full`: `roche/upfront-infra.git` | exit `0`, clean |
| `git fsck --full`: `roche/croprun.git` | exit `0`, 68 verbose lines (no errors) |
| Historical log run 204 (task 734) SHA-256 | `3257fd73945d2b9c97df879fa15dd4c2697714e8eb46349c4d2673bc056ffb3c` |
| Historical log run 205 (task 739) SHA-256 | `b09eebbc8b824f544977764a47146c5a85751498073cc02424a320a5c3670e4a` |

## Restored PVC record

| Field | Value |
|---|---|
| PVC name | `forgejo-rehearsal-data` |
| Namespace | `forgejo-rehearsal` |
| Size | 10 GiB |
| Storage class | `longhorn` |
| Data source | `forgejo-pre-v16-20260912` (VolumeSnapshot) |
| Phase | Bound |

## Rehearsal clone record

The isolated rehearsal clone ran in namespace `forgejo-rehearsal` on image
`code.forgejo.org/forgejo/forgejo:16.0.4-rootless`.

The clone used a separate configuration file (`rehearsal.ini`). It did not
modify the original `app.ini` from the restored PVC. The original `app.ini`
was the same size, ownership, and mode before and after the rehearsal.

The clone disabled mail, SSH serving, LFS serving, cron tasks, federation,
registration, webhooks, and external lookups. It had no public ingress and
no external egress. A namespace-wide deny-all NetworkPolicy remained the
primary isolation control.

### Ephemeral secrets limitation

The rehearsal clone generates ephemeral `SECRET_KEY` and `INTERNAL_TOKEN`
values at startup. These differ from the production values in the cloned
database. Production-encrypted database fields (user passwords, two-factor
secrets, OAuth2 tokens) are encrypted with the production key. Those fields
are not readable in the clone. This is expected and does not indicate data
corruption.

Do not use the clone as a fidelity test for authentication or OAuth2 flows.
Use it only to test migration, read-only data access, and API endpoint shape.

### ConfigMap revision annotation

The rehearsal configuration is in a ConfigMap with a manual revision
annotation. If you change the ConfigMap, increment the revision annotation
in the same commit. Otherwise, Argo CD will not roll the pod.

For a future change, consider switching to a content-hashed generator to
remove this manual step.

## Runner protocol test record

A dedicated Forgejo runner `12.7.3` was registered against the rehearsal
clone only. It ran one harmless host-executor workflow in a private
disposable repository (`roche/forgejo-v16-rehearsal-20260912`).

| Field | Value |
|---|---|
| Runner version | `12.7.3` |
| Executor | host (inside the restricted runner container) |
| Run status | `success` |
| Job status | `success` |
| Marker output | `FORGEJO_REHEARSAL_PROTOCOL_OK` |

**This test proves runner 12.7.3 is protocol-compatible with Forgejo 16.**
It does not prove that the production Docker/DinD workflow works. The
production runner uses a Docker-in-Docker sidecar (`29.3.1-dind`). That
path requires a separate test in a production-equivalent environment.

## Retention policy

Retain these resources until the owner separately approves cleanup:

- Source VolumeSnapshot `forgejo/forgejo-pre-v16-20260912`
- VolumeSnapshotContent `snapcontent-7157c072-e4e2-48e6-904a-1f8a4fee19e4`
- Restored PVC `forgejo-rehearsal/forgejo-rehearsal-data`
- Encrypted archive `/home/roche/backups/forgejo/2026-09-12/forgejo-data.tar.gz.age`
- Recovery export `/home/roche/backups/forgejo-recovery/2026-09-12/`
- Database captures in the rehearsal pod and in `/tmp/forgejo-actions-investigation/task4-evidence/`
- Disposable repository `roche/forgejo-v16-rehearsal-20260912` in the clone
- All rehearsal Argo resources (`forgejo-rehearsal`, `forgejo-maintenance` apps)

Do not remove any of these resources from the cluster or workstation without
explicit owner approval.

## Full-data rollback requirement

CAUTION: Do not run the old Forgejo image against a database that a newer
release migrated. The migration is not reversible by swapping images.

To roll back from any future v16 production deployment, you must:

1. Stop Forgejo (scale to zero replicas through Git).
2. Restore the external encrypted backup to a new PVC.
3. Start Forgejo on `15.0.5-rootless` against the restored PVC.
4. Verify health, SSH access, and runner connection before returning traffic.

There is no fast rollback path. Plan for the full outage before any
production upgrade.

## Production chart render gate

Before you submit a production upgrade for approval, render the production
chart locally with the target image. Do not commit or deliver the override.

### Render command

Download the chart archive:

```bash
helm repo add forgejo https://code.forgejo.org/forgejo-helm
helm pull forgejo/forgejo --version 17.1.3
```

Render with the v16 image override:

```bash
helm template forgejo forgejo-17.1.3.tgz \
  --namespace forgejo \
  --values production-values.yaml \
  --set image.tag=16.0.4-rootless \
  > /tmp/production-v16-render.yaml
```

Note: `--skip-schema-validation` is not required for an image-only override.
It was required during the Task 2 maintenance window only because that step
set `replicaCount: 0`, which the chart schema rejects.

### Verify the rendered image

```bash
grep 'image:' /tmp/production-v16-render.yaml | grep forgejo | sort -u
```

The output must contain exactly:

```
image: "code.forgejo.org/forgejo/forgejo:16.0.4-rootless"
```

If it does not, correct the override before continuing.

### Evidence (2026-09-12)

Command run on 2026-09-12:

```
helm template forgejo /tmp/forgejo-actions-investigation/forgejo-17.1.3.tgz \
  --namespace forgejo \
  --values /tmp/forgejo-actions-investigation/production-values.yaml \
  --set image.tag=16.0.4-rootless
```

Exit: `0`. Image confirmed: `code.forgejo.org/forgejo/forgejo:16.0.4-rootless`.
This render was not committed or delivered to the cluster.

## Production state (2026-09-12)

All four Argo applications were `Synced / Healthy` at the time of this
record.

| Application | Sync | Health | Note |
|---|---|---|---|
| `forgejo` | Synced | Healthy | chart `17.1.3`, image `15.0.5-rootless` |
| `forgejo-runner` | Synced | Healthy | chart `0.7.6`, runner `12.7.3`, dind `29.3.1` |
| `forgejo-maintenance` | Synced | Healthy | snapshot class and anchor retained |
| `forgejo-rehearsal` | Synced | Healthy | isolated clone at `e151a14` |

Production Forgejo pod: `forgejo-6499f8dcf9-mtnfh`, image `15.0.5-rootless`,
restart count `0`. Version confirmed: `forgejo version 15.0.5+gitea-1.22.0`.

Production runner pod: `forgejo-runner-7df7c7f85c-sl8m5`, images
`runner:12.7.3` and `docker:29.3.1-dind`, restart counts `0/0`.

## Production hold

**Production remains on `15.0.5-rootless`.**

Do not deliver a production image change until the owner approves a
separate upgrade window. The approved scope of 2026-09-12 was snapshot
capture, external backup, and an isolated rehearsal only.

Before you request upgrade approval, complete these items:

- [ ] Owner reviews rehearsal results and residual limits.
- [ ] Owner identifies a maintenance window with the full-data rollback time budget.
- [ ] Owner approves the production upgrade in writing.
- [ ] The Docker/DinD runner path is tested in a production-equivalent environment.
- [ ] Verify the production `GET /api/v1/repos/{OWNER}/{REPO}/actions/runs/{RUN_ID}/jobs`
      response shape after the upgrade and update
      `docs/runbooks/forgejo-actions-logs.md` to remove the REHEARSAL ONLY label.
