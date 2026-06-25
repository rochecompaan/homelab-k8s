# Storage Benchmark v2 Design

Date: 2026-06-25

## Goal

Run a second, performance-only benchmark that validates the surprising Mayastor write results from the first benchmark and adds existing `local-path` storage as a local-node reference point.

## Decisions

- Treat the first Mayastor vs LINSTOR/Piraeus benchmark as concluded.
- Keep `/home/roche/homelab-k8s/.worktrees/storage-benchmark` intact for reference.
- Do all new work in `/home/roche/homelab-k8s/.worktrees/storage-benchmark-v2` on branch `feature/storage-benchmark-v2`.
- Benchmark only performance; do not repeat degraded-node or recovery observations.
- Use `fordyce` as the fixed fio consumer node for all backends.
- Include three backends:
  - existing `local-path` StorageClass, pinned to `fordyce`
  - OpenEBS Replicated PV Mayastor, 3 replicas
  - LINSTOR/Piraeus, 3 replicas
- Reuse the host benchmark LVM layout created for the first benchmark:
  - `vg-nvme/mayastor-bench` raw 30 GiB LV on each benchmark node
  - `vg-nvme/linstor-bench-thin` 30 GiB thin pool on each benchmark node
- Do not reuse old benchmark PVCs, PVs, Jobs, or data.
- Use fresh v2 PVC and Job names for every backend run.
- Use the existing `local-path` StorageClass rather than adding a benchmark-specific local-path class.

## Current Context

The first benchmark ended with the GitOps `main` branch at `deb1ea6 chore(storage): disable Piraeus benchmark`. The root app bundle no longer includes Mayastor or Piraeus benchmark apps. The v1 benchmark manifests and artifacts remain in the repository history and in the old benchmark worktree.

A fresh host check showed the benchmark LVMs still present on `dauwalter`, `fordyce`, and `selassie`. It also showed stale LINSTOR thin volumes from the first Piraeus run on `fordyce` and `selassie`:

- `vg-nvme/pvc-fac962ee-369f-46d4-a67a-645feed28492_00000`

Before running the Piraeus v2 benchmark, the plan must verify those volumes are not referenced by Kubernetes or LINSTOR and then stop for explicit approval before any host-side deletion.

The orphan `mayastor-bench-3r` StorageClass from v1 is not part of the v2 benchmark and should not be reused. The v2 Mayastor benchmark should create a new StorageClass name.

## Chosen Approach

Use new v2-specific GitOps app paths and resource names while reusing the existing operator base apps and host storage layout.

Create dormant benchmark app wrappers for:

- `storage-benchmark-v2-local-path`
- `storage-benchmark-v2-mayastor`
- `storage-benchmark-v2-piraeus`

Use existing operator app wrappers when needed:

- `openebs-mayastor` for Mayastor
- `piraeus-operator` for LINSTOR/Piraeus

Run one backend at a time by adding only the relevant app wrappers to `argocd/homelab/apps/kustomization.yaml`, committing, pushing, and letting ArgoCD reconcile. After collecting logs and health snapshots, disable that backend through GitOps before enabling the next backend.

## Benchmark Shape

Each backend run uses the same fio workload shape:

- PVC size: 20 GiB
- fio file size: 16 GiB
- passes per profile: 5
- warmup: one 1 MiB sequential write warmup before measured profiles
- measured profiles:
  - `seq-write-1m`
  - `seq-read-1m`
  - `rand-write-4k`
  - `rand-read-4k`
  - `randrw-4k-70r30w`
  - `sync-write-4k`
- default `iodepth`: 16
- `sync-write-4k` `iodepth`: 1, matching v1 semantics
- `direct=1`
- `numjobs=1`
- runtime per measured pass: 60 seconds
- ramp time per measured pass: 10 seconds

The benchmark preserves v1 profile names so v1 and v2 logs can be compared with the existing summarizer. The `sync-write-4k` profile name is retained for continuity, but it should be interpreted as single-depth 4 KiB direct writes rather than a full fsync-on-every-write durability benchmark.

## Backend Details

### local-path reference

The local-path run uses the existing `local-path` StorageClass and pins the fio Job to `fordyce` with:

```yaml
nodeSelector:
  kubernetes.io/hostname: fordyce
```

Because `local-path` uses `WaitForFirstConsumer`, the PVC should provision on `fordyce`. This reference is not replicated and is not failure tolerant. It exists only to show the local-node storage ceiling and overhead baseline.

### Mayastor

The Mayastor run uses the existing `openebs-mayastor` operator app and a new v2 benchmark app. The benchmark app creates:

- namespace `storage-benchmark-v2`
- DiskPools on `dauwalter`, `fordyce`, and `selassie`, each pointing at `aio:///dev/disk/by-id/dm-name-vg--nvme-mayastor--bench`
- StorageClass `mayastor-bench-v2-3r`
- PVC `mayastor-fio-pvc-v2-run-001`
- Job `storage-bench-mayastor-v2-run-001`, pinned to `fordyce`

### LINSTOR/Piraeus

The LINSTOR/Piraeus run uses the existing `piraeus-operator` app and a new v2 benchmark app. The benchmark app creates:

- namespace `storage-benchmark-v2`
- `LinstorCluster`
- `LinstorSatelliteConfiguration` using existing `vg-nvme/linstor-bench-thin`
- StorageClass `piraeus-bench-v2-3r`
- PVC `piraeus-fio-pvc-v2-run-001`
- Job `storage-bench-piraeus-v2-run-001`, pinned to `fordyce`

Before this run, stale host LVs from the v1 Piraeus PVC must be investigated and either proven harmless or removed with explicit approval.

## Activation Order

Recommended order:

1. local-path reference
2. Mayastor v2
3. LINSTOR/Piraeus v2

This gives a non-replicated baseline first, then repeats the replicated backend comparison. LINSTOR/Piraeus runs last because it has known stale host-side v1 LV cleanup to gate before activation.

## Artifacts

Write v2 artifacts under `docs/storage-benchmark-v2/`:

- `local-path-run-001.log`
- `local-path-run-001-summary.md`
- `local-path-run-001-health.md`
- `mayastor-v2-run-001.log`
- `mayastor-v2-run-001-summary.md`
- `mayastor-v2-run-001-health.md`
- `piraeus-v2-run-001.log`
- `piraeus-v2-run-001-summary.md`
- `piraeus-v2-run-001-health.md`
- `combined-summary.md`
- `final-comparison.md`

## Verification

Use direct verification rather than new tests for static benchmark manifests:

- `kubectl kustomize argocd/homelab/apps`
- `kubectl kustomize` for each v2 benchmark app path
- semantic checks that only the intended benchmark app is wired live before each activation
- `python3 -m unittest scripts/test_summarize_storage_benchmark.py`
- `python3 -m py_compile scripts/summarize-storage-benchmark.py`
- read-only `kubectl get`, `kubectl logs`, and backend CLI inspection for live benchmark status

## Risks and Mitigations

- The local-path reference is not replicated. Treat it only as a performance baseline, not as an availability candidate.
- Stale v1 LINSTOR thin volumes may consume capacity or confuse v2. Gate Piraeus activation on explicit stale-volume verification and approved cleanup if needed.
- The v2 file size is larger than v1 but still fits within 30 GiB backend pools. Keep PVCs at 20 GiB and do not run multiple replicated backend PVCs concurrently.
- Running all backends on `fordyce` controls consumer-node variance but does not prove performance from every possible node. That is accepted for v2.
- Direct Kubernetes writes remain out of scope. Host-side cleanup commands also require explicit approval because they are destructive.
