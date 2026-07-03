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

Longhorn RWX was the strongest all-around choice for latency-sensitive random writes:

- Best single-client sequential read: 1829.72 MiB/s with 40.97 ms read p99.
- Best single-client random-write throughput and p99: 3223.53 write IOPS with 7.35 ms write p99.
- Best concurrent random-write throughput and p99: 2017.88 write IOPS with 15.83 ms write p99.

Its weak spot was concurrent sequential IO through the RWX/NFS path:

- Concurrent sequential read fell to 59.89 MiB/s with 573.57 ms read p99.
- Concurrent sequential write was 24.07 MiB/s with 2061.50 ms write p99.

Longhorn is the safer RWX option when predictable random-write tail latency matters more than concurrent sequential throughput.

### Piraeus/LINSTOR RWX

Piraeus/LINSTOR was the strongest read-heavy concurrent option:

- Best single-client random-read throughput: 24869.92 read IOPS.
- Best concurrent sequential read: 731.95 MiB/s with 98.89 ms read p99.
- Best concurrent random-read throughput and p99: 20066.32 read IOPS with 2.18 ms read p99.

Its write behavior was weak in this run:

- Single-client random write was 563.90 write IOPS with 81.74 ms p99.
- Concurrent random write was 192.19 write IOPS with 173.02 ms p99.
- Concurrent sync write was 55.00 write IOPS with 28.84 ms p99.

The Piraeus benchmark also exposed operational rough edges in this cluster: the temporary `LinstorCluster` cleanup twice required manual intervention after foreground deletion became stuck, and stale Piraeus `drbd.linbit.com/lost-quorum` taints later affected Mayastor scheduling. Treat Piraeus RWX as read-attractive but operationally higher-risk here until that lifecycle issue is resolved.

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

For a write-sensitive RWX app-state trial, use **Mayastor-backed RWX via NFS/NFS CSI** first if the app can accept the explicit NFS-server architecture. It delivered the best sequential write, sync write, and mixed-write results in both single-client and concurrent passes.

Use **Longhorn RWX** when random-write p99 latency and operational simplicity are more important than peak write-heavy throughput. It was the best random-write latency path and avoided the Piraeus lifecycle problems.

Use **Piraeus/LINSTOR RWX** selectively for read-heavy RWX shares. It won concurrent read throughput/latency, but write performance and cleanup behavior make it a poor first choice for write-heavy app state in this cluster.

## Operational follow-ups

- Remove or prevent stale `drbd.linbit.com/lost-quorum` taints after temporary Piraeus runs; they affected later Mayastor scheduling.
- Investigate why temporary Piraeus `LinstorCluster` deletion repeatedly stuck with foreground deletion.
- If Mayastor-backed NFS is selected for a real app, replace the single benchmark NFS server with an explicitly supported, monitored deployment model and test failure/restart behavior before production use.
