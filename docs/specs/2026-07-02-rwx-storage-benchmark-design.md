# RWX Storage Benchmark Design

Date: 2026-07-02

## Goal

Run a new benchmark focused on `ReadWriteMany` behavior for Longhorn, LINSTOR/Piraeus, and OpenEBS Mayastor. This is separate from the earlier RWO/block-volume storage benchmark v2.

## Chosen Approach

Use each backend's supported RWX path:

- Longhorn RWX through Longhorn share-manager NFS.
- LINSTOR/Piraeus RWX through direct `ReadWriteMany` PVCs from the LINSTOR CSI driver.
- OpenEBS Mayastor RWX through an NFS server pod and NFS CSI backed by a Mayastor RWO PVC.

This compares what each backend actually offers for RWX workloads. It is not a native block-device comparison. The final artifacts must state that all three paths include an NFS-like file-sharing layer, and that Mayastor is Mayastor-backed RWX via NFS rather than native Mayastor block RWX.

## Alternatives Considered

1. Provider-native RWX path per backend. This is the selected option because it is the shortest useful benchmark and matches real user-facing RWX behavior.
2. Common NFS shim over each backend's RWO PVC. This would isolate backend RWO performance beneath the same NFS layer, but it would not test Longhorn or Piraeus as users normally request RWX from those systems.
3. Run both provider-native and common-shim suites. This would answer more questions, but it doubles manifests, runtime, cleanup, and artifact interpretation.

## Current Evidence

- Longhorn 1.10.1 docs say RWX volumes are regular Longhorn volumes exposed through NFSv4 servers in `share-manager-*` pods.
- LINBIT LINSTOR Kubernetes docs say Operator 2.10.0+ supports `ReadWriteMany` PVCs directly through the LINSTOR CSI driver; under the hood it uses NFS and DRBD Reactor, and a three-node quorum-capable cluster is recommended.
- Current OpenEBS docs describe Replicated PV Mayastor RWX as NFS over a Mayastor-backed volume using an NFS server pod plus NFS CSI. Another OpenEBS page explicitly says Replicated PV Mayastor does not natively support RWX volumes.
- The cluster currently has Longhorn active and existing Longhorn share-manager pods. Piraeus and OpenEBS CRDs/storage classes exist from prior benchmark work, but their ArgoCD apps are not active in the bootstrap bundle.
- Existing repo patterns to reuse are under `argocd/homelab/storage-benchmark-v2-*`, `argocd/base/storage-benchmark-v2-*`, and `scripts/summarize-storage-benchmark.py`.

## Benchmark Shape

Create one temporary GitOps-managed benchmark app per backend. Run backends one at a time.

For each backend:

1. Provision an RWX PVC.
2. Prove multi-attach with two pods on different nodes mounting the same PVC and writing/reading a small marker file.
3. Run one single-client fio job for apples-to-apples comparison with the earlier v2 profiles.
4. Run one two-client concurrent fio pass with each client writing a unique file in the same RWX mount.
5. Capture backend health, placement, PVC/PV details, pod placement, and any NFS/share-manager/exporter resources.

Keep the fio profiles close to storage benchmark v2:

- `seq-write-1m`
- `seq-read-1m`
- `rand-write-4k`
- `rand-read-4k`
- `randrw-4k-70r30w`
- `sync-write-4k`

Default parameters:

- PVC size: 20 GiB when supported by the backend path.
- fio file size: 16 GiB for single-client runs.
- passes: 5 for single-client profiles.
- runtime: 60 seconds per measured pass.
- ramp time: 10 seconds.
- default `iodepth`: 16.
- `sync-write-4k` `iodepth`: 1.
- concurrent pass: two pods, unique filenames such as `/volume/${POD_NAME}-fio-test-file`, one measured pass per profile unless runtime proves too long.

If Mayastor-backed NFS introduces a smaller practical PVC size or one NFS-server bottleneck, document the difference rather than hiding it.

## Backend Details

### Longhorn

Create a benchmark-only Longhorn StorageClass for RWX that keeps the NVMe lesson from the RWO benchmark:

- provisioner: `driver.longhorn.io`
- replicas: `3`
- `diskSelector: nvme`
- `dataEngine: v1`
- access mode on the benchmark PVC: `ReadWriteMany`

Capture Longhorn volume, replica, share-manager pod, share-manager service, and disk placement details. The health artifact must prove benchmark replicas are on `/var/lib/longhorn/` NVMe-tagged disks, not `/srv/data` SATA disks.

### LINSTOR/Piraeus

Use a benchmark-specific LINSTOR/Piraeus StorageClass and an RWX PVC:

- provisioner: `linstor.csi.linbit.com`
- storage pool: `linstor-bench`
- placement count: `3`
- access mode on the benchmark PVC: `ReadWriteMany`

The RWO `piraeus-bench-v2-3r` class can be copied as a starting point, but the RWX run must validate that the class and cluster version actually create the NFS/Reactor-backed RWX path. Capture LINSTOR resource, resource definition, storage pool, pod, service, and any NFS/Reactor-related resources visible through Kubernetes or LINSTOR CLI output.

### OpenEBS Mayastor

Use Mayastor as the persistent backend for an NFS server pod, then expose RWX through NFS CSI:

- Mayastor RWO StorageClass using `io.openebs.csi-mayastor`, `protocol: nvmf`, `repl: "3"`.
- Mayastor-backed PVC mounted by a single NFS server pod.
- NFS CSI StorageClass pointing at that NFS server service.
- Benchmark RWX PVC using the NFS CSI StorageClass.

This is Mayastor-backed RWX via NFS. Do not describe it as native Mayastor RWX.

Prefer GitOps-rendered manifests for the NFS server and NFS CSI driver/app if the cluster does not already have NFS CSI installed. If NFS CSI is not present, add a temporary ArgoCD app for the driver and remove it after artifacts are captured unless it is intentionally retained.

## Artifact Layout

Create a new result directory:

- `docs/storage-benchmark-rwx/`

Expected artifacts:

- `longhorn-rwx-run-001.log`
- `longhorn-rwx-run-001-summary.md`
- `longhorn-rwx-run-001-health.md`
- `piraeus-rwx-run-001.log`
- `piraeus-rwx-run-001-summary.md`
- `piraeus-rwx-run-001-health.md`
- `mayastor-rwx-run-001.log`
- `mayastor-rwx-run-001-summary.md`
- `mayastor-rwx-run-001-health.md`
- `combined-summary.md`
- `final-comparison.md`

Raw logs must include `RESULT` rows compatible with `scripts/summarize-storage-benchmark.py` or a minimally extended parser. If the concurrent pass needs extra columns, extend the parser with tests before changing production summarizer behavior.

## Activation and Cleanup

All cluster changes must go through GitOps:

1. Add dormant benchmark app manifests and ArgoCD Application wrappers.
2. Activate one backend by adding its app to `argocd/homelab/apps/kustomization.yaml`.
3. Commit, push, and let ArgoCD reconcile.
4. Use only read-only observation commands such as `kubectl get`, `kubectl describe`, `kubectl logs`, and `kubectl wait`.
5. Capture logs and health artifacts.
6. Remove the backend app from the bootstrap bundle and let ArgoCD prune temporary resources before activating the next backend.

Do not run `kubectl apply`, `kubectl patch`, `kubectl delete`, or `helm upgrade` against homelab resources.

## Verification

Before activation:

- `kubectl kustomize argocd/homelab/apps`
- `kubectl kustomize` for each new app path
- grep/render checks for expected StorageClass names, `ReadWriteMany`, backend labels, unique fio filenames, and node placement controls
- `python3 scripts/test_summarize_storage_benchmark.py`
- `python3 scripts/test-just-targets.py`

During and after runs:

- read-only ArgoCD Application status checks
- read-only PVC/PV/job/pod status checks
- read-only logs for fio jobs and multi-attach proof pods
- backend-specific health captures for Longhorn, LINSTOR/Piraeus, Mayastor, and NFS resources
- summary generation with `scripts/summarize-storage-benchmark.py`

## Risks and Mitigations

- RWX introduces NFS/server bottlenecks. Keep final interpretation focused on RWX path behavior, not raw block performance.
- Mayastor's RWX path is a composed NFS design. Label it clearly and avoid claiming native Mayastor RWX.
- Piraeus RWX may require details not present in the RWO StorageClass. Validate with a small RWX PVC and multi-attach proof before running fio.
- Longhorn default StorageClass may place data on SATA. Use `diskSelector: nvme` and capture replica disk paths.
- Running multiple benchmark PVCs at once can consume pool capacity and distort results. Activate one backend at a time.
- NFS client support is required on client nodes. If a mount fails with missing NFS helper errors, stop and document the node prerequisite instead of changing nodes by hand.

## Acceptance Criteria

- The benchmark is provider-native RWX per backend.
- Each backend has a multi-attach proof before fio results are accepted.
- Results include raw logs, summaries, health/placement artifacts, and final comparison.
- Final comparison highlights throughput and p99 latency.
- Artifacts identify NFS/share-manager/Reactor/NFS CSI components involved.
- Temporary benchmark apps/resources are pruned through GitOps after capture.
