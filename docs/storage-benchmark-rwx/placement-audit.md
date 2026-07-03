# RWX Storage Benchmark Placement Audit

## Summary

The RWX benchmark numbers in `combined-summary.md` are numerically correct, but the sequential-read results are **not placement-controlled**. Active RWX serving placement, client locality, and read-cache warmth materially affected the results.

The final comparison should therefore treat the current RWX read numbers as diagnostic, not as a definitive backend ranking, until the benchmark is rerun with explicit locality controls.

## RWX locality matrix

| Backend | Active/share/NFS placement | fio index 0 single node | fio index 1 concurrent node | fio index 2 concurrent node | seq-read single values (MiB/s) | seq-read concurrent values (MiB/s) | Locality concern |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Longhorn RWX | share/currentNodeID=`dauwalter` | `dauwalter` | `fordyce` | `selassie` | 1004, 2060, 2015, 2031, 2038 | client-1:31, client-2:89 | Single pass 1 was local to the share and later passes were much faster, likely cache-hot. Concurrent clients were remote to the share and differed by 2.9x. |
| Piraeus/LINSTOR RWX | LINSTOR `InUse` node=`selassie` | `fordyce` | `dauwalter` | `selassie` | 107, 107, 107, 107, 107 | client-1:107, client-2:1357 | The `selassie` concurrent client was on the `InUse` node and was 12.7x faster than the remote client. The concurrent average is misleading. |
| Mayastor-backed NFS | benchmark NFS server=`fordyce` | `dauwalter` | `selassie` | `fordyce` | 42, 47, 43, 41, 41 | client-1:42, client-2:135 | The `fordyce` concurrent client was local to the benchmark NFS server and was 3.2x faster than the remote client. |

## What this invalidates

The following current-table interpretations are unsafe:

- Treating Longhorn's 1829.72 MiB/s single-client sequential read as a clean backend capability. The raw passes were 1004, then ~2 GiB/s for later passes, which strongly suggests warm-cache effects.
- Treating Piraeus/LINSTOR's 731.95 MiB/s concurrent sequential read as representative. It is the average of one remote client at 107 MiB/s and one local/active-placement client at 1357 MiB/s.
- Treating Mayastor-backed NFS's 88.49 MiB/s concurrent sequential read as representative. It is the average of one remote client at 42 MiB/s and one NFS-local client at 135 MiB/s.

The write-heavy results are less obviously skewed by the audited placement data, but they should still be interpreted with the same caution until a controlled rerun confirms them.

## RWO benchmark placement notes

The earlier RWO benchmark runs are less affected by this specific multi-client averaging problem because they used one fio pod per run rather than multiple simultaneous clients:

| Benchmark | fio pod node | Placement caveat |
| --- | --- | --- |
| `storage-benchmark-v2/local-path-run-001` | `fordyce` | Local-path is node-local by design; result is a `fordyce` local-path result, not a cluster-wide average. |
| `storage-benchmark-v2/longhorn-nvme-v2-run-001` | `fordyce` | Longhorn replicas were on NVMe-tagged disks, but the volume was detached by capture time; locality during each pass is not fully reconstructable from the health artifact. |
| `storage-benchmark-v2/mayastor-v2-run-001` | `fordyce` | Single-client result only; target/locality during each pass is not fully reconstructable from the health artifact. |
| `storage-benchmark-v2/piraeus-v2-run-001` | `fordyce` | Single-client result only; LINSTOR resource placement was captured, but there is no concurrent-client locality averaging. |
| older `docs/storage-benchmark/*` runs | `dauwalter` or `fordyce` depending on backend | Older single-client runs are useful history but should not be mixed with the RWX locality-sensitive comparison. |

## Required rerun controls

A trustworthy RWX rerun should change the benchmark shape and reporting:

1. Capture active serving placement before and after every profile, not only once at run end:
   - Longhorn share-manager/current node.
   - LINSTOR `InUse` node and NFS server path.
   - Mayastor-backed NFS server node and Mayastor target/replica placement.
2. Run single-client reads from each benchmark node, or pin the serving endpoint and client placement intentionally:
   - local-to-serving-node client,
   - remote client A,
   - remote client B.
3. Report concurrent results per client as well as aggregate:
   - min,
   - max,
   - per-client values,
   - sum if measuring aggregate service throughput,
   - average only when per-client results are symmetric enough to justify it.
4. Split read tests into cold-read and warm-read phases. The current sequential-read profiles are cache-sensitive.
5. Avoid using a single averaged sequential-read number as a backend ranking unless locality and cache state are controlled.

## Current recommendation after audit

Use the existing RWX results as a successful functional benchmark and a write/read diagnostic, not as a definitive read-performance ranking.

Before selecting a backend based on sequential read or concurrent read performance, rerun with the controls above.
