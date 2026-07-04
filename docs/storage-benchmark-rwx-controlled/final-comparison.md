# Controlled RWX Storage Benchmark Final Comparison

## Goal and placement contract

This controlled rerun compares RWX storage backends with serving locality fixed to `fordyce` and fio clients fixed to `dauwalter` and `selassie`. `walmsley` and `kipsang` are excluded from benchmark serving/client roles, and no fio client ran on `fordyce`.

The Mayastor entry is **Mayastor-backed RWX via NFS/NFS CSI**: Mayastor provides a replicated RWO backend PVC, exported by a benchmark NFS server on `fordyce`, and consumed via the NFS CSI driver.

## Row counts

| Backend | RESULT rows |
| --- | --- |
| Longhorn RWX | 72 |
| Piraeus/LINSTOR RWX | 72 |
| Mayastor-backed RWX via NFS/NFS CSI | 72 |

Total `RESULT,` rows: **216**.

## Placement audit summary

Full evidence: [`placement-audit.md`](placement-audit.md).

| Backend | Serving/active evidence | fio client evidence | Validity |
| --- | --- | --- | --- |
| Longhorn RWX | PV `pvc-28d642c9-5b7e-4d22-934f-4f549ab98c34` share-manager pod on `fordyce`; Volume YAML contains `currentNodeID: fordyce`. | 4 fio pods on `dauwalter`, `selassie`. | Valid |
| Piraeus/LINSTOR RWX | Serving anchor pod on `fordyce`; LINSTOR resource `pvc-494b412e-d23f-44c5-8996-caff4a09ec4c` is `InUse` on `fordyce`. | 4 fio pods on `dauwalter`, `selassie`. | Valid |
| Mayastor-backed RWX via NFS/NFS CSI | NFS server pod on `fordyce`. | 4 fio pods on `dauwalter`, `selassie`. | Valid |

## Single-client results: dauwalter

| Backend | Profile | Passes | Read MiB/s | Write MiB/s | Read IOPS | Write IOPS | Read p99 ms | Write p99 ms | Errors |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Longhorn RWX | seq-write-1m | 5 | 0.00 | 34.70 | 0.00 | 34.45 | 0.00 | 710.52 | 0 |
| Longhorn RWX | seq-read-1m | 5 | 107.06 | 0.00 | 106.81 | 0.00 | 165.47 | 0.00 | 0 |
| Longhorn RWX | rand-write-4k | 5 | 0.00 | 10.06 | 0.00 | 2576.18 | 0.00 | 11.84 | 0 |
| Longhorn RWX | rand-read-4k | 5 | 98.34 | 0.00 | 25175.76 | 0.00 | 0.89 | 0.00 | 0 |
| Longhorn RWX | randrw-4k-70r30w | 5 | 26.83 | 11.52 | 6868.17 | 2949.68 | 1.55 | 6.42 | 0 |
| Longhorn RWX | sync-write-4k | 5 | 0.00 | 0.49 | 0.00 | 126.17 | 0.00 | 10.11 | 0 |
| Piraeus/LINSTOR RWX | seq-write-1m | 5 | 0.00 | 50.62 | 0.00 | 50.37 | 0.00 | 445.02 | 0 |
| Piraeus/LINSTOR RWX | seq-read-1m | 5 | 107.04 | 0.00 | 106.79 | 0.00 | 166.30 | 0.00 | 0 |
| Piraeus/LINSTOR RWX | rand-write-4k | 5 | 0.00 | 1.93 | 0.00 | 493.74 | 0.00 | 82.16 | 0 |
| Piraeus/LINSTOR RWX | rand-read-4k | 5 | 97.46 | 0.00 | 24948.80 | 0.00 | 0.89 | 0.00 | 0 |
| Piraeus/LINSTOR RWX | randrw-4k-70r30w | 5 | 3.09 | 1.32 | 792.14 | 338.13 | 13.21 | 108.16 | 0 |
| Piraeus/LINSTOR RWX | sync-write-4k | 5 | 0.00 | 0.24 | 0.00 | 61.82 | 0.00 | 26.35 | 0 |
| Mayastor-backed RWX via NFS/NFS CSI | seq-write-1m | 5 | 0.00 | 107.34 | 0.00 | 107.09 | 0.00 | 156.66 | 0 |
| Mayastor-backed RWX via NFS/NFS CSI | seq-read-1m | 5 | 45.98 | 0.00 | 45.73 | 0.00 | 458.44 | 0.00 | 0 |
| Mayastor-backed RWX via NFS/NFS CSI | rand-write-4k | 5 | 0.00 | 8.01 | 0.00 | 2051.16 | 0.00 | 227.75 | 0 |
| Mayastor-backed RWX via NFS/NFS CSI | rand-read-4k | 5 | 96.38 | 0.00 | 24673.70 | 0.00 | 1.00 | 0.00 | 0 |
| Mayastor-backed RWX via NFS/NFS CSI | randrw-4k-70r30w | 5 | 45.66 | 19.58 | 11687.87 | 5013.59 | 1.74 | 1.79 | 0 |
| Mayastor-backed RWX via NFS/NFS CSI | sync-write-4k | 5 | 0.00 | 3.96 | 0.00 | 1014.06 | 0.00 | 2.19 | 0 |

## Single-client results: selassie

| Backend | Profile | Passes | Read MiB/s | Write MiB/s | Read IOPS | Write IOPS | Read p99 ms | Write p99 ms | Errors |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Longhorn RWX | seq-write-1m | 5 | 0.00 | 35.04 | 0.00 | 34.79 | 0.00 | 702.13 | 0 |
| Longhorn RWX | seq-read-1m | 5 | 107.29 | 0.00 | 107.04 | 0.00 | 155.40 | 0.00 | 0 |
| Longhorn RWX | rand-write-4k | 5 | 0.00 | 10.33 | 0.00 | 2644.63 | 0.00 | 11.18 | 0 |
| Longhorn RWX | rand-read-4k | 5 | 100.26 | 0.00 | 25665.78 | 0.00 | 0.76 | 0.00 | 0 |
| Longhorn RWX | randrw-4k-70r30w | 5 | 26.65 | 11.45 | 6821.61 | 2930.78 | 1.61 | 6.84 | 0 |
| Longhorn RWX | sync-write-4k | 5 | 0.00 | 0.53 | 0.00 | 136.74 | 0.00 | 9.61 | 0 |
| Piraeus/LINSTOR RWX | seq-write-1m | 5 | 0.00 | 51.10 | 0.00 | 50.85 | 0.00 | 437.47 | 0 |
| Piraeus/LINSTOR RWX | seq-read-1m | 5 | 107.39 | 0.00 | 107.14 | 0.00 | 152.04 | 0.00 | 0 |
| Piraeus/LINSTOR RWX | rand-write-4k | 5 | 0.00 | 1.97 | 0.00 | 504.28 | 0.00 | 65.17 | 0 |
| Piraeus/LINSTOR RWX | rand-read-4k | 5 | 100.33 | 0.00 | 25684.03 | 0.00 | 0.74 | 0.00 | 0 |
| Piraeus/LINSTOR RWX | randrw-4k-70r30w | 5 | 3.51 | 1.50 | 898.80 | 383.74 | 10.00 | 84.72 | 0 |
| Piraeus/LINSTOR RWX | sync-write-4k | 5 | 0.00 | 0.25 | 0.00 | 63.03 | 0.00 | 25.19 | 0 |
| Mayastor-backed RWX via NFS/NFS CSI | seq-write-1m | 5 | 0.00 | 107.14 | 0.00 | 106.89 | 0.00 | 152.46 | 0 |
| Mayastor-backed RWX via NFS/NFS CSI | seq-read-1m | 5 | 45.94 | 0.00 | 45.69 | 0.00 | 450.05 | 0.00 | 0 |
| Mayastor-backed RWX via NFS/NFS CSI | rand-write-4k | 5 | 0.00 | 12.18 | 0.00 | 3116.64 | 0.00 | 117.86 | 0 |
| Mayastor-backed RWX via NFS/NFS CSI | rand-read-4k | 5 | 99.89 | 0.00 | 25571.58 | 0.00 | 0.79 | 0.00 | 0 |
| Mayastor-backed RWX via NFS/NFS CSI | randrw-4k-70r30w | 5 | 52.15 | 22.38 | 13351.20 | 5728.40 | 1.55 | 1.58 | 0 |
| Mayastor-backed RWX via NFS/NFS CSI | sync-write-4k | 5 | 0.00 | 9.80 | 0.00 | 2509.17 | 0.00 | 1.72 | 0 |

## Two-client concurrent results: dauwalter

| Backend | Profile | Passes | Read MiB/s | Write MiB/s | Read IOPS | Write IOPS | Read p99 ms | Write p99 ms | Errors |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Longhorn RWX | seq-write-1m | 1 | 0.00 | 15.72 | 0.00 | 15.50 | 0.00 | 7952.40 | 0 |
| Longhorn RWX | seq-read-1m | 1 | 74.04 | 0.00 | 73.79 | 0.00 | 299.89 | 0.00 | 0 |
| Longhorn RWX | rand-write-4k | 1 | 0.00 | 9.16 | 0.00 | 2343.55 | 0.00 | 9.63 | 0 |
| Longhorn RWX | rand-read-4k | 1 | 47.06 | 0.00 | 12048.35 | 0.00 | 2.41 | 0.00 | 0 |
| Longhorn RWX | randrw-4k-70r30w | 1 | 23.36 | 10.04 | 5979.44 | 2570.20 | 2.09 | 7.70 | 0 |
| Longhorn RWX | sync-write-4k | 1 | 0.00 | 0.50 | 0.00 | 127.55 | 0.00 | 10.03 | 0 |
| Piraeus/LINSTOR RWX | seq-write-1m | 1 | 0.00 | 26.39 | 0.00 | 26.14 | 0.00 | 809.50 | 0 |
| Piraeus/LINSTOR RWX | seq-read-1m | 1 | 57.40 | 0.00 | 57.15 | 0.00 | 299.89 | 0.00 | 0 |
| Piraeus/LINSTOR RWX | rand-write-4k | 1 | 0.00 | 1.03 | 0.00 | 264.48 | 0.00 | 119.01 | 0 |
| Piraeus/LINSTOR RWX | rand-read-4k | 1 | 52.83 | 0.00 | 13524.66 | 0.00 | 1.52 | 0.00 | 0 |
| Piraeus/LINSTOR RWX | randrw-4k-70r30w | 1 | 2.39 | 1.02 | 611.41 | 261.34 | 14.35 | 112.72 | 0 |
| Piraeus/LINSTOR RWX | sync-write-4k | 1 | 0.00 | 0.15 | 0.00 | 39.14 | 0.00 | 36.96 | 0 |
| Mayastor-backed RWX via NFS/NFS CSI | seq-write-1m | 1 | 0.00 | 58.22 | 0.00 | 57.97 | 0.00 | 287.31 | 0 |
| Mayastor-backed RWX via NFS/NFS CSI | seq-read-1m | 1 | 30.83 | 0.00 | 30.58 | 0.00 | 666.89 | 0.00 | 0 |
| Mayastor-backed RWX via NFS/NFS CSI | rand-write-4k | 1 | 0.00 | 0.20 | 0.00 | 51.96 | 0.00 | 792.72 | 0 |
| Mayastor-backed RWX via NFS/NFS CSI | rand-read-4k | 1 | 40.34 | 0.00 | 10326.31 | 0.00 | 2.18 | 0.00 | 0 |
| Mayastor-backed RWX via NFS/NFS CSI | randrw-4k-70r30w | 1 | 24.61 | 10.57 | 6299.41 | 2706.39 | 2.38 | 2.54 | 0 |
| Mayastor-backed RWX via NFS/NFS CSI | sync-write-4k | 1 | 0.00 | 3.53 | 0.00 | 904.34 | 0.00 | 2.47 | 0 |

## Two-client concurrent results: selassie

| Backend | Profile | Passes | Read MiB/s | Write MiB/s | Read IOPS | Write IOPS | Read p99 ms | Write p99 ms | Errors |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Longhorn RWX | seq-write-1m | 1 | 0.00 | 17.58 | 0.00 | 17.33 | 0.00 | 1333.79 | 0 |
| Longhorn RWX | seq-read-1m | 1 | 31.09 | 0.00 | 30.84 | 0.00 | 1069.55 | 0.00 | 0 |
| Longhorn RWX | rand-write-4k | 1 | 0.00 | 8.23 | 0.00 | 2106.07 | 0.00 | 12.12 | 0 |
| Longhorn RWX | rand-read-4k | 1 | 61.13 | 0.00 | 15649.60 | 0.00 | 2.64 | 0.00 | 0 |
| Longhorn RWX | randrw-4k-70r30w | 1 | 19.08 | 8.21 | 4885.54 | 2101.49 | 2.28 | 7.90 | 0 |
| Longhorn RWX | sync-write-4k | 1 | 0.00 | 0.77 | 0.00 | 197.50 | 0.00 | 8.59 | 0 |
| Piraeus/LINSTOR RWX | seq-write-1m | 1 | 0.00 | 25.18 | 0.00 | 24.94 | 0.00 | 901.78 | 0 |
| Piraeus/LINSTOR RWX | seq-read-1m | 1 | 53.69 | 0.00 | 53.44 | 0.00 | 304.09 | 0.00 | 0 |
| Piraeus/LINSTOR RWX | rand-write-4k | 1 | 0.00 | 1.08 | 0.00 | 275.56 | 0.00 | 117.96 | 0 |
| Piraeus/LINSTOR RWX | rand-read-4k | 1 | 51.23 | 0.00 | 13115.43 | 0.00 | 1.35 | 0.00 | 0 |
| Piraeus/LINSTOR RWX | randrw-4k-70r30w | 1 | 2.54 | 1.09 | 650.74 | 279.86 | 13.70 | 107.48 | 0 |
| Piraeus/LINSTOR RWX | sync-write-4k | 1 | 0.00 | 0.15 | 0.00 | 37.35 | 0.00 | 38.54 | 0 |
| Mayastor-backed RWX via NFS/NFS CSI | seq-write-1m | 1 | 0.00 | 50.86 | 0.00 | 50.62 | 0.00 | 329.25 | 0 |
| Mayastor-backed RWX via NFS/NFS CSI | seq-read-1m | 1 | 31.10 | 0.00 | 30.86 | 0.00 | 683.67 | 0.00 | 0 |
| Mayastor-backed RWX via NFS/NFS CSI | rand-write-4k | 1 | 0.00 | 4.08 | 0.00 | 1043.47 | 0.00 | 417.33 | 0 |
| Mayastor-backed RWX via NFS/NFS CSI | rand-read-4k | 1 | 51.74 | 0.00 | 13244.06 | 0.00 | 2.01 | 0.00 | 0 |
| Mayastor-backed RWX via NFS/NFS CSI | randrw-4k-70r30w | 1 | 38.05 | 16.34 | 9741.25 | 4182.13 | 2.24 | 2.57 | 0 |
| Mayastor-backed RWX via NFS/NFS CSI | sync-write-4k | 1 | 0.00 | 9.84 | 0.00 | 2518.27 | 0.00 | 1.73 | 0 |

## Aggregate concurrent throughput (secondary context)

The table below sums the two concurrent client rows per backend/profile. Per-client tables above remain the primary comparison because client locality is controlled independently.

| Backend | Profile | Read MiB/s total | Write MiB/s total | Read IOPS total | Write IOPS total | Errors |
| --- | --- | --- | --- | --- | --- | --- |
| Longhorn RWX | seq-write-1m | 0.00 | 33.30 | 0.00 | 32.83 | 0 |
| Longhorn RWX | seq-read-1m | 105.13 | 0.00 | 104.63 | 0.00 | 0 |
| Longhorn RWX | rand-write-4k | 0.00 | 17.38 | 0.00 | 4449.63 | 0 |
| Longhorn RWX | rand-read-4k | 108.20 | 0.00 | 27697.94 | 0.00 | 0 |
| Longhorn RWX | randrw-4k-70r30w | 42.44 | 18.25 | 10864.98 | 4671.69 | 0 |
| Longhorn RWX | sync-write-4k | 0.00 | 1.27 | 0.00 | 325.05 | 0 |
| Piraeus/LINSTOR RWX | seq-write-1m | 0.00 | 51.57 | 0.00 | 51.07 | 0 |
| Piraeus/LINSTOR RWX | seq-read-1m | 111.09 | 0.00 | 110.59 | 0.00 | 0 |
| Piraeus/LINSTOR RWX | rand-write-4k | 0.00 | 2.11 | 0.00 | 540.03 | 0 |
| Piraeus/LINSTOR RWX | rand-read-4k | 104.06 | 0.00 | 26640.09 | 0.00 | 0 |
| Piraeus/LINSTOR RWX | randrw-4k-70r30w | 4.93 | 2.12 | 1262.15 | 541.20 | 0 |
| Piraeus/LINSTOR RWX | sync-write-4k | 0.00 | 0.30 | 0.00 | 76.50 | 0 |
| Mayastor-backed RWX via NFS/NFS CSI | seq-write-1m | 0.00 | 109.08 | 0.00 | 108.58 | 0 |
| Mayastor-backed RWX via NFS/NFS CSI | seq-read-1m | 61.93 | 0.00 | 61.44 | 0.00 | 0 |
| Mayastor-backed RWX via NFS/NFS CSI | rand-write-4k | 0.00 | 4.28 | 0.00 | 1095.42 | 0 |
| Mayastor-backed RWX via NFS/NFS CSI | rand-read-4k | 92.07 | 0.00 | 23570.37 | 0.00 | 0 |
| Mayastor-backed RWX via NFS/NFS CSI | randrw-4k-70r30w | 62.66 | 26.91 | 16040.66 | 6888.52 | 0 |
| Mayastor-backed RWX via NFS/NFS CSI | sync-write-4k | 0.00 | 13.37 | 0.00 | 3422.61 | 0 |

## Findings

- Concurrent `seq-read-1m` highest aggregate read mib s was **Piraeus/LINSTOR RWX** at **111.09 MiB/s**.
- Concurrent `seq-write-1m` highest aggregate write mib s was **Mayastor-backed RWX via NFS/NFS CSI** at **109.08 MiB/s**.
- Concurrent `rand-read-4k` highest aggregate read mib s was **Longhorn RWX** at **108.20 MiB/s**.
- Concurrent `rand-write-4k` highest aggregate write mib s was **Longhorn RWX** at **17.38 MiB/s**.
- Concurrent `sync-write-4k` highest aggregate write mib s was **Mayastor-backed RWX via NFS/NFS CSI** at **13.37 MiB/s**.

- Longhorn RWX is now valid for the controlled contract because `shareManagerNodeSelector` pinned the RWX share-manager to `fordyce`; the earlier anchor-only attempt was not sufficient.
- Piraeus/LINSTOR RWX is valid for the controlled contract because LINSTOR reported the benchmark resource `InUse` on `fordyce` while fio clients ran only on `dauwalter` and `selassie`.
- Mayastor-backed RWX via NFS/NFS CSI is valid for the controlled contract because the benchmark NFS server ran on `fordyce` while fio clients ran only on `dauwalter` and `selassie`.

## Comparison against the uncontrolled RWX run

The previous uncontrolled RWX comparison remains useful as an operational smoke test, but it should not be used for backend ranking because serving locality was contaminated: active RWX serving components could land on different nodes than the intended serving node, including nodes excluded from this controlled benchmark. This controlled run fixes that by recording explicit serving/active evidence for each backend and by pinning fio clients to remote nodes only.

## Operational notes

- Several benchmark nodes carried stale `drbd.linbit.com/lost-quorum=:NoSchedule` taints during this work. Controlled benchmark pods and storage data-plane components needed explicit tolerations where they were expected to run on those nodes.
- Longhorn RWX required `shareManagerNodeSelector` plus `shareManagerTolerations`; a serving-anchor client pod alone did not guarantee share-manager placement.
- Piraeus operator cleanup required deleting the benchmark `LinstorCluster` before removing the operator app so ArgoCD could prune resources cleanly.
- OpenEBS Mayastor cleanup required the ArgoCD resources finalizer and etcd PVC retention policy before pruning the temporary operator app; otherwise generated resources and etcd PVCs were orphaned.
- These are not cache-cold measurements; no approved cache-flush runbook artifact accompanies this run.

## Source artifacts

- [`combined-summary.md`](combined-summary.md)
- [`longhorn-rwx-controlled-run-001.log`](longhorn-rwx-controlled-run-001.log) and [`longhorn-rwx-controlled-run-001-health.md`](longhorn-rwx-controlled-run-001-health.md)
- [`piraeus-rwx-controlled-run-001.log`](piraeus-rwx-controlled-run-001.log) and [`piraeus-rwx-controlled-run-001-health.md`](piraeus-rwx-controlled-run-001-health.md)
- [`mayastor-rwx-controlled-run-001.log`](mayastor-rwx-controlled-run-001.log) and [`mayastor-rwx-controlled-run-001-health.md`](mayastor-rwx-controlled-run-001-health.md)
