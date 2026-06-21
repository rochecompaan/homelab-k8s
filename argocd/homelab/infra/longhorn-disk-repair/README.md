# Longhorn disk repair job

GitOps-managed repair manifests for clearing stale Longhorn disk records after
the 2026-06-21 benchmark-node reinstalls.

When this directory is referenced by `argocd/homelab/infra/kustomization.yaml`
and the `Job` has `spec.suspend: false`, ArgoCD will create and run the repair
job in `longhorn-system`.

## What the job is intended to do

The job uses the Kubernetes API from inside the cluster to repair Longhorn
`Node` custom resources in the `longhorn-system` namespace.

It removes stale disk records only when Longhorn already reports
`DiskFilesystemChanged`, `storageScheduled=0`, and no `scheduledReplica` entries
for the stale disk. It refuses to touch running replicas.

It deletes stopped stale Longhorn `Replica` CRs that still reference the old disk
UUIDs, then replaces the disk records with stable names:

| Node | Remove stale disk | Add fresh disk | Path | Tags |
| --- | --- | --- | --- | --- |
| `dauwalter` | `default-disk-b5dbf4849fa96599` | `longhorn-root` | `/var/lib/longhorn/` | `[]` |
| `fordyce` | `default-disk-fec640abc4d0caff` | `longhorn-root` | `/var/lib/longhorn/` | `[]` |
| `selassie` | `default-disk-75fe019eb4ad6eea` | `longhorn-root` | `/var/lib/longhorn/` | `[]` |
| `selassie` | `disk-1` | `longhorn-sata` | `/srv/data` | `["sata"]` |

## Activation status

The operator approved activation after reviewing the dormant manifests. The
activation change should:

1. Add `longhorn-disk-repair` to `argocd/homelab/infra/kustomization.yaml`.
2. Change `spec.suspend` in `job.yaml` from `true` to `false`.
3. Commit and deliver through the normal GitOps path.
4. Watch read-only status:

   ```bash
   KUBECONFIG=/home/roche/homelab-k8s/.kubeconfig kubectl -n longhorn-system get jobs,pods
   KUBECONFIG=/home/roche/homelab-k8s/.kubeconfig kubectl -n longhorn-system get nodes.longhorn.io
   KUBECONFIG=/home/roche/homelab-k8s/.kubeconfig kubectl -n longhorn-system get volumes.longhorn.io
   ```

## Rollback

If the job has not been unsuspended, remove this directory or leave it unreferenced.
If it has run, review Longhorn `Node`, `Volume`, and `Replica` CR status before
making further changes. Do not recreate stale disk records.
