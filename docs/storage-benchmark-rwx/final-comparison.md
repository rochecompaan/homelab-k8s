# RWX Storage Benchmark Final Comparison

## Scope

This benchmark compares `ReadWriteMany` behavior for three storage paths in the homelab cluster:

| backend | RWX implementation tested | Result artifacts |
| --- | --- | --- |
| Longhorn | Longhorn RWX volume through Longhorn share-manager/NFS, using the NVMe-constrained Longhorn benchmark StorageClass | `longhorn-rwx-run-001.log`, `longhorn-rwx-run-001-summary.md`, `longhorn-rwx-run-001-health.md` |
| Piraeus/LINSTOR | LINSTOR CSI RWX PVC managed by Piraeus; LINBIT's RWX path uses NFS/DRBD Reactor under the CSI integration | `piraeus-rwx-run-001.log`, `piraeus-rwx-run-001-summary.md`, `piraeus-rwx-run-001-health.md` |
| Mayastor-backed NFS | Mayastor RWO backend PVC exported by a benchmark NFS server and consumed through NFS CSI | `mayastor-rwx-run-001.log`, `mayastor-rwx-run-001-summary.md`, `mayastor-rwx-run-001-health.md` |

The Mayastor result is **Mayastor-backed RWX via NFS/NFS CSI**, not native Mayastor block RWX.

Each backend completed:

- 30 single-client fio `RESULT` rows: 5 passes for each of 6 profiles.
- 12 concurrent fio `RESULT` rows: 2 clients, 1 pass each for each of 6 profiles.
- Multi-attach proof with two pods on separate nodes seeing each other's writes.
- Health/placement captures for the backend and any NFS/share-manager path.

All 126 fio `RESULT` rows across the three backends reported `errors_total = 0` in the generated summaries.

Full generated table: [`combined-summary.md`](combined-summary.md).

## Placement audit caveat

A follow-up audit found that the sequential-read results are materially affected by RWX serving placement and cache warmth. See [`placement-audit.md`](placement-audit.md).

Key examples:

- Longhorn single-client sequential read was 1004 MiB/s on pass 1, then about 2 GiB/s on later passes, which suggests warm-cache effects.
- Piraeus/LINSTOR concurrent sequential read averaged 731.95 MiB/s, but that average came from one remote client at 107 MiB/s and one client on the LINSTOR `InUse` node at 1357 MiB/s.
- Mayastor-backed NFS concurrent sequential read averaged 88.49 MiB/s, but that average came from one remote client at 42 MiB/s and one client local to the benchmark NFS server at 135 MiB/s.

The current RWX results are valid as functional benchmark artifacts and useful diagnostics, but the read-performance rankings should be treated as **preliminary** until rerun with controlled serving-node placement and cold/warm read separation.

## Single-client results

| profile | Longhorn RWX throughput / p99 | Piraeus/LINSTOR RWX throughput / p99 | Mayastor-backed NFS throughput / p99 |
| --- | --- | --- | --- |
| seq-read-1m | 1829.72 MiB/s read / 40.97 ms | 107.17 MiB/s read / 156.66 ms | 42.77 MiB/s read / 473.54 ms |
| seq-write-1m | 48.39 MiB/s write / 535.19 ms | 51.38 MiB/s write / 473.54 ms | 107.05 MiB/s write / 171.34 ms |
| rand-read-4k | 24304.75 read IOPS / 0.89 ms | 24869.92 read IOPS / 1.14 ms | 24253.86 read IOPS / 1.06 ms |
| rand-write-4k | 3223.53 write IOPS / 7.35 ms | 563.90 write IOPS / 81.74 ms | 2714.32 write IOPS / 148.74 ms |
| randrw-4k-70r30w | 2408.12 write IOPS (70/30) / 8.76 ms | 303.21 write IOPS (70/30) / 113.35 ms | 5064.93 write IOPS (70/30) / 1.74 ms |
| sync-write-4k | 226.33 write IOPS / 6.06 ms | 93.10 write IOPS / 17.13 ms | 1028.00 write IOPS / 2.21 ms |

### Single-client winners

| profile | Throughput winner | Lowest p99 latency |
| --- | --- | --- |
| seq-read-1m | Longhorn RWX (1829.72 MiB/s read) | Longhorn RWX (40.97 ms) |
| seq-write-1m | Mayastor-backed NFS (107.05 MiB/s write) | Mayastor-backed NFS (171.34 ms) |
| rand-read-4k | Piraeus/LINSTOR RWX (24869.92 read IOPS) | Longhorn RWX (0.89 ms) |
| rand-write-4k | Longhorn RWX (3223.53 write IOPS) | Longhorn RWX (7.35 ms) |
| randrw-4k-70r30w | Mayastor-backed NFS (5064.93 write IOPS (70/30)) | Mayastor-backed NFS (1.74 ms) |
| sync-write-4k | Mayastor-backed NFS (1028.00 write IOPS) | Mayastor-backed NFS (2.21 ms) |

## Two-client concurrent results

| profile | Longhorn RWX throughput / p99 | Piraeus/LINSTOR RWX throughput / p99 | Mayastor-backed NFS throughput / p99 |
| --- | --- | --- | --- |
| seq-read-1m | 59.89 MiB/s read / 573.57 ms | 731.95 MiB/s read / 98.89 ms | 88.49 MiB/s read / 351.80 ms |
| seq-write-1m | 24.07 MiB/s write / 2061.50 ms | 26.68 MiB/s write / 868.22 ms | 64.11 MiB/s write / 699.92 ms |
| rand-read-4k | 11317.16 read IOPS / 2.38 ms | 20066.32 read IOPS / 2.18 ms | 13034.37 read IOPS / 7.68 ms |
| rand-write-4k | 2017.88 write IOPS / 15.83 ms | 192.19 write IOPS / 173.02 ms | 714.95 write IOPS / 170.66 ms |
| randrw-4k-70r30w | 1714.69 write IOPS (70/30) / 10.16 ms | 192.75 write IOPS (70/30) / 128.97 ms | 3568.17 write IOPS (70/30) / 8.72 ms |
| sync-write-4k | 183.56 write IOPS / 7.72 ms | 55.00 write IOPS / 28.84 ms | 1401.45 write IOPS / 6.66 ms |

### Concurrent winners

| profile | Throughput winner | Lowest p99 latency |
| --- | --- | --- |
| seq-read-1m | Piraeus/LINSTOR RWX (731.95 MiB/s read) | Piraeus/LINSTOR RWX (98.89 ms) |
| seq-write-1m | Mayastor-backed NFS (64.11 MiB/s write) | Mayastor-backed NFS (699.92 ms) |
| rand-read-4k | Piraeus/LINSTOR RWX (20066.32 read IOPS) | Piraeus/LINSTOR RWX (2.18 ms) |
| rand-write-4k | Longhorn RWX (2017.88 write IOPS) | Longhorn RWX (15.83 ms) |
| randrw-4k-70r30w | Mayastor-backed NFS (3568.17 write IOPS (70/30)) | Mayastor-backed NFS (8.72 ms) |
| sync-write-4k | Mayastor-backed NFS (1401.45 write IOPS) | Mayastor-backed NFS (6.66 ms) |

## Findings

### Longhorn RWX

Longhorn RWX was the strongest all-around choice for latency-sensitive random writes in this run:

- Best single-client random-write throughput and p99: 3223.53 write IOPS with 7.35 ms write p99.
- Best concurrent random-write throughput and p99: 2017.88 write IOPS with 15.83 ms write p99.

Its sequential-read result should not be treated as a clean backend ranking because the raw passes were 1004 MiB/s followed by about 2 GiB/s on later passes, indicating likely cache warmth. Its concurrent sequential IO was also remote to the share-manager node and much slower:

- Concurrent sequential read: 59.89 MiB/s with 573.57 ms read p99.
- Concurrent sequential write: 24.07 MiB/s with 2061.50 ms write p99.

Longhorn remains the safer RWX option when predictable random-write tail latency matters more than peak sequential-read numbers.

### Piraeus/LINSTOR RWX

Piraeus/LINSTOR had strong random-read numbers in the summary, but the sequential-read audit shows locality contamination:

- Single-client sequential read was consistently about 107 MiB/s.
- Concurrent sequential read averaged 731.95 MiB/s only because the client on the LINSTOR `InUse` node reached 1357 MiB/s while the remote client stayed at 107 MiB/s.
- Concurrent random-read throughput and p99 were strong at 20066.32 read IOPS with 2.18 ms read p99, but this should still be rerun with placement controls before using it as a backend ranking.

Its write behavior was weak in this run:

- Single-client random write was 563.90 write IOPS with 81.74 ms p99.
- Concurrent random write was 192.19 write IOPS with 173.02 ms p99.
- Concurrent sync write was 55.00 write IOPS with 28.84 ms p99.

The Piraeus benchmark also exposed operational rough edges in this cluster: the temporary `LinstorCluster` cleanup twice required manual intervention after foreground deletion became stuck, and stale Piraeus `drbd.linbit.com/lost-quorum` taints later affected Mayastor scheduling. Treat Piraeus RWX as operationally higher-risk here until that lifecycle issue is resolved.

### Mayastor-backed RWX via NFS/NFS CSI

The Mayastor-backed NFS path was the strongest write-heavy RWX result overall, especially for sync and mixed writes:

- Best single-client sequential write: 107.05 MiB/s with 171.34 ms write p99.
- Best single-client mixed 70/30 write side: 5064.93 write IOPS with 1.74 ms write p99.
- Best single-client sync write: 1028.00 write IOPS with 2.21 ms write p99.
- Best concurrent sequential write: 64.11 MiB/s with 699.92 ms write p99.
- Best concurrent mixed 70/30 write side: 3568.17 write IOPS with 8.72 ms write p99.
- Best concurrent sync write: 1401.45 write IOPS with 6.66 ms write p99.

Caveats:

- This is a benchmark-managed NFS server over a Mayastor RWO backend PVC. It is not native block-level RWX from Mayastor.
- Single-client random-write throughput was high at 2714.32 write IOPS, but p99 was 148.74 ms, much worse than Longhorn's 7.35 ms.
- OpenEBS etcd had one pending pod during the run because stale Piraeus taints prevented the local-path PV from scheduling on `dauwalter`; the benchmark still completed and health captures recorded the state.

## Recommendation

Do not select an RWX backend from the sequential-read or concurrent-read winners in this run. Those numbers are placement- and cache-sensitive, as documented in [`placement-audit.md`](placement-audit.md).

For a write-sensitive RWX app-state trial, **Mayastor-backed RWX via NFS/NFS CSI** remains the most interesting candidate if the app can accept the explicit NFS-server architecture. It delivered the best sequential write, sync write, and mixed-write results in both single-client and concurrent passes, and those write results did not show the same obvious per-client sequential-read outlier pattern.

Use **Longhorn RWX** when random-write p99 latency and operational simplicity are more important than peak write-heavy throughput. It was the best random-write latency path and avoided the Piraeus lifecycle problems.

Do not promote **Piraeus/LINSTOR RWX** as the read-heavy winner from this run alone. Its apparent concurrent sequential-read win is an average of one normal remote client and one much faster client on the LINSTOR `InUse` node. Rerun with controlled placement before making a read-heavy recommendation.

## Operational follow-ups

- Remove or prevent stale `drbd.linbit.com/lost-quorum` taints after temporary Piraeus runs; they affected later Mayastor scheduling.
- Investigate why temporary Piraeus `LinstorCluster` deletion repeatedly stuck with foreground deletion.
- If Mayastor-backed NFS is selected for a real app, replace the single benchmark NFS server with an explicitly supported, monitored deployment model and test failure/restart behavior before production use.
