# Strict-placement RWO Storage Benchmark Final Comparison

## Goal and placement contract

This benchmark measures replicated RWO read performance after a different consumer node wrote the fio test file. For each backend, a writer Job on `fordyce` fully wrote `/volume/fio-test-file`, exited, and separate reader Jobs on `dauwalter` and `selassie` ran read-only fio profiles.

Locality is allowed. These results do not claim cold remote/no-replica reads, and they are not presented as cache-cold remote reads.

## Included backends

- Piraeus/LINSTOR RWO
- Longhorn NVMe RWO
- Mayastor RWO

`local-path` was not rerun. The original v2 local-path result remains the local-node baseline/reference only; it is non-replicated and is not part of the strict replicated RWO read table below.

## Read-only results

| Backend | Profile | Passes | Read MiB/s | Read IOPS | Read p99 ms | Errors |
| --- | --- | --- | --- | --- | --- | --- |
| longhorn-nvme-rwo-strict-dauwalter | rand-read-4k | 5 | 67.47 | 17271.53 | 1.71 | 0 |
| longhorn-nvme-rwo-strict-dauwalter | seq-read-1m | 5 | 161.30 | 161.05 | 369.52 | 0 |
| longhorn-nvme-rwo-strict-selassie | rand-read-4k | 5 | 74.60 | 19098.30 | 1.71 | 0 |
| longhorn-nvme-rwo-strict-selassie | seq-read-1m | 5 | 108.33 | 108.08 | 496.19 | 0 |
| mayastor-rwo-strict-dauwalter | rand-read-4k | 5 | 133.76 | 34242.09 | 1.06 | 0 |
| mayastor-rwo-strict-dauwalter | seq-read-1m | 5 | 167.61 | 167.35 | 128.24 | 0 |
| mayastor-rwo-strict-selassie | rand-read-4k | 5 | 123.50 | 31615.39 | 1.28 | 0 |
| mayastor-rwo-strict-selassie | seq-read-1m | 5 | 168.27 | 168.01 | 137.78 | 0 |
| piraeus-rwo-strict-dauwalter | rand-read-4k | 5 | 88.23 | 22587.37 | 2.14 | 0 |
| piraeus-rwo-strict-dauwalter | seq-read-1m | 5 | 107.87 | 107.62 | 199.44 | 0 |
| piraeus-rwo-strict-selassie | rand-read-4k | 5 | 387.20 | 99121.98 | 0.39 | 0 |
| piraeus-rwo-strict-selassie | seq-read-1m | 5 | 1742.37 | 1742.12 | 18.69 | 0 |


## Methodology notes

- Writer phase used `fio --direct=1`, `--rw=write`, `--bs=1m`, and `--size=16G`.
- Reader phase used only `seq-read-1m` and `rand-read-4k`.
- Reader result backend labels include the reader node name.
- Write, mixed read/write, and sync-write profiles are excluded from this comparison.
- Existing `docs/storage-benchmark-v2` replicated backend results remain useful context, but they used a different methodology because a single fio Job wrote and read on the same consumer node.

## Placement audit

See `placement-audit.md` and the per-backend health files:

- `piraeus-run-001-health.md`
- `longhorn-nvme-run-001-health.md`
- `mayastor-run-001-health.md`

The placement audit records the supporting pod placement files and backend storage-placement evidence. In particular, `piraeus-run-001-health.md` records that the `piraeus-rwo-strict-dauwalter` result completed, but LINSTOR reported the `dauwalter` resource as `Diskless, SkipDisk (R)`. The `piraeus-rwo-strict-dauwalter` rows are therefore included only with that caveat and must not be interpreted as normal local-replica or up-to-date-local-resource reads on `dauwalter`.

## Source artifacts

- Piraeus raw logs: `piraeus-writer-fordyce-run-001.log`, `piraeus-reader-dauwalter-run-001.log`, `piraeus-reader-selassie-run-001.log`
- Piraeus placement evidence: `piraeus-writer-placement-run-001.txt`, `piraeus-reader-dauwalter-placement-run-001.txt`, `piraeus-reader-selassie-placement-run-001.txt`
- Longhorn raw logs: `longhorn-nvme-writer-fordyce-run-001.log`, `longhorn-nvme-reader-dauwalter-run-001.log`, `longhorn-nvme-reader-selassie-run-001.log`
- Longhorn placement evidence: `longhorn-nvme-writer-placement-run-001.txt`, `longhorn-nvme-reader-dauwalter-placement-run-001.txt`, `longhorn-nvme-reader-selassie-placement-run-001.txt`
- Mayastor raw logs: `mayastor-writer-fordyce-run-001.log`, `mayastor-reader-dauwalter-run-001.log`, `mayastor-reader-selassie-run-001.log`
- Mayastor placement evidence: `mayastor-writer-placement-run-001.txt`, `mayastor-reader-dauwalter-placement-run-001.txt`, `mayastor-reader-selassie-placement-run-001.txt`
- Summaries: `piraeus-run-001-summary.md`, `longhorn-nvme-run-001-summary.md`, `mayastor-run-001-summary.md`
- Health reports: `piraeus-run-001-health.md`, `longhorn-nvme-run-001-health.md`, `mayastor-run-001-health.md`
- Local baseline context: `docs/storage-benchmark-v2/final-comparison.md`
