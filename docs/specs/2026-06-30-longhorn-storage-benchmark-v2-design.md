# Longhorn Storage Benchmark v2 Add-On Design

## Goal

Add one quick Longhorn run to the existing storage benchmark v2 results before making a storage decision.

This run tests the cluster's default `longhorn` StorageClass because it has no `sata` disk selector and should exercise the default NVMe-backed Longhorn path rather than the `longhorn-sata` class.

## Decisions

- Use the existing default `longhorn` StorageClass.
- Keep the same benchmark shape as storage benchmark v2.
- Pin the fio consumer pod to `fordyce`, matching the earlier v2 runs.
- Use GitOps only. Do not run `kubectl apply`, `kubectl patch`, `kubectl delete`, or `helm upgrade` against homelab resources.
- Add Longhorn results to `docs/storage-benchmark-v2/` and update the final comparison.

## Current Context

The existing v2 benchmark compared:

- `local-path`
- OpenEBS Mayastor, 3 replicas
- LINSTOR/Piraeus, 3 replicas

The cluster already has these Longhorn StorageClasses:

- `longhorn`
- `longhorn-sata`
- `longhorn-static`

The default `longhorn` StorageClass uses `driver.longhorn.io`, `numberOfReplicas: "3"`, `dataEngine: v1`, `volumeBindingMode: Immediate`, and no `diskSelector`. The `longhorn-sata` class has `diskSelector: sata`, so it is intentionally not used for this NVMe-focused test.

## Chosen Approach

Create a new GitOps benchmark app named `storage-benchmark-v2-longhorn`.

The app creates:

- namespace `storage-benchmark-v2` if needed
- PVC `longhorn-fio-pvc-v2-run-001`
- Job `storage-bench-longhorn-v2-run-001`

The PVC uses:

```yaml
storageClassName: longhorn
resources:
  requests:
    storage: 20Gi
```

The Job reuses the existing v2 fio workload script with only backend names and PVC claim names changed.

## Benchmark Shape

Use the same workload as v2:

- PVC size: 20 GiB
- fio file size: 16 GiB
- measured passes: 5
- runtime per measured pass: 60 seconds
- warmup: existing v2 warmup behavior
- `numjobs=1`
- default `iodepth=16`
- `sync-write-4k` uses `iodepth=1`

Profiles:

- `seq-read-1m`
- `seq-write-1m`
- `rand-read-4k`
- `rand-write-4k`
- `randrw-4k-70r30w`
- `sync-write-4k`

## Activation

Activation stays GitOps-only:

1. Add the Longhorn benchmark app under `argocd/base/storage-benchmark-v2-longhorn/`.
2. Add manifests under `argocd/homelab/storage-benchmark-v2-longhorn/`.
3. Temporarily add the app to `argocd/homelab/apps/kustomization.yaml`.
4. Let ArgoCD reconcile it.
5. Capture logs and health output.
6. Remove the app from the bootstrap bundle after results are captured.

## Artifacts

Write these artifacts under `docs/storage-benchmark-v2/`:

- `longhorn-v2-run-001.log`
- `longhorn-v2-run-001-summary.md`
- `longhorn-v2-run-001-health.md`

Then update:

- `docs/storage-benchmark-v2/combined-summary.md`
- `docs/storage-benchmark-v2/final-comparison.md`

## Verification

Before activation:

- validate kustomize output for the new app path
- confirm manifests reference `storageClassName: longhorn`
- confirm the Job is pinned to `fordyce`

After activation:

- confirm the Job completes successfully
- confirm Longhorn reports the volume healthy with 3 replicas
- summarize fio output with `scripts/summarize-storage-benchmark.py`
- compare Longhorn rows against the existing v2 table

## Risks and Mitigations

- Longhorn uses `Immediate` binding, so replica placement happens before the fio pod is scheduled. Keep the consumer pod pinned to `fordyce` for workload consistency and record Longhorn volume placement in the health artifact.
- The default `longhorn` class has no `diskSelector`. Confirm in the health artifact that the benchmark volume did not use `sata`-tagged disks.
- The benchmark app is temporary. Remove it from the bootstrap bundle after artifacts are captured.
