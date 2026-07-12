# Homelab storage benchmark report

## Executive summary

The benchmark campaign started with a practical question: which storage backend should carry homelab app state and shared storage as the cluster moves beyond node-local volumes? The answer is not a single backend for every workload.

For **replicated RWO app state**, the best next step is: **proceed with one non-critical app trial on Mayastor**. Mayastor was the strongest replicated write backend in the canonical v2 benchmark: it led random write, mixed read/write, and sync write profiles, and was effectively tied with Piraeus/LINSTOR on sequential writes. That write behavior matters most for many stateful applications.

Keep **Longhorn on NVMe** as the practical fallback. The retained Longhorn result is the NVMe-specific rerun, not the discarded default Longhorn run that placed replicas on SATA disks. Longhorn NVMe did not beat Mayastor for app-state write throughput, and the strict RWO read benchmark still leaves Piraeus as the stronger read-specialist candidate, but Longhorn remains useful as a fallback if Mayastor's operational issues outweigh its performance advantage.

Do **not** choose **Piraeus/LINSTOR** as the first write-sensitive default from these results. Piraeus had outstanding read numbers, and the corrected strict RWO rerun confirmed that read strength with healthy `UpToDate` resources. Its write throughput and write tail latency were much weaker in the app-state benchmark, and the campaign exposed enough lifecycle and cleanup friction that it should not be the first default for write-sensitive application state.

Keep **local-path** in perspective: it is the non-replicated local baseline and write ceiling, not a replicated storage recommendation. It is useful for disposable state, workloads with their own replication, or performance reference points, but it does not solve node failure or shared-storage requirements.

## What we were trying to optimize for

The goal was to identify the most suitable storage backend for two different homelab storage roles:

1. **RWO app state**: databases, queues, and application data volumes that are mounted by one pod at a time but should survive node loss better than local-path.
2. **RWX shared storage**: volumes mounted by multiple consumers, such as shared files, media-like data, or services that need a ReadWriteMany abstraction.

Those roles stress storage differently. App-state workloads are often sensitive to small random writes, mixed read/write behavior, and tail latency. Shared-storage workloads are more sensitive to serving locality, NFS/share-manager placement, remote clients, and concurrent access behavior.

The benchmarks therefore distinguish four concepts that should not be collapsed into one ranking:

- **Local baseline vs replicated storage**: `local-path` shows the local-node ceiling but is intentionally not replicated.
- **RWO vs RWX**: RWO app-state and RWX shared-storage benchmarks use different access patterns and different operational paths.
- **Read-heavy vs write-sensitive workloads**: Piraeus is compelling for reads, while Mayastor is the better write-sensitive candidate from these results.
- **Performance vs readiness**: benchmark wins are not enough without monitoring, restore paths, rollback steps, and cleanup confidence.

## Benchmark matrix and methodology evolution

The benchmark docs now form a layered evidence set. The canonical files are the final comparison docs; raw logs and health captures are supporting evidence.

### Canonical replicated app-state benchmark

The primary app-state comparison is [`docs/storage-benchmark-v2/final-comparison.md`](storage-benchmark-v2/final-comparison.md). It covers:

- fixed fio consumer node: `fordyce`
- 20 GiB PVCs
- 16 GiB fio files
- five passes per profile
- `local-path`, 3-replica Mayastor, 3-replica Piraeus/LINSTOR, and 3-replica Longhorn NVMe

This is the main source for the RWO app-state recommendation.

### Corrected strict RWO read-after-write benchmark

The strict RWO comparison is [`docs/storage-benchmark-rwo-strict/final-comparison.md`](storage-benchmark-rwo-strict/final-comparison.md). It controls consumer placement more explicitly:

- writer pod on `fordyce`
- reader pods on `dauwalter` and `selassie`
- read-only profiles after the writer phase
- local or up-to-date reader-side replicas/resources are allowed and documented

The canonical Piraeus result is **run 003**, summarized in [`piraeus-run-003-summary.md`](storage-benchmark-rwo-strict/piraeus-run-003-summary.md) with health evidence in [`piraeus-run-003-health.md`](storage-benchmark-rwo-strict/piraeus-run-003-health.md). Piraeus run 001 is historical only because LINSTOR reported `Diskless, SkipDisk (R)` on `dauwalter`.

### Controlled RWX benchmark

The controlled RWX comparison is [`docs/storage-benchmark-rwx-controlled/final-comparison.md`](storage-benchmark-rwx-controlled/final-comparison.md). It supersedes the original uncontrolled RWX ranking because it fixes the most important locality variables:

- active serving component on `fordyce`
- fio clients on `dauwalter` and `selassie`
- no fio client on `fordyce`
- `walmsley` and `kipsang` excluded from serving/client roles

The Mayastor RWX entry is not native Mayastor RWX. It is **Mayastor-backed RWX via NFS/NFS CSI**: Mayastor provides a replicated RWO backend PVC, which is exported by an NFS server and consumed through the NFS CSI driver.

## Final app-state/RWO results and interpretation

The final app-state evidence points to a split result: **strict RWO run 003 supports Piraeus for reads, while v2 supports Mayastor for writes**. This report does not use the v2 read rows as canonical read evidence; the read claims below come from the strict RWO benchmark.

The v2 write-oriented app-state results were:

| Workload | Longhorn NVMe | Mayastor | Piraeus/LINSTOR | Winner among replicated backends |
| --- | ---: | ---: | ---: | --- |
| Sequential write | 35 MiB/s | 56 MiB/s | 54 MiB/s | Mayastor, narrowly |
| 4 KiB random write | 8.3k IOPS / 32.5 MiB/s | 12.5k IOPS / 48.8 MiB/s | 1.1k IOPS / 4.1 MiB/s | Mayastor |
| Mixed 70/30 write side | 5.7k IOPS / 22.1 MiB/s | 9.4k IOPS / 36.6 MiB/s | 0.8k IOPS / 3.2 MiB/s | Mayastor |
| Sync 4 KiB write | 777 IOPS / 3.0 MiB/s | 1009 IOPS / 3.9 MiB/s | 279 IOPS / 1.1 MiB/s | Mayastor |

The write-sensitive conclusion is driven less by sequential write and more by the smaller write profiles. Mayastor's random write and mixed-write numbers were materially stronger than Piraeus, and its write p99 latency stayed far lower. Piraeus random-write p99 averaged **58.41 ms**, and mixed-write p99 averaged **65.12 ms**. Those are the wrong trade-offs for a first app-state default when many stateful services care about tail latency.

Piraeus's read strength is established by the strict RWO read-after-write benchmark. In run 003, with the writer on `fordyce`, readers on `dauwalter` and `selassie`, and all LINSTOR resources `UpToDate` with no `SkipDisk`, Piraeus was the strongest read backend on both reader nodes.

Strict RWO read highlights:

| Backend/reader | Sequential read | Random read | Read p99 notes |
| --- | ---: | ---: | --- |
| Piraeus on `dauwalter` | 2185 MiB/s | 333.64 MiB/s / 85k IOPS | 25.81 ms seq-read p99, 0.31 ms rand-read p99 |
| Piraeus on `selassie` | 1746 MiB/s | 385.73 MiB/s / 99k IOPS | 18.52 ms seq-read p99, 0.39 ms rand-read p99 |
| Mayastor readers | about 168 MiB/s seq | 123-134 MiB/s rand | 128-138 ms seq-read p99 |
| Longhorn NVMe readers | 108-161 MiB/s seq | 67-75 MiB/s rand | 370-496 ms seq-read p99 |

That makes Piraeus interesting for read-heavy future exploration, but it does not overturn the Mayastor recommendation for a first write-sensitive app-state trial.

The local-path baseline shows why the comparison must separate performance from replication. `local-path` reached **860 MiB/s sequential write**, **96k random-write IOPS**, and **55k sync-write IOPS**, beating every replicated backend on writes. It is fast because it is local and non-replicated. It should be treated as the local ceiling, not as a replacement for replicated storage.

## Final RWX/shared-storage results and interpretation

The controlled RWX benchmark is more nuanced than the RWO benchmark because every backend's RWX path has a serving component. The controlled run fixed serving locality on `fordyce` and kept fio clients remote on `dauwalter` and `selassie`.

The headline findings from the aggregate concurrent table were:

| Concurrent RWX profile | Best backend | Winning throughput |
| --- | --- | ---: |
| Sequential read | Piraeus/LINSTOR RWX | 111.09 MiB/s aggregate read |
| Sequential write | Mayastor-backed RWX via NFS/NFS CSI | 109.08 MiB/s aggregate write |
| Random read | Longhorn RWX | 108.20 MiB/s aggregate read |
| Random write | Longhorn RWX | 17.38 MiB/s aggregate write |
| Sync write | Mayastor-backed RWX via NFS/NFS CSI | 13.37 MiB/s aggregate write |
| Mixed 70/30 write side | Mayastor-backed RWX via NFS/NFS CSI | 26.91 MiB/s aggregate write |

This does not produce a universal RWX winner. It does show that:

- Mayastor-backed NFS RWX was strongest for sequential write, sync write, and mixed write-side throughput.
- Longhorn RWX was strongest for random read and random write in the aggregate concurrent view.
- Piraeus/LINSTOR RWX was strongest for sequential read, but its random and mixed writes were weak.
- These are controlled-locality results, not cache-cold results. No approved cache-flush runbook artifact accompanies the run.

For shared storage, the recommendation should therefore be workload-specific. If the RWX use case is write-heavy and NFS semantics are acceptable, Mayastor-backed NFS deserves more exploration. If the use case is mostly random-read or simple shared files, Longhorn RWX remains competitive. If the use case is read-heavy sequential access, Piraeus has a strong signal but still carries the operational caveats seen elsewhere.

## Backend-by-backend assessment

### Mayastor

Mayastor is the recommended next app-state trial because it provided the strongest replicated write profile. It led random write, mixed-write, and sync-write workloads among replicated app-state backends, and its sequential write was close enough to Piraeus that the smaller write profiles are the deciding factor.

It also performed well in the controlled RWX run when used as a replicated backend behind NFS/NFS CSI, especially for sequential write, mixed write, and sync write. That makes it the most promising backend for the first non-critical trial, provided the trial is framed as a validation step rather than an immediate production migration.

The caution is operational. The campaign noted Mayastor cleanup and reused-pool metadata wrinkles. Those do not erase the performance result, but they do mean Mayastor still needs monitoring, cleanup rehearsal, restore testing, and rollback instructions before critical app state moves onto it.

### Longhorn NVMe

Longhorn should be kept as the fallback, but the correct comparison is the retained **Longhorn NVMe** run. The first default Longhorn run was discarded because Longhorn placed two of three replicas on `sata`-tagged `/srv/data` disks. The retained run used a storage class with `diskSelector: nvme`, and the health artifact confirms all three replicas used `/var/lib/longhorn/` disks tagged `nvme`.

With that fix, Longhorn NVMe still did not beat Mayastor on write throughput. In the strict RWO read comparison it also trailed Piraeus, so it remains a fallback rather than the performance leader for either app-state write throughput or read-specialist use.

Longhorn RWX was more competitive in the controlled shared-storage benchmark, especially for random read and random write. The controlled run also showed that Longhorn RWX placement requires explicit `shareManagerNodeSelector` and `shareManagerTolerations`; a serving-anchor client pod alone was not enough to guarantee share-manager placement.

### Piraeus/LINSTOR

Piraeus is the read-performance standout in the strict RWO benchmark. Run 003 confirmed excellent read behavior with all resources `UpToDate` and no `SkipDisk` caveat.

The reason it is not the first app-state default is write behavior and operational risk. In v2, Piraeus random write, mixed write, and sync write lagged Mayastor and Longhorn NVMe. Its random-write and mixed-write p99 latencies were high enough to be a practical concern for databases and other write-sensitive services.

The campaign also exposed lifecycle challenges: one strict RWO run completed but was invalidated by LINSTOR `Diskless, SkipDisk (R)` on `dauwalter`; a later rerun was blocked until stale/orphaned LINSTOR/LVM thin-volume state was cleaned up; Piraeus cleanup and ArgoCD finalizer behavior needed careful ordering. Those are solvable operational issues, but they make Piraeus a poor first default for write-sensitive app state in this cluster.

### local-path

`local-path` remains valuable as a baseline and for intentionally local storage. It produced the strongest write numbers because it avoids replication. That makes it useful for disposable workloads, workloads with their own replication, and benchmarks that need a local performance ceiling.

It should not be confused with a resilient storage backend. It does not provide replicated app-state safety and it does not provide RWX shared storage.

## Challenges, invalidated results, and reruns

The final recommendations are credible because several early results were rejected or rerun instead of being averaged into the conclusion.

### Longhorn default run used the wrong disks

The first default Longhorn run placed two of three replicas on SATA-tagged `/srv/data` disks. That made it unsuitable for comparing against NVMe-backed Mayastor and Piraeus runs. The retained Longhorn result is the NVMe rerun using `diskSelector: nvme`.

### The original RWX run had locality contamination

The original RWX benchmark produced useful diagnostics but was not a fair backend ranking. Active serving components could land on different nodes than intended, and client locality was not controlled tightly enough. The controlled rerun fixed this by pinning serving locality to `fordyce`, pinning fio clients to `dauwalter` and `selassie`, and recording explicit placement evidence.

### Piraeus strict RWO run 001 was superseded

Piraeus strict RWO run 001 completed and produced result rows, but LINSTOR reported the `dauwalter` resource as `Diskless, SkipDisk (R)`. LINSTOR describes `SkipDisk` as indicating an IO error on the affected resource, so run 001 cannot be used as the normal healthy-resource result.

Piraeus run 003 supersedes it. Run 003 shows writer on `fordyce`, readers on `dauwalter` and `selassie`, all three resources `UpToDate`, and no `SkipDisk` entries.

### Cleanup and finalizers mattered

The Piraeus rerun was initially blocked by stale/orphaned LINSTOR/LVM thin-volume state from prior benchmarks filling `linstor-bench` capacity. Cleanup was handled through GitOps, after which run 003 completed cleanly.

Cleanup also exposed finalizer behavior. Piraeus operator cleanup required deleting the benchmark `LinstorCluster` before removing the operator app so ArgoCD could prune resources cleanly. OpenEBS Mayastor cleanup required the ArgoCD resources finalizer and etcd PVC retention policy before pruning the temporary operator app; otherwise generated resources and etcd PVCs could be orphaned.

Those details belong in the recommendation because operational safety is part of the storage decision. A backend that benchmarks well but is hard to cleanly deactivate is not ready for critical app state without runbooks and rehearsals.

## Operational readiness gaps before production migration

Before moving critical state, complete the remaining gates from the final comparison and make them concrete:

1. **Monitoring and alerting**: backend health, replica state, pool usage, rebuilds, degraded volumes, and latency symptoms should be visible before migration.
2. **Documented restore path**: prove that an app can be restored from backup onto the chosen backend, not just that the PVC survives ordinary pod movement.
3. **Non-critical app trial**: choose a recoverable, non-critical app with real writes and run it on Mayastor first.
4. **Rollback instructions**: define how to move the app back to local-path or Longhorn if Mayastor shows unacceptable behavior.
5. **Cleanup rehearsal**: rehearse deactivation and resource cleanup, including finalizers, retained PVCs, pool metadata, and stale backend state.
6. **Failure drills**: test node loss, replica rebuild behavior, and degraded-volume recovery before trusting the backend with important state.
7. **Workload fit checks**: do not generalize the Mayastor app-state recommendation to every RWX workload; use the controlled RWX data to select shared-storage backends per workload.

A reasonable next milestone is therefore: migrate one non-critical, write-representative app to Mayastor; monitor it; prove restore and rollback; then decide whether to expand Mayastor usage or fall back to Longhorn NVMe.

## Appendix: artifact map

### Canonical app-state/RWO artifacts

- [`docs/storage-benchmark-v2/final-comparison.md`](storage-benchmark-v2/final-comparison.md): main replicated app-state recommendation.
- [`docs/storage-benchmark-v2/combined-summary.md`](storage-benchmark-v2/combined-summary.md): source table for v2 performance rows.
- [`docs/storage-benchmark-v2/local-path-run-001-health.md`](storage-benchmark-v2/local-path-run-001-health.md): local-path baseline health evidence.
- [`docs/storage-benchmark-v2/mayastor-v2-run-001-health.md`](storage-benchmark-v2/mayastor-v2-run-001-health.md): Mayastor v2 health evidence.
- [`docs/storage-benchmark-v2/piraeus-v2-run-001-health.md`](storage-benchmark-v2/piraeus-v2-run-001-health.md): Piraeus v2 health evidence.
- [`docs/storage-benchmark-v2/longhorn-nvme-v2-run-001-health.md`](storage-benchmark-v2/longhorn-nvme-v2-run-001-health.md): retained Longhorn NVMe health evidence.

### Canonical strict RWO read artifacts

- [`docs/storage-benchmark-rwo-strict/final-comparison.md`](storage-benchmark-rwo-strict/final-comparison.md): strict read-after-write final comparison.
- [`docs/storage-benchmark-rwo-strict/placement-audit.md`](storage-benchmark-rwo-strict/placement-audit.md): placement contract and evidence map.
- [`docs/storage-benchmark-rwo-strict/piraeus-run-003-summary.md`](storage-benchmark-rwo-strict/piraeus-run-003-summary.md): canonical Piraeus strict RWO summary.
- [`docs/storage-benchmark-rwo-strict/piraeus-run-003-health.md`](storage-benchmark-rwo-strict/piraeus-run-003-health.md): canonical Piraeus run 003 health evidence.

### Canonical RWX artifacts

- [`docs/storage-benchmark-rwx-controlled/final-comparison.md`](storage-benchmark-rwx-controlled/final-comparison.md): controlled RWX comparison and recommendation context.
- [`docs/storage-benchmark-rwx-controlled/combined-summary.md`](storage-benchmark-rwx-controlled/combined-summary.md): source table for controlled RWX results.
- [`docs/storage-benchmark-rwx-controlled/placement-audit.md`](storage-benchmark-rwx-controlled/placement-audit.md): controlled RWX placement evidence.
- [`docs/storage-benchmark-rwx-controlled/longhorn-rwx-controlled-run-001-health.md`](storage-benchmark-rwx-controlled/longhorn-rwx-controlled-run-001-health.md): Longhorn RWX health evidence.
- [`docs/storage-benchmark-rwx-controlled/piraeus-rwx-controlled-run-001-health.md`](storage-benchmark-rwx-controlled/piraeus-rwx-controlled-run-001-health.md): Piraeus RWX health evidence.
- [`docs/storage-benchmark-rwx-controlled/mayastor-rwx-controlled-run-001-health.md`](storage-benchmark-rwx-controlled/mayastor-rwx-controlled-run-001-health.md): Mayastor-backed NFS RWX health evidence.

### Historical and diagnostic artifacts

- [`docs/storage-benchmark/`](storage-benchmark/): v1 and historical validation context.
- [`docs/storage-benchmark-rwx/`](storage-benchmark-rwx/): original uncontrolled RWX run. Treat it as diagnostic and operationally useful, not as the definitive RWX backend ranking.
- [`docs/storage-benchmark-rwo-strict/piraeus-run-001-summary.md`](storage-benchmark-rwo-strict/piraeus-run-001-summary.md): historical/superseded Piraeus run 001 summary.
- [`docs/storage-benchmark-rwo-strict/piraeus-run-001-health.md`](storage-benchmark-rwo-strict/piraeus-run-001-health.md): evidence for the `Diskless, SkipDisk (R)` caveat that made run 001 non-canonical.

