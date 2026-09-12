# Forgejo Actions log access and upgrade rehearsal

## Approval and boundaries

The owner approved snapshot preparation, a brief backup outage, external backup, and an isolated upgrade rehearsal on 2026-09-12.
Production must return to `15.0.5-rootless` after snapshot capture.
Production deployment of `16.0.4-rootless` needs a separate maintenance approval.
Keep the production runner and Helm chart versions unchanged.
Do not rerun historical CI jobs or clean up Git hooks.
All Kubernetes resource changes pass through Git and Argo CD.

## Current deployment

- Server: `argocd/base/forgejo/app.yaml`, chart `17.1.3`, image `15.0.5-rootless`, namespace `forgejo`.
- Runner: `argocd/base/forgejo-runner/app.yaml`, chart `0.7.6`, runner `12.7.3`, Docker `29.3.1-dind`.
- Data: `gitea-shared-storage`, 10 GiB Longhorn RWO, mounted at `/data`.
- SQLite: `/data/forgejo.db`. Repositories: `/data/git/gitea-repositories`.
- Longhorn: `1.10.1`, v1 data engine. The CSI snapshot controller and CRDs already exist.
- There is no configured Longhorn backup target or VolumeSnapshotClass.

## Capture design

Create a retained CSI snapshot class with driver `driver.longhorn.io` and parameter `type: snap`.
Do not use the default backup snapshot type without a configured backup target.

A temporary maintenance pod mounts the production PVC read-only on the same node as Forgejo.
It has no network access, service account token, or application process.
Its mount keeps the Longhorn engine attached during the brief Forgejo outage.

Before the outage, verify that the anchor and Forgejo occupy the same node.
After confirming no active jobs, declare zero Forgejo replicas through Git.
Wait for the Forgejo pod to exit before declaring the dated VolumeSnapshot through Git.
Require `readyToUse: true` and record its source volume, handle, creation time, and size.
Scale the anchor to zero through Git and wait for its pod to exit.
This releases the RWO attachment before Kubernetes schedules production again.
Immediately restore one production replica on the unchanged image through Git.
Record both the outage duration and the time to restored application health.
If capture fails, release the anchor and restore the original replica count before further diagnosis.

## Restore and external backup

Create a separate `forgejo-rehearsal` namespace with default-deny ingress and egress.
Before restoring private data, use a data-free probe pod to verify that egress is blocked.
Verify the same network control on the anchor before the outage.
Use reachable production targets as positive controls outside the isolated pods.
Import the captured handle through a retained, pre-provisioned VolumeSnapshotContent and a namespaced VolumeSnapshot.
This avoids cross-namespace PVC references and does not modify the source snapshot.
Create a 10 GiB PVC from the imported snapshot.
Both snapshot references and the rehearsal PVC require explicit retention during cleanup.

Start a read-only inspection deployment on the restored PVC, initially with the current Forgejo image and a sleep command.
Do not start the cloned Forgejo application before the external backup is complete.
Stream a complete tar archive from this restored volume through `age` to the workstation.
Use `/home/roche/backups/forgejo/2026-09-12/` on `kipchoge`, outside the production cluster.
Encrypt to the owner's existing SOPS age recipient.
Keep the private recovery key outside the cluster and outside the backup directory.

Preserve the sealed-secrets controller recovery material as a separate encrypted archive.
The workstation copy is an encrypted off-cluster backup, not an independently replicated off-site backup.
Record that limitation explicitly.

Decrypt the external archive into a private temporary directory on workstation tmpfs.
Verify full archive readability, file hashes, SQLite integrity, Git object integrity, and decoding of historical job logs.
Remove plaintext verification files after verification.
Retain the encrypted archive, ciphertext checksum, capture metadata, and sanitized verification evidence.

## Isolated application rehearsal

After backup verification, replace the inspection command with a separate Forgejo deployment on the restored PVC.
Use the explicit `16.0.4-rootless` image and a new, isolated configuration file.
Keep the original production configuration in the backup unchanged.

The isolated configuration uses the cloned SQLite database and repositories.
It disables mail, SSH, LFS serving, cron tasks, and new mirrors.
It uses localhost URLs and separate generated signing material.
Default-deny networking remains the main control against copied integrations or credentials reaching production.
There is no public ingress, external DNS change, host network, or production runner connection.
Use a local port-forward for API and UI checks.

Require successful startup migrations, SQLite integrity, readable old job logs, and HTTP endpoint checks.
Verify missing and invalid tokens cannot read private logs.
Verify mismatched repository/run or repository/job IDs cannot expose another repository's logs.

A dedicated temporary runner can test the `12.7.3` registration, task, and log protocol against the clone.
Use a new disposable repository and a harmless workflow with a unique runner label.
Use no production registration token and no historical reruns.
This protocol test does not replace a later normal production Docker workflow check.

## API contract

Forgejo 16 returns a bare array from `GET /repos/{owner}/{repo}/actions/runs/{run_id}/jobs`.
It returns plaintext from `GET /repos/{owner}/{repo}/actions/jobs/{job_id}/logs`.
It returns a ZIP from `GET /repos/{owner}/{repo}/actions/runs/{run_id}/logs`.
Use `?attempt=N` on the job log endpoint for historical attempts.

The unmodified tea all-jobs command expects an object containing `jobs`, so it is incompatible.
The `--follow` path also requires a job-detail route absent from this stable release.
Document `tea api` and `curl` with `jq` instead.
Do not describe rehearsal verification as live production verification.

## Rollback and release gate

Keep the immutable source snapshot and encrypted backup until the owner approves retention changes.
Production rollback requires the matching full data restore and old image/configuration.
Never run the old image against a database migrated by a newer release.
Do not deliver the production image override until the owner approves its separate upgrade window.

## Verification policy

These changes are Kubernetes configuration and an operational rehearsal.
Do not add tests that only restate manifest values.
Use Kustomize builds, Helm rendering, schema checks when available, independent review, and live isolated verification.
Test any new reusable parsing or validation logic before implementation.

## References

- <https://longhorn.io/docs/1.10.1/snapshots-and-backups/csi-snapshot-support/csi-volume-snapshot-associated-with-longhorn-snapshot/>
- <https://kubernetes.io/docs/concepts/storage/volume-snapshots/>
- <https://forgejo.org/docs/v16.0/admin/upgrade/>
- <https://codeberg.org/forgejo/forgejo/src/tag/v16.0.4/routers/api/v1/repo/action.go>
